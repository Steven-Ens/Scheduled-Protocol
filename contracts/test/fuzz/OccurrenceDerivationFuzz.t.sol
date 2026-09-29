// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";
import {ScheduledProtocolHarness} from "../utils/ScheduledProtocolHarness.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";

contract OccurrenceDerivationFuzzTest is Test {
    uint40 private executeAfter;

    MockUSDC private mockUSDC;
    ScheduledProtocolHarness private harness;

    function setUp() public {
        // Safe because the test timestamp plus one day is well below type(uint40).max.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + 1 days);

        mockUSDC = new MockUSDC();
        harness = new ScheduledProtocolHarness(mockUSDC);
    }

    function testFuzz_OccurrenceDerivation_SuccessWhen_FixedIntervalDerivesCurrentOccurrence(
        bool daily,
        uint32 expectedOccurrenceIndex,
        uint256 offset
    ) public view {
        // Select one of the two fixed-interval recurrence types.
        IScheduledProtocol.RecurrenceType recurrence =
            daily ? IScheduledProtocol.RecurrenceType.Daily : IScheduledProtocol.RecurrenceType.Weekly;

        uint256 interval = daily ? 1 days : 1 weeks;

        // Constrain the fuzzed offset to a timestamp within the expected occurrence.
        offset = bound(offset, 0, interval - 1);

        // Construct the exact start of the fuzzed occurrence.
        uint256 expectedOccurrenceStart = uint256(executeAfter) + (uint256(expectedOccurrenceIndex) * interval);

        // Choose an arbitrary timestamp within that occurrence.
        uint256 timestamp = expectedOccurrenceStart + offset;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(recurrence, executeAfter, timestamp);

        // The derived occurrence must match the occurrence used to construct the timestamp.
        assertEq(occurrenceIndex, expectedOccurrenceIndex);
        assertEq(occurrenceStart, expectedOccurrenceStart);
    }
}
