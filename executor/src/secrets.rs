use std::path::Path;

// Stores the executor's private runtime secrets.
pub(crate) struct Secrets {
    rpc_url: String,
    private_key: String,
}

impl Secrets {
    // Loads required executor secrets from a .env file.
    pub(crate) fn from_file(path: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        let mut rpc_url: Option<String> = None;
        let mut private_key: Option<String> = None;

        for item in dotenvy::from_path_iter(path)? {
            let (key, value) = item?;

            match key.as_str() {
                "RPC_URL" => rpc_url = Some(value),
                "PRIVATE_KEY" => private_key = Some(value),
                // Ignores unrelated .env entries.
                _ => {}
            }
        }

        let rpc_url = rpc_url
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| {
                std::io::Error::new(std::io::ErrorKind::InvalidData, "RPC_URL is required")
            })?;

        let private_key = private_key
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| {
                std::io::Error::new(std::io::ErrorKind::InvalidData, "PRIVATE_KEY is required")
            })?;

        Ok(Self {
            rpc_url,
            private_key,
        })
    }

    // Returns the configured RPC_URL.
    pub(crate) fn rpc_url(&self) -> &str {
        &self.rpc_url
    }

    // Returns the configured PRIVATE_KEY.
    pub(crate) fn private_key(&self) -> &str {
        &self.private_key
    }
}

#[cfg(test)]
mod tests {
    use super::Secrets;

    #[test]
    // Verifies that valid executor secrets load from a .env file.
    fn load_executor_secrets_from_file() {
        let path = std::env::temp_dir().join("executor-secrets.env");

        let contents: &str = r#"
RPC_URL=https://example.com
PRIVATE_KEY=0x1111111111111111111111111111111111111111111111111111111111111111
"#;

        std::fs::write(&path, contents).expect("temporary secrets file should be written");
        let secrets = Secrets::from_file(&path).expect("valid secrets file should load");
        std::fs::remove_file(&path).expect("temporary secrets file should be removed");

        assert_eq!(secrets.rpc_url, "https://example.com");
        assert_eq!(
            secrets.private_key,
            "0x1111111111111111111111111111111111111111111111111111111111111111"
        );
    }

    #[test]
    // Verifies that a missing .env file returns an error.
    fn load_executor_secrets_from_missing_file_returns_error() {
        // Creates an owned temporary path for a file that should not exist.
        let path = std::env::temp_dir().join("executor-missing.env");
        // Ensures a stale file cannot make this test unexpectedly succeed.
        let _ = std::fs::remove_file(&path);

        // Attempts to load secrets from the missing file without unwrapping the Result.
        let result = Secrets::from_file(&path);

        assert!(result.is_err());
    }

    #[test]
    // Verifies that malformed dotenv syntax returns an error.
    fn load_executor_secrets_from_malformed_file_returns_error() {
        let path = std::env::temp_dir().join("executor-malformed.env");

        let contents: &str = r#"
RPC_URL=https://example.com
INVALID LINE
PRIVATE_KEY=0x1111111111111111111111111111111111111111111111111111111111111111
"#;

        std::fs::write(&path, contents).expect("temporary secrets file should be written");
        let result = Secrets::from_file(&path);
        std::fs::remove_file(&path).expect("temporary secrets file should be removed");

        assert!(result.is_err());
    }

    #[test]
    // Verifies that unrecognized dotenv values are ignored.
    fn load_executor_secrets_ignores_unrecognized_values() {
        // Creates an owned path for the valid test file with unrecognized values.
        let path = std::env::temp_dir().join("executor-unrecognized.env");

        let contents: &str = r#"
RPC_URL=https://example.com
UNRECOGNIZED_LINE=IGNORED
PRIVATE_KEY=0x1111111111111111111111111111111111111111111111111111111111111111
"#;

        std::fs::write(&path, contents).expect("temporary secrets file should be written");
        let secrets = Secrets::from_file(&path).expect("valid secrets file should load");
        std::fs::remove_file(&path).expect("temporary secrets file should be removed");

        assert_eq!(secrets.rpc_url, "https://example.com");
        assert_eq!(
            secrets.private_key,
            "0x1111111111111111111111111111111111111111111111111111111111111111"
        );
    }

    #[test]
    // Verifies that RPC_URL is required.
    fn load_executor_secrets_without_rpc_url_returns_error() {
        let path = std::env::temp_dir().join("executor-missing-rpc-url.env");

        let contents: &str = r#"
PRIVATE_KEY=0x1111111111111111111111111111111111111111111111111111111111111111
"#;

        std::fs::write(&path, contents).expect("temporary secrets file should be written");
        let result = Secrets::from_file(&path);
        std::fs::remove_file(&path).expect("temporary secrets file should be removed");

        assert!(result.is_err());
    }

    // Verifies that an empty RPC_URL returns an error.
    #[test]
    fn load_executor_secrets_with_empty_rpc_url_returns_error() {
        let path = std::env::temp_dir().join("executor-empty-rpc-url.env");

        let contents = r#"
RPC_URL=
PRIVATE_KEY=0x1111111111111111111111111111111111111111111111111111111111111111
"#;

        std::fs::write(&path, contents).expect("temporary secrets file should be written");
        let result = Secrets::from_file(&path);
        std::fs::remove_file(&path).expect("temporary secrets file should be removed");

        assert!(result.is_err());
    }

    #[test]
    // Verifies that PRIVATE_KEY required.
    fn load_executor_secrets_without_private_key_returns_error() {
        let path = std::env::temp_dir().join("executor-missing-private-key.env");

        let contents: &str = r#"
RPC_URL=https://example.com
"#;

        std::fs::write(&path, contents).expect("temporary secrets file should be written");
        let result = Secrets::from_file(&path);
        std::fs::remove_file(&path).expect("temporary secrets file should be removed");

        assert!(result.is_err());
    }

    // Verifies that an empty PRIVATE_KEY returns an error.
    #[test]
    fn load_executor_secrets_with_empty_private_key_returns_error() {
        let path = std::env::temp_dir().join("executor-empty-private-key.env");

        let contents = r#"
RPC_URL=https://example.com
PRIVATE_KEY=
"#;

        std::fs::write(&path, contents).expect("temporary secrets file should be written");
        let result = Secrets::from_file(&path);
        std::fs::remove_file(&path).expect("temporary secrets file should be removed");

        assert!(result.is_err());
    }
}
