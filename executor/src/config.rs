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
    gas_cost_buffer_percent: u64,
    minimum_profit_usdc: u64,
}

/// Stores network specific configuration.
#[derive(Deserialize)]
struct NetworkConfig {
    chain_id: u64,
    scheduled_protocol_address: Address,
    start_block: u64,
    eth_usd_price_feed_address: Address,
    usdc_usd_price_feed_address: Address,
    max_eth_usd_price_age_seconds: u64,
    max_usdc_usd_price_age_seconds: u64,
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

    // Getters

    pub(crate) fn database_path(&self) -> &Path {
        &self.operator.database_path
    }

    pub(crate) fn poll_interval_seconds(&self) -> u64 {
        self.operator.poll_interval_seconds
    }

    pub(crate) fn gas_cost_buffer_percent(&self) -> u64 {
        self.operator.gas_cost_buffer_percent
    }

    pub(crate) fn minimum_profit_usdc(&self) -> u64 {
        self.operator.minimum_profit_usdc
    }
    pub(crate) fn chain_id(&self) -> u64 {
        self.network.chain_id
    }

    pub(crate) fn scheduled_protocol_address(&self) -> Address {
        self.network.scheduled_protocol_address
    }

    pub(crate) fn start_block(&self) -> u64 {
        self.network.start_block
    }

    pub(crate) fn eth_usd_price_feed_address(&self) -> Address {
        self.network.eth_usd_price_feed_address
    }

    pub(crate) fn usdc_usd_price_feed_address(&self) -> Address {
        self.network.usdc_usd_price_feed_address
    }

    pub(crate) fn max_eth_usd_price_age_seconds(&self) -> u64 {
        self.network.max_eth_usd_price_age_seconds
    }

    pub(crate) fn max_usdc_usd_price_age_seconds(&self) -> u64 {
        self.network.max_usdc_usd_price_age_seconds
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use alloy::primitives::address;

    use super::Config;

    #[test]
    fn load_executor_config_from_toml_file_succeeds() {
        let path = std::env::temp_dir().join("executor-config.toml");

        let toml = r#"
[operator]
database_path = "executor.db"
poll_interval_seconds = 1
gas_cost_buffer_percent = 10
minimum_profit_usdc = 100_000

[network]
chain_id = 421614
scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
start_block = 123456
eth_usd_price_feed_address = "0x1111111111111111111111111111111111111111"
usdc_usd_price_feed_address = "0x1111111111111111111111111111111111111111"
max_eth_usd_price_age_seconds = 86_460
max_usdc_usd_price_age_seconds = 86_460
"#;

        std::fs::write(&path, toml).expect("temporary config file should be written");
        let config = Config::from_file(&path).expect("valid config file should load");
        std::fs::remove_file(&path).expect("temporary config file should be removed");

        assert_eq!(config.network.chain_id, 421614);
    }

    #[test]
    fn load_executor_config_from_missing_file_returns_error() {
        let path = std::env::temp_dir().join("executor-config-missing.toml");
        // Ensure a stale file cannot make this test unexpectedly succeed.
        let _ = std::fs::remove_file(&path);

        let result = Config::from_file(&path);

        assert!(result.is_err());
    }

    #[test]
    fn load_executor_config_from_invalid_toml_returns_error() {
        let path = std::env::temp_dir().join("executor-config-invalid.toml");

        let toml = r#"
[operator]
database_path = "executor.db"
poll_interval_seconds = 1
gas_cost_buffer_percent = 10
minimum_profit_usdc = 100_000

[network]
chain_id = "not-a-number"
scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
start_block = 123456
eth_usd_price_feed_address = "0x1111111111111111111111111111111111111111"
usdc_usd_price_feed_address = "0x1111111111111111111111111111111111111111"
max_eth_usd_price_age_seconds = 86_460
max_usdc_usd_price_age_seconds = 86_460
"#;

        std::fs::write(&path, toml).expect("temporary config file should be written");
        let result = Config::from_file(&path);
        std::fs::remove_file(&path).expect("temporary config file should be removed");

        assert!(result.is_err());
    }

    #[test]
    fn parse_executor_config_from_toml_succeeds() {
        let toml = r#"
[operator]
database_path = "executor.db"
poll_interval_seconds = 1
gas_cost_buffer_percent = 10
minimum_profit_usdc = 100_000

[network]
chain_id = 421614
scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
start_block = 123456
eth_usd_price_feed_address = "0x1111111111111111111111111111111111111111"
usdc_usd_price_feed_address = "0x1111111111111111111111111111111111111111"
max_eth_usd_price_age_seconds = 86_460
max_usdc_usd_price_age_seconds = 86_460
"#;

        let config = Config::from_toml_str(toml).expect("valid TOML should parse");

        assert_eq!(config.operator.database_path, PathBuf::from("executor.db"));
        assert_eq!(config.operator.poll_interval_seconds, 1);
        assert_eq!(config.operator.gas_cost_buffer_percent, 10);
        assert_eq!(config.operator.minimum_profit_usdc, 100_000);
        assert_eq!(config.network.chain_id, 421614);
        assert_eq!(
            config.network.scheduled_protocol_address,
            address!("0x1111111111111111111111111111111111111111")
        );
        assert_eq!(config.network.start_block, 123456);
        assert_eq!(
            config.network.eth_usd_price_feed_address,
            address!("0x1111111111111111111111111111111111111111")
        );
        assert_eq!(
            config.network.usdc_usd_price_feed_address,
            address!("0x1111111111111111111111111111111111111111")
        );
        assert_eq!(config.network.max_eth_usd_price_age_seconds, 86_460);
        assert_eq!(config.network.max_usdc_usd_price_age_seconds, 86_460);
    }
}
