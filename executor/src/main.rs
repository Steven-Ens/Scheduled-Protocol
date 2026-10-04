mod config;
mod secrets;
mod rpc;

use std::path::Path;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = config::Config::from_file(Path::new("executor.toml"))?;
    let secrets = secrets::Secrets::from_file(Path::new(".env"))?;

    rpc::connect_and_validate(secrets.rpc_url(), config.chain_id()).await?;

    Ok(())
}
