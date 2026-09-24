// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

// Exposes the internal _deriveOccurrence helper for testing.
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

contract OccurrenceDerivationTest is Test {
    uint40 private executeAfter;
    // Delay added to `block.timestamp` to produce a valid future `executeAfter`.
    uint256 private constant VALID_EXECUTE_AFTER_DELAY = 1 days;

    MockUSDC private mockUSDC;
    ScheduledProtocolHarness harness;

    function setUp() public {
        // Safe because the test timestamp plus one day is well below `type(uint40).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + VALID_EXECUTE_AFTER_DELAY);

        mockUSDC = new MockUSDC();
        harness = new ScheduledProtocolHarness(mockUSDC);
    }

    // None

    function test_OccurrenceDerivation_SuccessWhen_NoneDerivesOccurrenceZero() public view {
        uint256 timestamp = uint256(executeAfter);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.None, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, executeAfter);
    }

    function test_OccurrenceDerivation_SuccessWhen_NoneRemainsAtOccurrenceZero() public view {
        uint256 timestamp = uint256(executeAfter) + 100 days;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.None, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, executeAfter);
    }

    // Daily

    function test_OccurrenceDerivation_SuccessWhen_DailyIsAtFirstOccurrence() public view {
        uint256 timestamp = uint256(executeAfter);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsWithinFirstOccurrence() public view {
        uint256 timestamp = uint256(executeAfter) + 12 hours;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsAtEndOfFirstOccurrence() public view {
        uint256 timestamp = uint256(executeAfter) + 1 days - 1;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsAtSecondOccurrence() public view {
        uint256 timestamp = uint256(executeAfter) + 1 days;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, uint256(executeAfter) + 1 days);
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsWithinLaterOccurrence() public view {
        uint256 timestamp = uint256(executeAfter) + 3 days + 12 hours;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 3);
        assertEq(occurrenceStart, uint256(executeAfter) + 3 days);
    }

    // Weekly

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsAtFirstOccurrence() public view {
        uint256 timestamp = uint256(executeAfter);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Weekly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsWithinFirstOccurrence() public view {
        uint256 timestamp = uint256(executeAfter) + 3 days + 12 hours;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Weekly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsAtEndOfFirstOccurrence() public view {
        uint256 timestamp = uint256(executeAfter) + 1 weeks - 1;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Weekly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsAtSecondOccurrence() public view {
        uint256 timestamp = uint256(executeAfter) + 1 weeks;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Weekly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, uint256(executeAfter) + 1 weeks);
    }

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsWithinLaterOccurrence() public view {
        uint256 timestamp = uint256(executeAfter) + 3 weeks + 3 days;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Weekly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 3);
        assertEq(occurrenceStart, uint256(executeAfter) + 3 weeks);
    }

    // Monthly

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsAtFirstOccurrence() public {
        // January 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 15, 10, 0, 0));

        uint256 timestamp = uint256(executeAfter);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsWithinFirstOccurrence() public {
        // January 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 15, 10, 0, 0));

        // January 31st, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsAtEndOfFirstOccurrence() public {
        // January 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 15, 10, 0, 0));

        // February 15th, 2026 @ 09:59:59 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 15, 9, 59, 59);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsAtSecondOccurrence() public {
        // January 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 15, 10, 0, 0));

        // February 15th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 15, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsWithinLaterOccurrence() public {
        // January 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 15, 10, 0, 0));

        // April 30th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 30, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        // April 15th, 2026 @ 10:00 UTC
        uint256 expectedOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 15, 10, 0, 0);

        assertEq(occurrenceIndex, 3);
        assertEq(occurrenceStart, expectedOccurrenceStart);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsBeforeClampedOccurrence() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        // February 28th, 2026 @ 09:59:59 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 9, 59, 59);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, executeAfter);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyCorrectsFutureCandidateOccurrence() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        // March 1st, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 3, 1, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        // February 28th, 2026 @ 10:00 UTC
        uint256 expectedOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 10, 0, 0);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, expectedOccurrenceStart);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyClampsToFebruaryInNonLeapYear() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        // February 28th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyClampsToFebruaryInLeapYear() public {
        // January 31st, 2028 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2028, 1, 31, 10, 0, 0));

        // February 29th, 2028 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2028, 2, 29, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyRestoresOriginalAnchorDay() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        // March 31st, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 3, 31, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 2);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyPreservesOriginalAnchorDay() public {
        // April 30th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 30, 10, 0, 0));

        // May 30th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 5, 30, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyPreservesOriginalAnchorTime() public {
        // January 31st, 2026 @ 12:34:56 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 12, 34, 56));

        // February 28th, 2026 @ 12:34:56 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 12, 34, 56);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyCrossesYear() public {
        // December 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 12, 15, 10, 0, 0));

        // January 15th, 2027 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2027, 1, 15, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    // LastOfMonth

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthIsAtFirstOccurrence() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        uint256 timestamp = uint256(executeAfter);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthIsWithinFirstOccurrence() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        // February 15th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 15, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthIsAtEndOfFirstOccurrence() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        // February 28th, 2026 @ 09:59:59 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 9, 59, 59);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthIsAtSecondOccurrence() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        // February 28th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthIsWithinLaterOccurrence() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        // April 15th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 15, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        // March 31st, 2026 @ 10:00 UTC
        uint256 expectedOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 3, 31, 10, 0, 0);

        assertEq(occurrenceIndex, 2);
        assertEq(occurrenceStart, expectedOccurrenceStart);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthCorrectsFutureCandidateOccurrence() public {
        // April 30th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 30, 10, 0, 0));

        // May 30th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 5, 30, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, executeAfter);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthUsesLeapDay() public {
        // January 31st, 2028 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2028, 1, 31, 10, 0, 0));

        // February 29th, 2028 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2028, 2, 29, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthAdvancesFromFebruaryToMarch() public {
        // February 28th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 10, 0, 0));

        // March 31st, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 3, 31, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthAdvancesToFinalDay() public {
        // April 30th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 30, 10, 0, 0));

        // May 31st, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 5, 31, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthPreservesOriginalAnchorTime() public {
        // February 28th, 2026 @ 12:34:56 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 12, 34, 56));

        // March 31st, 2026 @ 12:34:56 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 3, 31, 12, 34, 56);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthCrossesYear() public {
        // December 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 12, 31, 10, 0, 0));

        // January 31st, 2027 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2027, 1, 31, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }
}
