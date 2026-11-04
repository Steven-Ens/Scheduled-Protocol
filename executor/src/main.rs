mod config;
mod contract;
mod oracle;
mod profitability;
mod rpc;
mod secrets;
mod storage;

use alloy::{primitives::I256, providers::Provider, rpc::types::BlockNumberOrTag};
use std::{error::Error, path::Path};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let config = config::Config::from_file(Path::new("executor.toml"))?;
    let secrets = secrets::Secrets::from_file(Path::new(".env"))?;

    let connection = storage::open_database(config.database_path())?;
    storage::initialize_schema(&connection)?;
    storage::initialize_chain_state(&connection, config.chain_id())?;

    let (provider, executor_address) =
        rpc::connect_and_validate(secrets.rpc_url(), secrets.private_key(), config.chain_id())
            .await?;

    let last_processed_block = storage::load_last_processed_block(&connection, config.chain_id())?;
    println!("Last Processed Block: {last_processed_block:?}");

    let from_block = next_scan_start(config.start_block(), last_processed_block)?;
    let latest_block = provider.get_block_number().await?;

    // Only scan when there are unprocessed blocks.
    if from_block <= latest_block {
        let payment_created_events = contract::get_payment_created_events(
            &provider,
            config.scheduled_protocol_address(),
            from_block,
            latest_block,
        )
        .await?;

        // Save discovered payments before advancing the block checkpoint. Candidate insertion is
        // idempotent, so rescanning the same block range after a failure cannot create duplicate
        // candidate rows.
        for event in payment_created_events {
            storage::insert_candidate(&connection, event.paymentId)?;
            println!("Discovered Payment ID: {}", event.paymentId);
        }

        // Advance the checkpoint only after the entire scanned range has succeeded and all
        // discovered candidates have been saved.
        storage::save_last_processed_block(&connection, config.chain_id(), latest_block)?;
    }

    // Load candidates outside the scan block so previously saved payments are still processed even
    // when there no new blocks or `PaymentCreated` events.
    let candidate_payment_ids = storage::load_candidates(&connection)?;

    if !candidate_payment_ids.is_empty() {
        let block = provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or("Latest block not found")?;

        let current_timestamp = block.header.timestamp;

        let mut prices = Vec::with_capacity(2);

        for (feed_address, max_price_age_seconds) in [
            (
                config.eth_usd_price_feed_address(),
                config.max_eth_usd_price_age_seconds(),
            ),
            (
                config.usdc_usd_price_feed_address(),
                config.max_usdc_usd_price_age_seconds(),
            ),
        ] {
            let round = oracle::get_latest_round_data(&provider, feed_address).await?;

            oracle::validate_latest_round_data(&round, current_timestamp, max_price_age_seconds)?;

            let decimals = oracle::get_feed_decimals(&provider, feed_address).await?;

            prices.push((round.answer, decimals));
        }

        let [
            (eth_usd_price, eth_usd_decimals),
            (usdc_usd_price, usdc_usd_decimals),
        ]: [(I256, u8); 2] = prices
            .try_into()
            .map_err(|_| "Expected two oracle results")?;

        for payment_id in candidate_payment_ids {
            let payment_status = contract::get_payment_status(
                config.scheduled_protocol_address(),
                &provider,
                payment_id,
            )
            .await?;

            // `Active` payments remain candidates for later execution.
            match payment_status {
                contract::IScheduledProtocol::PaymentStatus::Active => {
                    let can_execute = contract::simulate_execute_payment(
                        config.scheduled_protocol_address(),
                        &provider,
                        executor_address,
                        payment_id,
                    )
                    .await?;

                    if can_execute {
                        let estimated_cost_wei = contract::estimate_execute_payment_cost(
                            config.scheduled_protocol_address(),
                            &provider,
                            executor_address,
                            payment_id,
                        )
                        .await?;

                        println!(
                            "Estimated Execution Cost for Payment ID {payment_id}: {estimated_cost_wei} Wei"
                        );

                        let is_profitable = profitability::is_profitable(
                            eth_usd_price,
                            eth_usd_decimals,
                            usdc_usd_price,
                            usdc_usd_decimals,
                            estimated_cost_wei,
                            config.gas_cost_buffer_percent(),
                            config.minimum_profit_usdc(),
                        )?;

                        if is_profitable {
                            println!("Profitable Candidate Payment ID: {payment_id}");

                            let receipt = contract::execute_payment(
                                config.scheduled_protocol_address(),
                                &provider,
                                executor_address,
                                payment_id,
                            )
                            .await?;

                            println!(
                                "Executed Payment ID {payment_id}: {}",
                                receipt.transaction_hash
                            );
                        } else {
                            println!("Unprofitable Candidate Payment ID: {payment_id}");
                        }
                    } else {
                        println!("Candidate Payment ID {payment_id} is not executable yet");
                    }
                }
                contract::IScheduledProtocol::PaymentStatus::Cancelled
                | contract::IScheduledProtocol::PaymentStatus::Completed => {
                    storage::remove_candidate(&connection, payment_id)?;

                    println!("Removed Candidate Payment ID: {payment_id}");
                }
                _ => {
                    println!("Invalid Payment Status for Payment ID: {payment_id}");
                }
            }
        }
    }

    Ok(())
}

/// Returns the first block the executor should scan from based on its persisted checkpoint.
fn next_scan_start(
    configured_start_block: u64,
    last_processed_block: Option<u64>,
) -> Result<u64, std::io::Error> {
    match last_processed_block {
        // Resume from the block after `last_processed_block`, which was already processed successfully.
        Some(last_processed_block) => last_processed_block.checked_add(1).ok_or_else(|| {
            std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                "last processed block cannot be incremented",
            )
        }),
        None => Ok(configured_start_block),
    }
}

#[cfg(test)]
mod tests {
    use std::error::Error;

    use super::next_scan_start;

    const START_BLOCK: u64 = 315_846_171;

    // Verifies that a fresh executor begins scanning from its configured historical floor.
    #[test]
    fn no_checkpoint_starts_from_configured_start_block() -> Result<(), Box<dyn Error>> {
        let scan_start = next_scan_start(START_BLOCK, None)?;

        assert_eq!(scan_start, START_BLOCK);

        Ok(())
    }

    // Verifies that an existing checkpoint resumes scanning from the following block.
    #[test]
    fn checkpoint_starts_from_next_block() -> Result<(), Box<dyn Error>> {
        let scan_start = next_scan_start(START_BLOCK, Some(START_BLOCK))?;

        assert_eq!(scan_start, START_BLOCK + 1);

        Ok(())
    }

    // Verifies that advancing an impossible maximum checkpoint fails instead of overflowing.
    #[test]
    fn maximum_checkpoint_returns_error() {
        let result = next_scan_start(START_BLOCK, Some(u64::MAX));

        assert!(result.is_err());
    }
}
