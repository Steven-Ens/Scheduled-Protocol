// Imports Serde's Deserialize trait so Config can be created from TOML data.
use serde::Deserialize;
// Imports Alloy's strongly typed 20-byte Ethereum address type.
use alloy::primitives::Address;
// Imports PathBuf into the production `config` module for the Config struct.
use std::path::PathBuf;

// Tells Serde to generate the deserialization code for this struct automatically.
#[derive(Deserialize)]
// Defines the Rust type that represents the executor configuration we support so far.
struct Config {
    // Stores the configured chain ID as an unsigned 64-bit integer.
    chain_id: u64,
    // Imports Alloy's strongly typed 20-byte Ethereum address type.
    scheduled_protocol_address: Address,
    // Stores the block containing the ScheduledProtocol deployment.
    start_block: u64,
    // Stores the number of seconds between polling cycles.
    poll_interval_seconds: u64,
    database_path: PathBuf,
}

// Starts an implementation block containing functions associated with Config.
impl Config {
    // Parses borrowed TOML text and returns either Config or a TOML parsing error.
    fn from_toml_str(contents: &str) -> Result<Self, toml::de::Error> {
        // Deserializes the TOML string into Self, which here means Config.
        toml::from_str(contents)
    }
}

// Compiles this module only when running tests.
#[cfg(test)]
// Starts a private module that contains tests for config.rs.
mod tests {
    // Imports Config from the parent config module into this test module.
    use super::Config;
    // Imports Alloy's address! macro for creating a known Address value in the test.
    use alloy::primitives::address;
    // Imports Rust's owned filesystem path type.
    use std::path::PathBuf;
    // Marks the following function as a test for cargo test.
    #[test]
    // Verifies that required executor configuration fields parse from TOML.
    fn parse_executor_config_from_toml() {
        // Creates a multi-line borrowed string containing valid executor TOML.
        let toml = r#"
        chain_id = 421614
        scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
        start_block = 123456
        poll_interval_seconds = 1
        database_path = "executor.db"
        "#;
        // Parses the TOML and fails the test if parsing unexpectedly returns an error.
        let config = Config::from_toml_str(toml).expect("valid TOML should parse");
        // Verifies that the configured Arbitrum Sepolia chain ID was parsed correctly.
        assert_eq!(config.chain_id, 421614);
        assert_eq!(
            config.scheduled_protocol_address,
            address!("0x1111111111111111111111111111111111111111")
        );
        assert_eq!(config.start_block, 123456);
        assert_eq!(config.poll_interval_seconds, 1);
        assert_eq!(config.database_path, PathBuf::from("executor.db"));
    }
}
