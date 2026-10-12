use std::error::Error;

use alloy::{
    contract::Event,
    primitives::{Address, U256},
    providers::DynProvider,
    rpc::types::Filter,
    sol,
    sol_types::SolEvent,
};

// Generates type-safe Rust types for the `ScheduledProtol` ABI.
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
        // `topic0` is the keccak256 hash of the event signature, so this filters specifically for `PaymentCreated` logs.
        .event_signature(IScheduledProtocol::PaymentCreated::SIGNATURE_HASH)
        .from_block(from_block)
        .to_block(to_block);

    // Create a typed `PaymentCreated` query, fetch and decode matching logs, discard each raw log,
    // and collect the decoded events into a `Vec`.
    let events =
        Event::<_, IScheduledProtocol::PaymentCreated>::new(provider, filter)
        .query()
        .await?
        .into_iter()
        .map(|(event, _log)| event)
        .collect();

    Ok(events)
}

/// Reads `getPaymentStatus` from the configured `ScheduledProtocol` deployment for payment
/// `payment_id`.
pub(crate) async fn get_payment_status(
    address: Address,
    provider: &DynProvider,
    payment_id: U256,
) -> Result<IScheduledProtocol::PaymentStatus, Box<dyn Error>> {
    let contract = IScheduledProtocol::new(address, provider);

    let payment_status = contract.getPaymentStatus(payment_id).call().await?;

    Ok(payment_status)
}
