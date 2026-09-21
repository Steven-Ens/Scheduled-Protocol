// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract GetPaymentStatusTest is Test {
    address private payer;
    address private recipient;
    uint40 private executeAfter;

    ScheduledProtocol private scheduledProtocol;

    uint96 private constant VALID_AMOUNT = 100e6;
    // Delay added to `block.timestamp` to produce a valid future `executeAfter`.
    uint256 private constant VALID_EXECUTE_AFTER_DELAY = 1 days;
    uint24 private constant VALID_EXPIRES_AFTER = 1 hours;
    uint32 private constant VALID_ONE_TIME_TOTAL_OCCURRENCES = 1;
    uint32 private constant VALID_RECURRING_TOTAL_OCCURRENCES = 10;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");
        // Safe because the test timestamp plus one day is well below `type(uint40).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + VALID_EXECUTE_AFTER_DELAY);

        scheduledProtocol = new ScheduledProtocol();
    }

    //

    function test_GetPaymentStatus_RevertWhen_InvalidPaymentId() public {
        vm.startPrank(payer);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidPaymentId.selector, 0));

        scheduledProtocol.getPaymentStatus(0);

        vm.stopPrank();
    }

    // None

    function test_GetPaymentStatus_SuccessWhen_OneTimeIsBeforeExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_OneTimeIsAtExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_OneTimeIsBeforeFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration = executeAfter + uint40(VALID_EXPIRES_AFTER);

        vm.warp(finalWindowExpiration - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_OneTimeIsAtFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration = executeAfter + uint40(VALID_EXPIRES_AFTER);

        vm.warp(finalWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_OneTimeIsPastFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration = executeAfter + uint40(VALID_EXPIRES_AFTER);

        vm.warp(finalWindowExpiration + 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    // Daily

    function test_GetPaymentStatus_SuccessWhen_DailyIsBeforeExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyIsAtExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyIsPastIntermediateWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 intermediateWindowExpiration = executeAfter + 1 days + VALID_EXPIRES_AFTER;

        vm.warp(intermediateWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyIsBeforeFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 days) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyIsAtFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 days) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyIsPastFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 days) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration + 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    // Weekly

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsBeforeExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsAtExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsPastIntermediateWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 intermediateWindowExpiration = executeAfter + 1 weeks + VALID_EXPIRES_AFTER;

        vm.warp(intermediateWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsBeforeFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 weeks) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsAtFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 weeks) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsPastFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 weeks) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration + 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    // Monthly

    function test_GetPaymentStatus_SuccessWhen_MonthlyIsBeforeExecuteAfter() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_MonthlyIsAtExecuteAfter() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_MonthlyIsPastIntermediateWindowExpiration() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 intermediateWindowExpiration =
            BokkyPooBahsDateTimeLibrary.addMonths(executeAfter, 1) + VALID_EXPIRES_AFTER;

        vm.warp(intermediateWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_MonthlyIsBeforeFinalWindowExpiration() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration = BokkyPooBahsDateTimeLibrary.addMonths(
            executeAfter, VALID_RECURRING_TOTAL_OCCURRENCES - 1
        ) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_MonthlyIsAtFinalWindowExpiration() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration = BokkyPooBahsDateTimeLibrary.addMonths(
            executeAfter, VALID_RECURRING_TOTAL_OCCURRENCES - 1
        ) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_MonthlyIsPastFinalWindowExpiration() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        uint256 finalWindowExpiration = BokkyPooBahsDateTimeLibrary.addMonths(
            executeAfter, VALID_RECURRING_TOTAL_OCCURRENCES - 1
        ) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration + 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_MonthlyClampsFinalOccurrenceToFebruary() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        uint32 validRecurringTotalOccurrences = 2;

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            validRecurringTotalOccurrences
        );

        // February 28th, 2026 @ 10:00 UTC
        uint256 expectedFinalOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 10, 0, 0);

        vm.warp(expectedFinalOccurrenceStart + VALID_EXPIRES_AFTER);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_MonthlyPreservesOriginalAnchorDay() public {
        // April 30th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 30, 10, 0, 0));

        uint32 validRecurringTotalOccurrences = 2;

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            VALID_EXPIRES_AFTER,
            validRecurringTotalOccurrences
        );

        // May 30th, 2026 @ 10:00 UTC
        uint256 expectedFinalOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 5, 30, 10, 0, 0);

        vm.warp(expectedFinalOccurrenceStart + VALID_EXPIRES_AFTER);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }
}
