use std::error::Error;

use alloy::{
    primitives::{Address, I256},
    providers::DynProvider,
    sol,
};

// Generates type-safe Rust bindings for Chainlink's price feed interface.
sol! {
    #[sol(rpc)]
    interface IAggregatorV3 {
        function decimals() external view returns (uint8);

        function latestRoundData()
            external
            view
            returns (
                uint80 roundId,
                int256 answer,
                uint256 startedAt,
                uint256 updatedAt,
                uint80 answeredInRound
            );
    }
}

/// Validates the latest round data from a Chainlink price feed.
pub(crate) fn validate_latest_round_data(
    round: &IAggregatorV3::latestRoundDataReturn,
    current_timestamp: u64,
    max_price_age_seconds: u64,
) -> Result<(), std::io::Error> {
    if round.answer <= I256::ZERO {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "Chainlink price must be positive",
        ));
    }

    // Convert for comparison
    let updated_at = u64::try_from(round.updatedAt).map_err(|_| {
        std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "Chainlink timestamp exceeds u64",
        )
    })?;

    if updated_at > current_timestamp {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "Chainlink price timestamp in the future",
        ));
    // Safe from overflow from previous check
    } else if current_timestamp - updated_at > max_price_age_seconds {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "Chainlink price timestamp is stale",
        ));
    }

    Ok(())
}

/// Reads the latest round data from a Chainlink price feed.
pub(crate) async fn get_latest_round_data(
    provider: &DynProvider,
    feed_address: Address,
) -> Result<IAggregatorV3::latestRoundDataReturn, Box<dyn Error>> {
    let feed = IAggregatorV3::new(feed_address, provider);

    let round = feed.latestRoundData().call().await?;

    Ok(round)
}

/// Reads the decimal precision of a Chainlink price feed.
pub(crate) async fn get_feed_decimals(
    provider: &DynProvider,
    feed_address: Address,
) -> Result<u8, Box<dyn Error>> {
    let feed = IAggregatorV3::new(feed_address, provider);

    let decimals = feed.decimals().call().await?;

    Ok(decimals)
}

#[cfg(test)]
mod tests {
    use alloy::primitives::aliases::U80;
    use alloy::primitives::{I256, U256};

    use super::{IAggregatorV3, validate_latest_round_data};

    #[test]
    fn valid_round_data_succeeds() {
        let round = IAggregatorV3::latestRoundDataReturn {
            roundId: U80::from(1),
            answer: I256::unchecked_from(100_000_000),
            startedAt: U256::from(1_000),
            updatedAt: U256::from(1_000),
            answeredInRound: U80::from(1),
        };

        assert!(validate_latest_round_data(&round, 1_100, 300).is_ok());
    }

    #[test]
    fn negative_price_returns_error() {
        let round = IAggregatorV3::latestRoundDataReturn {
            roundId: U80::from(1),
            answer: I256::unchecked_from(-100_000_000),
            startedAt: U256::from(1_000),
            updatedAt: U256::from(1_000),
            answeredInRound: U80::from(1),
        };

        assert!(validate_latest_round_data(&round, 1_100, 300).is_err());
    }

    #[test]
    fn zero_price_returns_error() {
        let round = IAggregatorV3::latestRoundDataReturn {
            roundId: U80::from(1),
            answer: I256::unchecked_from(0),
            startedAt: U256::from(1_000),
            updatedAt: U256::from(1_000),
            answeredInRound: U80::from(1),
        };

        assert!(validate_latest_round_data(&round, 1_100, 300).is_err());
    }

    #[test]
    fn max_price_age_timestamp_succeeds() {
        let round = IAggregatorV3::latestRoundDataReturn {
            roundId: U80::from(1),
            answer: I256::unchecked_from(100_000_000),
            startedAt: U256::from(1_000),
            updatedAt: U256::from(1_000),
            answeredInRound: U80::from(1),
        };

        assert!(validate_latest_round_data(&round, 1_100, 100).is_ok());
    }

    #[test]
    fn future_timestamp_returns_error() {
        let round = IAggregatorV3::latestRoundDataReturn {
            roundId: U80::from(1),
            answer: I256::unchecked_from(100_000_000),
            startedAt: U256::from(1_000),
            updatedAt: U256::from(1_101),
            answeredInRound: U80::from(1),
        };

        assert!(validate_latest_round_data(&round, 1_100, 300).is_err());
    }

    #[test]
    fn stale_timestamp_returns_error() {
        let round = IAggregatorV3::latestRoundDataReturn {
            roundId: U80::from(1),
            answer: I256::unchecked_from(100_000_000),
            startedAt: U256::from(1_000),
            updatedAt: U256::from(1_000),
            answeredInRound: U80::from(1),
        };

        assert!(validate_latest_round_data(&round, 1_101, 100).is_err());
    }
}
