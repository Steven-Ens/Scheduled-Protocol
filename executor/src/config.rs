use alloy::primitives::Address;
use serde::Deserialize;
use std::path::{Path, PathBuf};

// Serde generates the deserialization code for Config automatically.
#[derive(Deserialize)]
// Defines the executor's runtime config. Accessible throughout this crate without exposing it as a public external API.
pub(crate) struct Config {
    chain_id: u64,
    scheduled_protocol_address: Address,
    // Block containing the ScheduledProtocol deployment.
    start_block: u64,
    poll_interval_seconds: u64,
    // PathBuf required as Config stores and owns the database path.
    database_path: PathBuf,
}

impl Config {
    // Parses borrowed TOML string and returns either Config or a TOML parsing error.
    fn from_toml_str(contents: &str) -> Result<Self, toml::de::Error> {
        // Deserializes the TOML string into Config.
        toml::from_str(contents)
    }

    // Loads Config from a borrowed filesystem path and returns either Config or any standard error.
    // Callable from main.rs.
    pub(crate) fn from_file(path: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        // Reads the file into an owned String where `?` returns early if the filesystem read fails.
        let contents = std::fs::read_to_string(path)?;
        let config = Self::from_toml_str(&contents)?;
        // Wraps the successfully parsed Config in Result::Ok.
        Ok(config)
    }
}

// Compiles this module only when running tests.
#[cfg(test)]
mod tests {
    // Imports Config struct from the parent config module into this test module.
    use super::Config;
    use alloy::primitives::address;
    use std::path::PathBuf;

    #[test]
    // Verifies that required executor configuration fields parse from TOML string.
    fn parse_executor_config_from_toml() {
        // Creates a borrowed multi-line raw string containing valid executor TOML.
        let toml = r#"
        chain_id = 421614
        scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
        start_block = 123456
        poll_interval_seconds = 1
        database_path = "executor.db"
        "#;

        // Parses the TOML and fails the test if parsing unexpectedly returns an error.
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
    // Verifies that Config can be loaded from a TOML file on disk.
    fn load_executor_config_from_file() {
        // Creates and owns a temporary filesystem path outside the project directory, e.g. `/tmp/executor-test.toml`
        let path = std::env::temp_dir().join("executor-test.toml");

        let toml = r#"
        chain_id = 421614
        scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
        start_block = 123456
        poll_interval_seconds = 1
        database_path = "executor.db"
        "#;

        // Borrows the path and writes the TOML text to disk, fails the test if the file cannot be created.
        std::fs::write(&path, toml).expect("temporary config file should be written");
        let config = Config::from_file(&path).expect("valid config file should load");
        std::fs::remove_file(&path).expect("temporary config file should be removed");

        // One passing assertion confirms success.
        assert_eq!(config.chain_id, 421614);
    }

    #[test]
    // Verifies that loading a nonexistent config produces an error.
    fn load_executor_config_from_missing_file_returns_error() {
        // Creates an owned temporary path for a file that should not exist.
        let path = std::env::temp_dir().join("executor-test-missing.toml");
        // Removes any stale file from an earlier interrupted test run and intentionally ignores the result.
        let _ = std::fs::remove_file(&path);

        // Attempts to load the nonexistent file without unwrapping the Result.
        let result = Config::from_file(&path);

        // Verifies that the failed file read produced an Err result.
        assert!(result.is_err());
    }

    #[test]
    // Verifies that readable but invalid configuration data fails deserialization.
    fn load_executor_config_from_invalid_toml_returns_error() {
        // Creates and owns a temporary path for the deliberately invalid config file.
        let path = std::env::temp_dir().join("executor-test-invalid.toml");

        let toml = r#"
        chain_id = "not-a-number"
        scheduled_protocol_address = "0x1111111111111111111111111111111111111111"
        start_block = 123456
        poll_interval_seconds = 1
        database_path = "executor.db"
        "#;

        // Writes the invalid executor configuration to disk.
        std::fs::write(&path, toml).expect("temporary config file should be written");
        // Reads the file successfully but should fail while deserializing `chain_id` into `u64`.
        let result = Config::from_file(&path);
        std::fs::remove_file(&path).expect("temporary config file should be removed");

        assert!(result.is_err());
    }
}
