use alloy::providers::{Provider, ProviderBuilder};

// Connects to the RPC and verifies that it matches the configured chain.
pub(crate) async fn connect_and_validate(
    rpc_url: &str,
    configured_chain_id: u64,
) -> Result<(), Box<dyn std::error::Error>> {
    let provider = ProviderBuilder::new().connect(rpc_url).await?;

    let rpc_chain_id = provider.get_chain_id().await?;

    validate_chain_id(configured_chain_id, rpc_chain_id)?;

    Ok(())
}

// Validates that the connected RPC matches the configured chain.
fn validate_chain_id(configured_chain_id: u64, rpc_chain_id: u64) -> Result<(), std::io::Error> {
    if configured_chain_id != rpc_chain_id {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            format!(
                "RPC chain ID {rpc_chain_id} does not match configured chain ID {configured_chain_id}"
            )
        ));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::validate_chain_id;

    // Verifies that matching configured and RPC chain IDs are accepted.
    #[test]
    fn matching_chain_ids_are_valid() {
        let result = validate_chain_id(421614, 421614);

        assert!(result.is_ok());
    }

    // Verifies that mismatched configured and RPC chain IDs return an error.
    #[test]
    fn mismatched_chain_ids_return_error() {
        let result = validate_chain_id(421614, 1);

        assert!(result.is_err());
    }
}
