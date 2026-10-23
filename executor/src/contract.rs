use std::error::Error;

use alloy::{
    contract::Event,
    primitives::{Address, U256},
    providers::{DynProvider, Provider},
    rpc::types::{Filter, TransactionReceipt},
    sol,
    sol_types::SolEvent,
};

// Generates type-safe Rust types for the `ScheduledProtocol` ABI.
sol! {
    /// `ScheduledProtocol` contract binding used by the executor.
    #[sol(rpc)]
    interface IScheduledProtocol {
        enum PaymentStatus {
            Active,
            Cancelled,
            Completed
        }

        enum RecurrenceType {
            None,
            Daily,
            Weekly,
            Monthly,
            LastOfMonth
        }

        event PaymentCreated(
            uint256 indexed paymentId,
            address indexed payer,
            address indexed recipient,
            uint96 amount,
            RecurrenceType recurrence,
            uint40 executeAfter,
            uint24 expiresAfter,
            uint32 totalOccurrences
        );

        function executePayment(uint256 paymentId) external;

        function getPaymentStatus(uint256 paymentId)
            external
            view
            returns (PaymentStatus);
    }
}

/// Queries and decodes `PaymentCreated` events from the requested block range.
pub(crate) async fn get_payment_created_events(
    provider: &DynProvider,
    scheduled_protocol_address: Address,
    from_block: u64,
    to_block: u64,
) -> Result<Vec<IScheduledProtocol::PaymentCreated>, Box<dyn Error>> {
    let filter = Filter::new()
        .address(scheduled_protocol_address)
        // `topic0` is the keccak256 hash of the event signature, so this filters specifically for
        // `PaymentCreated` logs.
        .event_signature(IScheduledProtocol::PaymentCreated::SIGNATURE_HASH)
        .from_block(from_block)
        .to_block(to_block);

    let events =
        // Build a typed `PaymentCreated` query object from the `provider` and `filter`. `query()` 
        // returns `(PaymentCreated, Log)` pairs for each matching log.
        Event::<_, IScheduledProtocol::PaymentCreated>::new(provider, filter)
        .query()
        .await?
        // `into_iter()` creates the base iterator that yields each `(PaymentCreated, Log)` pair.
        // `map()` wraps that iterator with a transformation that keeps only `PaymentCreated`.
        // `collect()` drives the wrapped iterator, repeatedly pulling and transforming each pair
        // until all decoded events have been collected.
        .into_iter()
        .map(|pair| {
            let (event, _log) = pair;
            event
        })
        .collect();

    Ok(events)
}

/// Reads `getPaymentStatus` from the configured `ScheduledProtocol` deployment for payment
/// `payment_id`.
pub(crate) async fn get_payment_status(
    scheduled_protocol_address: Address,
    provider: &DynProvider,
    payment_id: U256,
) -> Result<IScheduledProtocol::PaymentStatus, Box<dyn Error>> {
    let contract = IScheduledProtocol::new(scheduled_protocol_address, provider);

    let payment_status = contract.getPaymentStatus(payment_id).call().await?;

    Ok(payment_status)
}

/// Simulates `executePayment` for `payment_id` without broadcasting a transaction.
pub(crate) async fn simulate_execute_payment(
    scheduled_protocol_address: Address,
    provider: &DynProvider,
    executor_address: Address,
    payment_id: U256,
) -> Result<bool, Box<dyn Error>> {
    let contract = IScheduledProtocol::new(scheduled_protocol_address, provider);

    let result = contract
        .executePayment(payment_id)
        .from(executor_address)
        .call()
        .await;

    // Inspect the simulation `Result` directly instead of propagating it with `?`. A successful
    // call means `executePayment` would currently succeed. If Alloy exposes revert data, the
    // contract execution reverted, so the payment is not currently executable. Other errors are
    // unexpected failures and are propagated to the caller.
    match result {
        Ok(_) => Ok(true),
        Err(error) if error.as_revert_data().is_some() => Ok(false),
        Err(error) => Err(Box::new(error)),
    }
}

/// Executes `executePayment` for `payment_id` and waits for transaction confirmation.
pub(crate) async fn execute_payment(
    scheduled_protocol_address: Address,
    provider: &DynProvider,
    executor_address: Address,
    payment_id: U256,
) -> Result<TransactionReceipt, Box<dyn Error>> {
    let contract = IScheduledProtocol::new(scheduled_protocol_address, provider);

    // Broadcast the signed `executePayment` transaction. The returned `PendingTransactionBuilder`
    // represents the transaction while Alloy waits for it to be included on-chain.
    let pending_transaction = contract
        .executePayment(payment_id)
        .from(executor_address)
        .send()
        .await?;

    // Wait for the transaction to be confirmed, then fetch its on-chain receipt.
    let receipt = pending_transaction.get_receipt().await?;

    // A mined transaction can still have failed during EVM execution. Only return the receipt when
    // the transaction completed successfully on-chain.
    if !receipt.status() {
        return Err(std::io::Error::other("executePayment transaction failed").into());
    }

    Ok(receipt)
}

/// Estimates the current cost in wei to execute `executePayment` for `payment_id`.
pub(crate) async fn estimate_execute_payment_cost(
    scheduled_protocol_address: Address,
    provider: &DynProvider,
    executor_address: Address,
    payment_id: U256,
) -> Result<u128, Box<dyn Error>> {
    let contract = IScheduledProtocol::new(scheduled_protocol_address, provider);

    // Estimate the gas required by `executePayment` using the executor address as `msg.sender`,
    // matching the transaction that would actually be submitted.
    let estimated_gas = contract
        .executePayment(payment_id)
        .from(executor_address)
        .estimate_gas()
        .await?;

    // Fetch the current gas price in wei per unit of gas.
    let gas_price = provider.get_gas_price().await?;

    // Transaction cost is gas used multiplied by the price paid for each unit of gas. Use checked
    // arithmetic so an overflow becomes an explicit error.
    let estimated_cost_wei = u128::from(estimated_gas)
        .checked_mul(gas_price)
        .ok_or_else(|| std::io::Error::other("estimated execution cost overflow"))?;

    Ok(estimated_cost_wei)
}
