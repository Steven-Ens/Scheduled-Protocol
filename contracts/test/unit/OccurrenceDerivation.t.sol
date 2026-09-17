// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

// external wrapper for _deriveOccurrence.
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

    function test_OccurrenceDerivation_RevertWhen_InvalidPaymentId() public {
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

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.None, executeAfter, block.timestamp);

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

    function test_OccurrenceDerivation_SuccessWhen_DailyIsWithinFutureOccurrence() public {
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

    function test_OccurrenceDerivation_SuccessWhen_WeeklyIsWithinFutureOccurrence() public {
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

        vm.warp(executeAfter);

        uint256 timestamp = block.timestamp;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsWithinFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // January 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 15, 10, 0, 0));

        vm.warp(executeAfter);

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

        vm.warp(executeAfter);

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

        vm.warp(executeAfter);

        // February 15th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 15, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, timestamp);
    }

    function test_OccurrenceDerivation_SuccessWhen_MonthlyIsWithinFutureOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        // January 15th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 15, 10, 0, 0));

        vm.warp(executeAfter);

        // April 30th, 2026 @ 10:00 UTC
        uint256 timestamp = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 30, 10, 0, 0);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Monthly, executeAfter, timestamp);

        // April 15th, 2026 @ 10:00 UTC
        uint256 expectedOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 15, 10, 0, 0);

        assertEq(occurrenceIndex, 3);
        assertEq(occurrenceStart, expectedOccurrenceStart);
    }
}
