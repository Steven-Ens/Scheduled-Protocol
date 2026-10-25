use std::{
    error::Error,
    path::{Path, PathBuf},
};

use alloy::primitives::Address;
use serde::Deserialize;

/// Stores the executor's runtime configuration.
#[derive(Deserialize)]
pub(crate) struct Config {
    operator: OperatorConfig,
    network: NetworkConfig,
}

/// Stores operator adjustable configuration.
#[derive(Deserialize)]
struct OperatorConfig {
    database_path: PathBuf,
    poll_interval_seconds: u64,
}

/// Stores network specific configuration.
#[derive(Deserialize)]
struct NetworkConfig {
    chain_id: u64,
    scheduled_protocol_address: Address,
    start_block: u64,
}

impl Config {
    /// Loads executor configuration from a TOML file.
    pub(crate) fn from_file(path: &Path) -> Result<Self, Box<dyn Error>> {
        let contents = std::fs::read_to_string(path)?;
        let config = Self::from_toml_str(&contents)?;
        Ok(config)
    }

    /// Parses executor TOML string into `Config`.
    fn from_toml_str(contents: &str) -> Result<Self, toml::de::Error> {
        toml::from_str(contents)
    }

    /// Returns the configured database path.
    pub(crate) fn database_path(&self) -> &Path {
        &self.operator.database_path
    }

    /// Returns the configured chain ID.
    pub(crate) fn chain_id(&self) -> u64 {
        self.network.chain_id
    }

    /// Returns the configured `ScheduledProtocol` address.
    pub(crate) fn scheduled_protocol_address(&self) -> Address {
        self.network.scheduled_protocol_address
    }

    /// Returns the configured start block.
    pub(crate) fn start_block(&self) -> u64 {
        self.network.start_block
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use alloy::primitives::address;

    use super::Config;

    // Verifies that executor configuration loads from a TOML file.
    #[test]
    fn load_executor_config_from_file() {
        let path = std::env::temp_dir().join("executor-config.toml");

        let toml = r#"
[operator]
database_path = "executor.db"
poll_interval_seconds = 1

[network]
chain_id = 421614
scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
start_block = 123456
"#;

        std::fs::write(&path, toml).expect("temporary config file should be written");
        let config = Config::from_file(&path).expect("valid config file should load");
        std::fs::remove_file(&path).expect("temporary config file should be removed");

        assert_eq!(config.network.chain_id, 421614);
    }

    // Verifies that a missing config file returns an error.
    #[test]
    fn load_executor_config_from_missing_file_returns_error() {
        let path = std::env::temp_dir().join("executor-config-missing.toml");
        // Ensure a stale file cannot make this test unexpectedly succeed.
        let _ = std::fs::remove_file(&path);

        let result = Config::from_file(&path);

        assert!(result.is_err());
    }

    // Verifies that invalid executor TOML returns a deserialization error.
    #[test]
    fn load_executor_config_from_invalid_toml_returns_error() {
        let path = std::env::temp_dir().join("executor-config-invalid.toml");

        let toml = r#"
[operator]
database_path = "executor.db"
poll_interval_seconds = 1

[network]
chain_id = "not-a-number"
scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
start_block = 123456
"#;

        std::fs::write(&path, toml).expect("temporary config file should be written");
        let result = Config::from_file(&path);
        std::fs::remove_file(&path).expect("temporary config file should be removed");

        assert!(result.is_err());
    }

    // Verifies that valid executor TOML parses into `Config`.
    #[test]
    fn parse_executor_config_from_toml() {
        let toml = r#"
[operator]
database_path = "executor.db"
poll_interval_seconds = 1

[network]
chain_id = 421614
scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
start_block = 123456
"#;

        let config = Config::from_toml_str(toml).expect("valid TOML should parse");

        assert_eq!(config.operator.database_path, PathBuf::from("executor.db"));
        assert_eq!(config.operator.poll_interval_seconds, 1);
        assert_eq!(config.network.chain_id, 421614);
        assert_eq!(
            config.network.scheduled_protocol_address,
            address!("0x1111111111111111111111111111111111111111")
        );
        assert_eq!(config.network.start_block, 123456);
    }
}
