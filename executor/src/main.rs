mod config;
mod secrets;

use std::path::Path;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let _config = config::Config::from_file(Path::new("executor.toml"))?;
    let _secrets = secrets::Secrets::from_file(Path::new(".env"))?;

    Ok(())
}
