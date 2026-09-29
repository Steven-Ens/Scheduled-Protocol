// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

// Exposes the internal `_deriveOccurrence` helper for testing.
contract ScheduledProtocolHarness is ScheduledProtocol {
    constructor(IERC20 usdc_) ScheduledProtocol(usdc_) {}

    function deriveOccurrence(RecurrenceType recurrence, uint40 executeAfter, uint256 timestamp)
        external
        pure
        returns (uint256 occurrenceIndex, uint256 occurrenceStart)
    {
        return _deriveOccurrence(recurrence, executeAfter, timestamp);
    }
}
