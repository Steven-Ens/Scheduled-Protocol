mod config;
mod secrets;

use std::path::Path;

// Defines the program entry point and allows startup errors to propagate cleanly.
fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Loads the local executor configuration and returns early if loading fails.
    let _config = config::Config::from_file(Path::new("executor.toml"))?;
    let _secrets = secrets::Secrets::from_file(Path::new(".env"))?;

    // Returns a successful program result after configuration loads correctly.
    Ok(())
}
