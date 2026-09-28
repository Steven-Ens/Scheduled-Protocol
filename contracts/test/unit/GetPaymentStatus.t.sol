// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract GetPaymentStatusTest is Test {
    address private payer;
    address private recipient;
    uint40 private executeAfter;

    MockUSDC private mockUSDC;
    ScheduledProtocol private scheduledProtocol;

    uint32 private constant MIN_VALID_RECURRING_TOTAL_OCCURRENCES = 2;

    uint96 private constant VALID_AMOUNT = 100e6;
    // Delay added to `block.timestamp` to produce a valid future `executeAfter`.
    uint256 private constant VALID_EXECUTE_AFTER_DELAY = 1 days;
    uint24 private constant VALID_EXPIRES_AFTER = 1 hours;
    uint32 private constant VALID_ONE_TIME_TOTAL_OCCURRENCES = 1;
    uint32 private constant VALID_RECURRING_TOTAL_OCCURRENCES = 10;

    uint96 private constant MAX_VALID_AMOUNT = type(uint96).max;
    uint40 private constant MAX_VALID_EXECUTE_AFTER = type(uint40).max;

    uint24 private constant MAX_VALID_ONE_TIME_EXPIRES_AFTER = 28 days;
    uint24 private constant MAX_VALID_DAILY_EXPIRES_AFTER = 1 days;
    uint24 private constant MAX_VALID_WEEKLY_EXPIRES_AFTER = 1 weeks;
    uint24 private constant MAX_VALID_MONTHLY_EXPIRES_AFTER = 28 days;
    uint24 private constant MAX_VALID_LAST_OF_MONTH_EXPIRES_AFTER = 28 days;

    uint32 private constant MAX_VALID_RECURRING_TOTAL_OCCURRENCES = type(uint32).max;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");
        // Safe because the test timestamp plus one day is well below `type(uint40).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + VALID_EXECUTE_AFTER_DELAY);

        mockUSDC = new MockUSDC();
        scheduledProtocol = new ScheduledProtocol(mockUSDC);
    }

    // Payment ID validation

    function test_GetPaymentStatus_RevertWhen_InvalidPaymentId() public {
        vm.startPrank(payer);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidPaymentId.selector, 0));

        scheduledProtocol.getPaymentStatus(0);

        vm.stopPrank();
    }

    // Payment cancellation validation

    function test_GetPaymentStatus_SuccessWhen_PaymentIsCancelled() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.None, VALID_ONE_TIME_TOTAL_OCCURRENCES);

        scheduledProtocol.cancelPayment(paymentId);

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);
        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertTrue(payment.cancelled);
        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Cancelled));
    }

    function test_GetPaymentStatus_SuccessWhen_PaymentRemainsCancelledAtFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.None, VALID_ONE_TIME_TOTAL_OCCURRENCES);

        scheduledProtocol.cancelPayment(paymentId);

        vm.warp(executeAfter + VALID_EXPIRES_AFTER);

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);
        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertTrue(payment.cancelled);
        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Cancelled));
    }

    // None

    function test_GetPaymentStatus_SuccessWhen_OneTimeIsBeforeExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.None, VALID_ONE_TIME_TOTAL_OCCURRENCES);

        vm.warp(executeAfter - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_OneTimeIsAtExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.None, VALID_ONE_TIME_TOTAL_OCCURRENCES);

        vm.warp(executeAfter);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_OneTimeIsBeforeFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.None, VALID_ONE_TIME_TOTAL_OCCURRENCES);

        uint256 finalWindowExpiration = uint256(executeAfter) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_OneTimeIsAtFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.None, VALID_ONE_TIME_TOTAL_OCCURRENCES);

        uint256 finalWindowExpiration = uint256(executeAfter) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_OneTimeIsPastFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.None, VALID_ONE_TIME_TOTAL_OCCURRENCES);

        uint256 finalWindowExpiration = uint256(executeAfter) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration + 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_OneTimeHasMaximumValidValues() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            MAX_VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            MAX_VALID_EXECUTE_AFTER,
            MAX_VALID_ONE_TIME_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();
    }

    // Daily

    function test_GetPaymentStatus_SuccessWhen_DailyIsBeforeExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Daily, VALID_RECURRING_TOTAL_OCCURRENCES);

        vm.warp(executeAfter - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyIsAtExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Daily, VALID_RECURRING_TOTAL_OCCURRENCES);

        vm.warp(executeAfter);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyIsAtIntermediateWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Daily, VALID_RECURRING_TOTAL_OCCURRENCES);

        uint256 intermediateWindowExpiration = executeAfter + 1 days + VALID_EXPIRES_AFTER;

        vm.warp(intermediateWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyIsBeforeFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Daily, VALID_RECURRING_TOTAL_OCCURRENCES);

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 days) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyIsAtFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Daily, VALID_RECURRING_TOTAL_OCCURRENCES);

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 days) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyIsPastFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Daily, VALID_RECURRING_TOTAL_OCCURRENCES);

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 days) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration + 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_DailyHasMaximumValidValues() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            MAX_VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            MAX_VALID_EXECUTE_AFTER,
            MAX_VALID_DAILY_EXPIRES_AFTER,
            MAX_VALID_RECURRING_TOTAL_OCCURRENCES
        );

        scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();
    }

    // Weekly

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsBeforeExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Weekly, VALID_RECURRING_TOTAL_OCCURRENCES);

        vm.warp(executeAfter - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsAtExecuteAfter() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Weekly, VALID_RECURRING_TOTAL_OCCURRENCES);

        vm.warp(executeAfter);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsAtIntermediateWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Weekly, VALID_RECURRING_TOTAL_OCCURRENCES);

        uint256 intermediateWindowExpiration = executeAfter + 1 weeks + VALID_EXPIRES_AFTER;

        vm.warp(intermediateWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsBeforeFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Weekly, VALID_RECURRING_TOTAL_OCCURRENCES);

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 weeks) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsAtFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Weekly, VALID_RECURRING_TOTAL_OCCURRENCES);

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 weeks) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyIsPastFinalWindowExpiration() public {
        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Weekly, VALID_RECURRING_TOTAL_OCCURRENCES);

        uint256 finalWindowExpiration =
            executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 weeks) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration + 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_WeeklyHasMaximumValidValues() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            MAX_VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            MAX_VALID_EXECUTE_AFTER,
            MAX_VALID_WEEKLY_EXPIRES_AFTER,
            MAX_VALID_RECURRING_TOTAL_OCCURRENCES
        );

        scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();
    }

    // Monthly

    function test_GetPaymentStatus_SuccessWhen_MonthlyIsBeforeExecuteAfter() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Monthly, VALID_RECURRING_TOTAL_OCCURRENCES);

        vm.warp(executeAfter - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_MonthlyIsAtExecuteAfter() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Monthly, VALID_RECURRING_TOTAL_OCCURRENCES);

        vm.warp(executeAfter);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_MonthlyIsAtIntermediateWindowExpiration() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Monthly, VALID_RECURRING_TOTAL_OCCURRENCES);

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

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Monthly, VALID_RECURRING_TOTAL_OCCURRENCES);

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

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Monthly, VALID_RECURRING_TOTAL_OCCURRENCES);

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

        uint256 paymentId = _createPayment(IScheduledProtocol.RecurrenceType.Monthly, VALID_RECURRING_TOTAL_OCCURRENCES);

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

        vm.startPrank(payer);

        uint256 paymentId =
            _createPayment(IScheduledProtocol.RecurrenceType.Monthly, MIN_VALID_RECURRING_TOTAL_OCCURRENCES);

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

        vm.startPrank(payer);

        uint256 paymentId =
            _createPayment(IScheduledProtocol.RecurrenceType.Monthly, MIN_VALID_RECURRING_TOTAL_OCCURRENCES);

        // May 30th, 2026 @ 10:00 UTC
        uint256 expectedFinalOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 5, 30, 10, 0, 0);

        vm.warp(expectedFinalOccurrenceStart + VALID_EXPIRES_AFTER);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_MonthlyHasMaximumValidValues() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            MAX_VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            MAX_VALID_EXECUTE_AFTER,
            MAX_VALID_MONTHLY_EXPIRES_AFTER,
            MAX_VALID_RECURRING_TOTAL_OCCURRENCES
        );

        scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();
    }

    // LastOfMonth

    function test_GetPaymentStatus_SuccessWhen_LastOfMonthIsBeforeExecuteAfter() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId =
            _createPayment(IScheduledProtocol.RecurrenceType.LastOfMonth, VALID_RECURRING_TOTAL_OCCURRENCES);

        vm.warp(executeAfter - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_LastOfMonthIsAtExecuteAfter() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId =
            _createPayment(IScheduledProtocol.RecurrenceType.LastOfMonth, VALID_RECURRING_TOTAL_OCCURRENCES);

        vm.warp(executeAfter);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_LastOfMonthIsAtIntermediateWindowExpiration() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId =
            _createPayment(IScheduledProtocol.RecurrenceType.LastOfMonth, VALID_RECURRING_TOTAL_OCCURRENCES);

        // February 28th, 2026 @ 10:00 UTC
        uint256 intermediateOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 10, 0, 0);

        uint256 intermediateWindowExpiration = intermediateOccurrenceStart + VALID_EXPIRES_AFTER;

        vm.warp(intermediateWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_LastOfMonthIsBeforeFinalWindowExpiration() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId =
            _createPayment(IScheduledProtocol.RecurrenceType.LastOfMonth, VALID_RECURRING_TOTAL_OCCURRENCES);

        // October 31st, 2026 @ 10:00 UTC
        uint256 finalWindowExpiration =
            BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 10, 31, 10, 0, 0) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration - 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_GetPaymentStatus_SuccessWhen_LastOfMonthIsAtFinalWindowExpiration() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId =
            _createPayment(IScheduledProtocol.RecurrenceType.LastOfMonth, VALID_RECURRING_TOTAL_OCCURRENCES);

        // October 31st, 2026 @ 10:00 UTC
        uint256 finalWindowExpiration =
            BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 10, 31, 10, 0, 0) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_LastOfMonthIsPastFinalWindowExpiration() public {
        // January 31st, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 1, 31, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId =
            _createPayment(IScheduledProtocol.RecurrenceType.LastOfMonth, VALID_RECURRING_TOTAL_OCCURRENCES);

        // October 31st, 2026 @ 10:00 UTC
        uint256 finalWindowExpiration =
            BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 10, 31, 10, 0, 0) + VALID_EXPIRES_AFTER;

        vm.warp(finalWindowExpiration + 1);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_LastOfMonthAdvancesFromFebruaryToMarch() public {
        // February 28th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 2, 28, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId =
            _createPayment(IScheduledProtocol.RecurrenceType.LastOfMonth, MIN_VALID_RECURRING_TOTAL_OCCURRENCES);

        // March 28th, 2026 @ 10:00 UTC
        uint256 incorrectFinalOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 3, 28, 10, 0, 0);

        vm.warp(incorrectFinalOccurrenceStart + VALID_EXPIRES_AFTER);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));

        // March 31st, 2026 @ 10:00 UTC
        uint256 expectedFinalOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 3, 31, 10, 0, 0);

        vm.warp(expectedFinalOccurrenceStart + VALID_EXPIRES_AFTER);

        status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_LastOfMonthAdvancesToFinalDay() public {
        // April 30th, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 30, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId =
            _createPayment(IScheduledProtocol.RecurrenceType.LastOfMonth, MIN_VALID_RECURRING_TOTAL_OCCURRENCES);

        // May 30th, 2026 @ 10:00 UTC
        uint256 incorrectFinalOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 5, 30, 10, 0, 0);

        vm.warp(incorrectFinalOccurrenceStart + VALID_EXPIRES_AFTER);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));

        // May 31st, 2026 @ 10:00 UTC
        uint256 expectedFinalOccurrenceStart = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 5, 31, 10, 0, 0);

        vm.warp(expectedFinalOccurrenceStart + VALID_EXPIRES_AFTER);

        status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    function test_GetPaymentStatus_SuccessWhen_LastOfMonthHasMaximumValidValues() public {
        // Latest last-of-month timestamp representable by uint40:
        // January 31st, 36812 @ 23:59:59 UTC.
        uint40 MAX_VALID_LAST_OF_MONTH_EXECUTE_AFTER = 1_099_509_983_999;

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            MAX_VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.LastOfMonth,
            MAX_VALID_LAST_OF_MONTH_EXECUTE_AFTER,
            MAX_VALID_LAST_OF_MONTH_EXPIRES_AFTER,
            MAX_VALID_RECURRING_TOTAL_OCCURRENCES
        );

        scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        // January 31st, 36812 @ 23:59:59 UTC.
        uint256 expectedExecuteAfter = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(36812, 1, 31, 23, 59, 59);

        assertEq(MAX_VALID_LAST_OF_MONTH_EXECUTE_AFTER, expectedExecuteAfter);
    }

    // Helpers

    function _createPayment(IScheduledProtocol.RecurrenceType recurrence, uint32 totalOccurrences)
        private
        returns (uint256 paymentId)
    {
        paymentId = scheduledProtocol.createPayment(
            recipient, VALID_AMOUNT, recurrence, executeAfter, VALID_EXPIRES_AFTER, totalOccurrences
        );
    }
}
