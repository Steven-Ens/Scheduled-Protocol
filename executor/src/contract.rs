use alloy::{
    primitives::{Address, U256},
    providers::DynProvider,
    sol,
};

// Generates typed Rust bindings for the ScheduledProtocol interface.
sol! {
    #[sol(rpc)]
    interface IScheduledProtocol {
        enum PaymentStatus {
            Active,
            Cancelled,
            Completed
        }

        function getPaymentStatus(uint256 paymentId)
            external
            view
            returns (PaymentStatus);
    }
}

// Reads `getPaymentStatus` from the configured ScheduledProtocol deployment for payment
// `payment_id`.
pub(crate) async fn get_payment_status(
    address: Address,
    provider: DynProvider,
    payment_id: U256,
) -> Result<IScheduledProtocol::PaymentStatus, Box<dyn std::error::Error>> {
    let contract = IScheduledProtocol::new(address, provider);

    let payment_status = contract.getPaymentStatus(payment_id).call().await?;

    Ok(payment_status)
}
