mod config;
mod contract;
mod oracle;
mod rpc;
mod secrets;
mod storage;

use std::{error::Error, path::Path};

use alloy::{primitives::utils::format_units, providers::Provider};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Load executor configuration and secrets, connect to the configured chain, then open and
    // initialize the persistent SQLite state.
    let config = config::Config::from_file(Path::new("executor.toml"))?;
    let secrets = secrets::Secrets::from_file(Path::new(".env"))?;

    let (provider, executor_address) =
        rpc::connect_and_validate(secrets.rpc_url(), secrets.private_key(), config.chain_id())
            .await?;

    // Run: $ cargo run -- --oracle-check
    if std::env::args().any(|argument| argument == "--oracle-check") {
        for (name, address) in [
            ("ETH/USD", "0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165"),
            ("USDC/USD", "0x0153002d20B96532C639313c2d54c3dA09109309"),
        ] {
            let feed_address = address.parse::<alloy::primitives::Address>()?;

            let round = oracle::get_latest_round_data(&provider, feed_address).await?;

            let decimals = oracle::get_feed_decimals(&provider, feed_address).await?;

            let price = format_units(round.answer, decimals)?;

            println!(
                "{name}: ${price}, decimals={decimals}, updatedAt={}",
                round.updatedAt
            );
        }

        return Ok(());
    }

    let connection = storage::open_database(config.database_path())?;
    storage::initialize_schema(&connection)?;
    storage::initialize_chain_state(&connection, config.chain_id())?;

    let last_processed_block = storage::load_last_processed_block(&connection, config.chain_id())?;
    println!("Last Processed Block: {last_processed_block:?}");

    let from_block = next_scan_start(config.start_block(), last_processed_block)?;
    let latest_block = provider.get_block_number().await?;

    // Only scan when there are unprocessed blocks. A fresh deployment begins at `start_block`
    // otherwise scanning resumes from the block after the checkpoint.
    if from_block <= latest_block {
        let payment_created_events = contract::get_payment_created_events(
            &provider,
            config.scheduled_protocol_address(),
            from_block,
            latest_block,
        )
        .await?;

        // Persist every discovered payment before advancing the block checkpoint. Candidate
        // insertion is idempotent, so rescanning the same block range after a failure cannot create
        // duplicate candidate rows.
        for event in payment_created_events {
            storage::insert_candidate(&connection, event.paymentId)?;
            println!("Discovered Payment ID: {}", event.paymentId);
        }

        // Advance the checkpoint only after the entire scanned range has succeeded and all
        // discovered candidates have been persisted.
        storage::save_last_processed_block(&connection, config.chain_id(), latest_block)?;
    }

    // Load candidates outside the scan block so previously persisted payments are still processed
    // even when there are no new blocks or `PaymentCreated` events.
    let candidate_payment_ids = storage::load_candidates(&connection)?;

    for payment_id in candidate_payment_ids {
        let payment_status = contract::get_payment_status(
            config.scheduled_protocol_address(),
            &provider,
            payment_id,
        )
        .await?;

        // `Active` payments remain candidates for later execution. Terminal payment states no
        // longer need to be tracked by the executor.
        match payment_status {
            contract::IScheduledProtocol::PaymentStatus::Active => {
                const MAX_EXECUTION_COST_WEI: u128 = 327_000_000_000_000;

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

                    // Temporary profitability check using a manually calculated wei value
                    // equivalent to approximately $0.80 at the current ETH/USD price.
                    if estimated_cost_wei < MAX_EXECUTION_COST_WEI {
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
