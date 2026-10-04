use alloy::primitives::Address;
use serde::Deserialize;
use std::path::{Path, PathBuf};

#[derive(Deserialize)]
// Stores the executor's runtime config.
pub(crate) struct Config {
    chain_id: u64,
    scheduled_protocol_address: Address,
    // Immutable backfill floor using the ScheduledProtocol deployment block.
    start_block: u64,
    poll_interval_seconds: u64,
    database_path: PathBuf,
}

impl Config {
    // Parses executor TOML into Config.
    fn from_toml_str(contents: &str) -> Result<Self, toml::de::Error> {
        toml::from_str(contents)
    }

    // Load executor configuration from a TOML file.
    pub(crate) fn from_file(path: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        let contents = std::fs::read_to_string(path)?;
        let config = Self::from_toml_str(&contents)?;
        Ok(config)
    }

    // Returns the configured chain ID.
    pub(crate) fn chain_id(&self) -> u64 {
        self.chain_id
    }
}

#[cfg(test)]
mod tests {
    use super::Config;
    use alloy::primitives::address;
    use std::path::PathBuf;

    #[test]
    // Verifies that valid executor TOML parses into Config.
    fn parse_executor_config_from_toml() {
        let toml = r#"
chain_id = 421614
scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
start_block = 123456
poll_interval_seconds = 1
database_path = "executor.db"
"#;

        let config = Config::from_toml_str(toml).expect("valid TOML should parse");

        assert_eq!(config.chain_id, 421614);
        assert_eq!(
            config.scheduled_protocol_address,
            address!("0x1111111111111111111111111111111111111111")
        );
        assert_eq!(config.start_block, 123456);
        assert_eq!(config.poll_interval_seconds, 1);
        assert_eq!(config.database_path, PathBuf::from("executor.db"));
    }

    #[test]
    // Verifies that executor configuration loads from a TOML file.
    fn load_executor_config_from_file() {
        let path = std::env::temp_dir().join("executor-test.toml");

        let toml = r#"
chain_id = 421614
scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
start_block = 123456
poll_interval_seconds = 1
database_path = "executor.db"
"#;

        std::fs::write(&path, toml).expect("temporary config file should be written");
        let config = Config::from_file(&path).expect("valid config file should load");
        std::fs::remove_file(&path).expect("temporary config file should be removed");

        assert_eq!(config.chain_id, 421614);
    }

    #[test]
    // Verifies that a missing config file returns an error.
    fn load_executor_config_from_missing_file_returns_error() {
        let path = std::env::temp_dir().join("executor-test-missing.toml");
        // Ensure a stale file cannot make this test unexpectedly succeed.
        let _ = std::fs::remove_file(&path);

        let result = Config::from_file(&path);

        assert!(result.is_err());
    }

    #[test]
    // Verifies that invalid executor TOML returns a deserialization error.
    fn load_executor_config_from_invalid_toml_returns_error() {
        let path = std::env::temp_dir().join("executor-test-invalid.toml");

        let toml = r#"
chain_id = "not-a-number"
scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
start_block = 123456
poll_interval_seconds = 1
database_path = "executor.db"
"#;

        std::fs::write(&path, toml).expect("temporary config file should be written");
        let result = Config::from_file(&path);
        std::fs::remove_file(&path).expect("temporary config file should be removed");

        assert!(result.is_err());
    }
}
