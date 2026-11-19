use std::io::Error;

use alloy::primitives::{I256, U256};

// Executor reward of 0.80 USDC.
const EXECUTOR_REWARD_USDC: u64 = 800_000;
// Convert buffered cost from 1e20 scaling to 1e6 for USDC.
const DENOMINATOR: u128 = 100_000_000_000_000;

/// Determines whether an execution meets the minimum expected profit. Cost estimates use 18-decimal
/// precision until conversion to 6-decimal USDC.
pub(crate) fn is_profitable(
    eth_usd_price: I256,
    eth_usd_decimals: u8,
    usdc_usd_price: I256,
    usdc_usd_decimals: u8,
    estimated_cost_wei: u128,
    gas_cost_buffer_percent: u64,
    minimum_profit_usdc: u64,
) -> Result<bool, Error> {
    // Convert ETH gas cost to USD by multiplying by the ETH/USD price.
    let eth_usd_price = eth_usd_price.into_raw();

    let price_scale = U256::from(10)
        .checked_pow(U256::from(eth_usd_decimals))
        .ok_or_else(|| Error::other("ETH/USD decimal scaling overflow"))?;

    let numerator = U256::from(estimated_cost_wei)
        .checked_mul(eth_usd_price)
        .ok_or_else(|| Error::other("ETH/USD numerator calculation overflow"))?;

    let estimated_cost_usd = numerator / price_scale;

    // Convert USD gas cost to USDC by dividing by the USDC/USD price.
    let usdc_usd_price = usdc_usd_price.into_raw();

    let price_scale = U256::from(10)
        .checked_pow(U256::from(usdc_usd_decimals))
        .ok_or_else(|| Error::other("USDC/USD decimal scaling overflow"))?;

    let numerator = U256::from(estimated_cost_usd)
        .checked_mul(price_scale)
        .ok_or_else(|| Error::other("USDC/USD numerator calculation overflow"))?;

    let estimated_cost_usdc = numerator / usdc_usd_price;

    // Apply the gas cost buffer (e.g., 10% buffer = 110% of estimated cost).
    let gas_cost_buffer_percent = U256::from(gas_cost_buffer_percent);

    let buffer_multiplier = U256::from(100)
        .checked_add(U256::from(gas_cost_buffer_percent))
        .ok_or_else(|| Error::other("Buffer multiplier calculation overflow"))?;

    let buffered_cost_numerator = estimated_cost_usdc
        .checked_mul(buffer_multiplier)
        .ok_or_else(|| Error::other("Buffer numerator calculation overflow"))?;

    // Convert to 6-decimal USDC, rounding up to avoid underestimating gas costs.
    let buffered_cost_usdc = buffered_cost_numerator.div_ceil(U256::from(DENOMINATOR));

    if buffered_cost_usdc > U256::from(EXECUTOR_REWARD_USDC) {
        return Ok(false);
    }

    let estimated_profit_usdc = U256::from(EXECUTOR_REWARD_USDC)
        .checked_sub(buffered_cost_usdc)
        .ok_or_else(|| Error::other("Profitability calculation underflow"))?;

    Ok(estimated_profit_usdc >= U256::from(minimum_profit_usdc))
}

#[cfg(test)]
mod tests {
    use std::error::Error;

    use alloy::primitives::I256;

    use super::is_profitable;

    // Default test values:
    // eth_usd_price = $100
    // usdc_usd_price = $1
    // minimum_profit_usdc = $0.10

    #[test]
    fn profitable_execution_returns_true() -> Result<(), Box<dyn Error>> {
        // Cost with buffer: $0.11
        // Profit: $0.69
        let result = is_profitable(
            I256::try_from(10_000_000_000u64)?,
            8,
            I256::try_from(100_000_000u64)?,
            8,
            // $0.10
            1_000_000_000_000_000,
            10,
            100_000,
        )?;

        assert_eq!(result, true);

        Ok(())
    }

    #[test]
    fn unprofitable_execution_returns_false() -> Result<(), Box<dyn Error>> {
        // Cost with buffer: $0.77
        // Profit: $0.03
        let result = is_profitable(
            I256::try_from(10_000_000_000u64)?,
            8,
            I256::try_from(100_000_000u64)?,
            8,
            // $0.70
            7_000_000_000_000_000,
            10,
            100_000,
        )?;

        assert_eq!(result, false);

        Ok(())
    }

    #[test]
    fn profit_equals_minimum_returns_true() -> Result<(), Box<dyn Error>> {
        // Cost with buffer: $0.70
        // Profit: $0.10
        let result = is_profitable(
            I256::try_from(10_000_000_000u64)?,
            8,
            I256::try_from(100_000_000u64)?,
            8,
            // $0.70
            7_000_000_000_000_000,
            // 0%
            0,
            100_000,
        )?;

        assert_eq!(result, true);

        Ok(())
    }

    #[test]
    fn profit_below_minimum_returns_false() -> Result<(), Box<dyn Error>> {
        // Cost with buffer: $0.700001
        // Profit $0.099999
        let result = is_profitable(
            I256::try_from(10_000_000_000u64)?,
            8,
            I256::try_from(100_000_000u64)?,
            8,
            // $0.700001 rounded up.
            7_000_000_000_000_001,
            // 0%
            0,
            100_000,
        )?;

        assert_eq!(result, false);

        Ok(())
    }

    #[test]
    fn gas_buffer_changes_profitability() -> Result<(), Box<dyn Error>> {
        // Cost with buffer: $0.70
        // Profit $0.10
        let without_buffer = is_profitable(
            I256::try_from(10_000_000_000u64)?,
            8,
            I256::try_from(100_000_000u64)?,
            8,
            7_000_000_000_000_000,
            0,
            100_000,
        )?;

        // Cost with buffer: $0.77
        // Profit $0.03
        let with_buffer = is_profitable(
            I256::try_from(10_000_000_000u64)?,
            8,
            I256::try_from(100_000_000u64)?,
            8,
            7_000_000_000_000_000,
            10,
            100_000,
        )?;

        assert!(without_buffer);
        assert!(!with_buffer);

        Ok(())
    }

    #[test]
    fn usdc_depeg_affects_profitability() -> Result<(), Box<dyn Error>> {
        // Cost with buffer: $0.693
        // Profit $0.107
        let without_depeg = is_profitable(
            I256::try_from(10_000_000_000u64)?,
            8,
            I256::try_from(100_000_000u64)?,
            8,
            6_300_000_000_000_000,
            10,
            100_000,
        )?;

        // Cost with buffer: $0.729474
        // Profit: 0.070526
        let with_depeg = is_profitable(
            I256::try_from(10_000_000_000u64)?,
            8,
            // $0.95
            I256::try_from(95_000_000u64)?,
            8,
            6_300_000_000_000_000,
            10,
            100_000,
        )?;

        assert!(without_depeg);
        assert!(!with_depeg);

        Ok(())
    }
}
