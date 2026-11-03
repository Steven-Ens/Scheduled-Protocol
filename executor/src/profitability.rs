use std::io::Error;

use alloy::primitives::{I256, U256};

// Fixed executor reward of 0.80 USDC (6 decimals).
const EXECUTOR_REWARD_USDC_UNITS: u64 = 800_000;

/// Determines whether an execution meets the minimum expected profit.
pub(crate) fn is_profitable(
    estimated_cost_wei: u128,
    eth_usd_price: I256,
    eth_usd_decimals: u8,
    usdc_usd_price: I256,
    usdc_usd_decimals: u8,
    gas_cost_buffer_percent: u64,
    minimum_profit_usdc: u64,
) -> Result<bool, Error> {
    // ETH/USD
    let eth_usd_price = eth_usd_price.into_raw();

    let price_scale = U256::from(10)
        .checked_pow(U256::from(eth_usd_decimals))
        .ok_or_else(|| Error::other("ETH/USD decimal scaling overflow"))?;

    // Calculate the estimated USD cost at 1e18.
    let numerator = U256::from(estimated_cost_wei)
        .checked_mul(eth_usd_price)
        .ok_or_else(|| Error::other("ETH/USD profitability calculation overflow"))?;

    let estimated_cost_usd_1e18 = numerator / price_scale;

    // USDC/USD
    let usdc_usd_price = usdc_usd_price.into_raw();

    let price_scale = U256::from(10)
        .checked_pow(U256::from(usdc_usd_decimals))
        .ok_or_else(|| Error::other("USDC/USD decimal scaling overflow"))?;

    let numerator = U256::from(estimated_cost_usd_1e18)
        .checked_mul(usdc_usd_price)
        .ok_or_else(|| Error::other("USDC/USD profitability calculation overflow"))?;

    let estimated_cost_usdc_1e18 = numerator / price_scale;

    // Buffer
    let gas_cost_buffer_percent = U256::from(gas_cost_buffer_percent);

    let buffer_multiplier = U256::from(100)
        .checked_add(U256::from(gas_cost_buffer_percent))
        .ok_or_else(|| Error::other("Profitability calculation overflow"))?;

    let buffered_cost_numerator = estimated_cost_usdc_1e18
        .checked_mul(buffer_multiplier)
        .ok_or_else(|| Error::other("Profitability calculation overflow"))?;

    // ie20 / 1e14 = 1e6 rounded up.
    let buffered_cost_usdc_ie6 =
        buffered_cost_numerator.div_ceil(U256::from(100_000_000_000_000u128));

    let estimated_profit_usdc_1e6 = U256::from(EXECUTOR_REWARD_USDC_UNITS)
        .checked_sub(buffered_cost_usdc_ie6)
        .ok_or_else(|| Error::other("Profitability calculation overflow"))?;

    Ok(estimated_profit_usdc_1e6 >= U256::from(minimum_profit_usdc))
}
