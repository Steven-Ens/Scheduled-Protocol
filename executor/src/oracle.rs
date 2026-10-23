use std::error::Error;

use alloy::{primitives::Address, providers::DynProvider, sol};

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

/// Reads the latest round data from a Chainlink price feed proxy.
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
