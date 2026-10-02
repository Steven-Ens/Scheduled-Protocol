use std::path::Path;

// Defines the executor's private secrets, owned by Secrets at runtime.
struct Secrets {
    rpc_url: String,
    private_key: String,
}

impl Secrets {
    // Loads secrets from a borrowed .env path and allows either dotenv or validation errors to be returned.
    fn from_file(path: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        // The owned mutable values may currently be absent or may eventually contain a String.
        let mut rpc_url: Option<String> = None;
        let mut private_key: Option<String> = None;

        // Opens the .env file and iterates over each parsed key/value entry, returning early if the file cannot be read.
        for item in dotenvy::from_path_iter(path)? {
            // Unwraps the current dotenv entry into its owned key and value Strings, returning early if that entry is invalid.
            let (key, value) = item?;

            // Borrows the key as &str so we can match it against the recognized secret names.
            match key.as_str() {
                // Stores the owned value in Some when the current key is RPC_URL or PRIVATE_KEY.
                "RPC_URL" => rpc_url = Some(value),
                "PRIVATE_KEY" => private_key = Some(value),
                // Ignores any other .env entries because they are not part of the Secrets type.
                _ => {}
            }
        }

        // Converts the RPC URL and PRIVATE_KEY into String, or creates errors describing the
        // missing secret(s). Extracts the String from Some or immediately returns the generated error.
        let rpc_url = rpc_url.ok_or_else(|| {
            std::io::Error::new(std::io::ErrorKind::InvalidData, "RPC_URL is required")
        })?;
        let private_key = private_key.ok_or_else(|| {
            std::io::Error::new(std::io::ErrorKind::InvalidData, "PRIVATE_KEY is required")
        })?;

        // Moves the owned values into Secrets and wraps it in Result::Ok because both required values are now present.
        Ok(Self {
            rpc_url,
            private_key,
        })
    }
}

#[cfg(test)]
mod tests {
    // Imports Secrets struct from the parent secrets module into this test module.
    use super::Secrets;
    use std::path::PathBuf;

    #[test]
    // Verifies that Secrets can be loaded from a .env file on disk.
    fn load_executor_secrets_from_file() {
        // Creates and owns a temporary .env filesystem path outside the project directory.
        let path: PathBuf = std::env::temp_dir().join("executor-secrets.env");

        let contents: &str = r#"
        RPC_URL=https://example.com
        PRIVATE_KEY=0x1111111111111111111111111111111111111111111111111111111111111111
        "#;

        // Borrows the path and writes the test .env contents to disk, fails the test if the file
        // cannot be created.
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
    // Verifies that loading a nonexistent .env produces an error.
    fn load_executor_secrets_from_missing_file_returns_error() {
        // Creates an owned temporary path for a file that should not exist.
        let path: PathBuf = std::env::temp_dir().join("executor-missing.env");
        // Removes any stale file from an earlier interrupted test run and intentionally ignores the result.
        let _ = std::fs::remove_file(&path);

        // Attempts to load secrets from the missing file without unwrapping the Result.
        let result = Secrets::from_file(&path);

        assert!(result.is_err());
    }

    #[test]
    // Verifies that malformed dotenv syntax produces an error.
    fn load_executor_secrets_from_malformed_file_returns_error() {
        // Creates an owned path for the malformed test file.
        let path: PathBuf = std::env::temp_dir().join("executor-malformed.env");

        let contents: &str = r#"
        RPC_URL=https://example.com
        INVALID LINE
        PRIVATE_KEY=0x1111111111111111111111111111111111111111111111111111111111111111
        "#;

        std::fs::write(&path, contents).expect("temporary secrets file should be written");
        // Attempts to load the malformed file without unwrapping the Result.
        let result = Secrets::from_file(&path);

        std::fs::remove_file(&path).expect("temporary secrets file should be removed");

        assert!(result.is_err());
    }

    #[test]
    fn load_executor_secrets_ignores_unrecognized_values() {
        // Creates an owned path for the valid test file with unrecognized values.
        let path: PathBuf = std::env::temp_dir().join("executor-unrecognized.env");

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
        // Creates an owned path for the temporary test file.
        let path: PathBuf = std::env::temp_dir().join("executor-missing-rpc-url.env");

        let contents: &str = r#"
        PRIVATE_KEY=0x1111111111111111111111111111111111111111111111111111111111111111
        "#;

        // Writes the incomplete secrets file to disk.
        std::fs::write(&path, contents).expect("temporary secrets file should be written");

        // Attempts to construct Secrets from a file missing RPC_URL.
        let result = Secrets::from_file(&path);

        std::fs::remove_file(&path).expect("temporary secrets file should be removed");

        assert!(result.is_err());
    }

    #[test]
    // Verifies that PRIVATE_KEY required.
    fn load_executor_secrets_without_private_key_returns_error() {
        // Creates an owned path for the temporary test file.
        let path: PathBuf = std::env::temp_dir().join("executor-missing-private-key.env");

        let contents: &str = r#"
        RPC_URL=https://example.com
        "#;

        // Writes the incomplete secrets file to disk.
        std::fs::write(&path, contents).expect("temporary secrets file should be written");

        // Attempts to construct Secrets from a file missing RPC_URL.
        let result = Secrets::from_file(&path);

        std::fs::remove_file(&path).expect("temporary secrets file should be removed");

        assert!(result.is_err());
    }
}
