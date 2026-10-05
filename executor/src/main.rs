mod config;
mod secrets;
mod rpc;
mod contract;

use alloy::primitives::U256;
use std::path::Path;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = config::Config::from_file(Path::new("executor.toml"))?;
    let secrets = secrets::Secrets::from_file(Path::new(".env"))?;

    let provider = rpc::connect_and_validate(
        secrets.rpc_url(),
        secrets.private_key(),
        config.chain_id()
    )
    .await?;

    let payment_id = U256::from(0);

    let payment_status = contract::get_payment_status(
        config.scheduled_protocol_address(),
        provider,
        payment_id,
    )
    .await?;

    let status = match payment_status {
        contract::IScheduledProtocol::PaymentStatus::Active => "Active",
        contract::IScheduledProtocol::PaymentStatus::Cancelled => "Cancelled",
        contract::IScheduledProtocol::PaymentStatus::Completed => "Completed",
        _ => "Invalid",
    };

    println!("Payment {payment_id} Status: {status}");

    Ok(())
}
