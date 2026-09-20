// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

// Exposes the internal _deriveOccurrence helper for testing.
contract ScheduledProtocolHarness is ScheduledProtocol {
    function deriveOccurrence(RecurrenceType recurrence, uint40 executeAfter, uint256 timestamp)
        external
        pure
        returns (uint256 occurrenceIndex, uint256 occurrenceStart)
    {
        return _deriveOccurrence(recurrence, executeAfter, timestamp);
    }
}

contract OccurrenceDerivationTest is Test {
    address private payer;
    address private recipient;
    uint40 private executeAfter;

    ScheduledProtocol private scheduledProtocol;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");
        executeAfter = uint40(block.timestamp + 1 days);

        scheduledProtocol = new ScheduledProtocol();
    }

    function test_ExecutePayment_RevertWhen_InvalidPaymentId() public {
        vm.startPrank(payer);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidPaymentId.selector, 0));

        scheduledProtocol.executePayment(0);

        vm.stopPrank();
    }

    function test_ExecutePayment_RevertWhen_BeforeExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient, 100e6, IScheduledProtocol.RecurrenceType.None, executeAfter, 1 hours, 1
        );

        vm.warp(executeAfter - 1);

        vm.expectRevert(
            abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolExecutionNotStarted.selector, executeAfter)
        );

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    function test_OccurrenceDerivation_SuccessWhen_NoneDerivesOccurrenceZero() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.None, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, executeAfter);
    }

    function test_OccurrenceDerivation_SuccessWhen_NoneRemainsAtOccurrenceZero() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter) + 100 days;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.None, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, executeAfter);
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsAtFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsWithinFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter) + 12 hours;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsAtEndOfFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter) + 1 days - 1;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsAtSecondOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter) + 1 days;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, uint256(executeAfter) + 1 days);
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsWithinLaterOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter) + 3 days + 12 hours;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 3);
        assertEq(occurrenceStart, uint256(executeAfter) + 3 days);
    }

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsAtFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Weekly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsWithinFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter) + 3 days + 12 hours;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Weekly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsAtEndOfFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter) + 1 weeks - 1;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Weekly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsAtSecondOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter) + 1 weeks;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Weekly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, uint256(executeAfter) + 1 weeks);
    }

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsWithinLaterOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint256 timestamp = uint256(executeAfter) + 3 weeks + 3 days;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Weekly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 3);
        assertEq(occurrenceStart, uint256(executeAfter) + 3 weeks);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsAtFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // January 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 15, 10, 0, 0));

        uint256 timestamp = uint256(executeAfter);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsWithinFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // January 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 15, 10, 0, 0));

        // February 15th, 2026 @ 9:59:59 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 15, 9, 59, 59);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsAtSecondOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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

    function test_OccurrenceDerivation_SuccessWhen_MonthlyCorrectsFutureCandidateOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // January 31st, 2026 @ 12:34:56 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 12, 34, 56));

        // February 28th, 2026 @ 12:34:56 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 12, 34, 56);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsBeforeClampedOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        // February 28th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 9, 59, 59);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, executeAfter);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyCrossesYear() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // December 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 12, 15, 10, 0, 0));

        // January 15th, 2027 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2027, 1, 15, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthIsAtFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        uint256 timestamp = uint256(executeAfter);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthIsWithinFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        // February 28th, 2026 @ 9:59:59 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 9, 59, 59);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthIsAtSecondOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthAdvancesToFinalDay() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // April 30th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 30, 10, 0, 0));

        // May 31st, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 5, 31, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthDoesNotAdvanceEarly() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // February 28th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 10, 0, 0));

        // March 31st, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 3, 31, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.LastOfMonth, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_LastOfMonthPreservesOriginalAnchorTime() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

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
