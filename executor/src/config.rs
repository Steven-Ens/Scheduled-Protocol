// Imports Serde's Deserialize trait so Config can be created from TOML data.
use serde::Deserialize;

// Tells Serde to generate the deserialization code for this struct automatically.
#[derive(Deserialize)]
// Defines the Rust type that represents the executor configuration we support so far.
struct Config {
    // Stores the configured chain ID as an unsigned 64-bit integer.
    chain_id: u64,
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

    #[test]
    // Verifies that a valid chain_id can be parsed from TOML.
    fn parse_chain_id_from_toml() {
        // Creates an immutable TOML string representing Arbitrum Sepolia.
        let toml = "chain_id = 421614";
        // Calls the parser API and fails the test if parsing returns an error.
        let config = Config::from_toml_str(toml).expect("valid TOML should parse");
        // Confirms the parsed Config contains the expected chain ID.
        assert_eq!(config.chain_id, 421614);
    }
}
