// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract CreatePaymentTest is Test {
    address private payer;
    address private recipient;
    uint40 private executeAfter;

    ScheduledProtocol private scheduledProtocol;

    uint96 private constant VALID_AMOUNT = 100e6;
    // Delay added to `block.timestamp` to produce a valid future `executeAfter`.
    uint256 private constant VALID_EXECUTE_AFTER_DELAY = 1 days;
    uint24 private constant VALID_EXPIRES_AFTER = 1 hours;

    uint96 private constant MIN_VALID_AMOUNT = 1;
    uint256 private constant MIN_VALID_EXECUTE_AFTER_DELAY = 1 seconds;
    uint24 private constant MIN_VALID_EXPIRES_AFTER = 1;

    uint32 private constant ONE_TIME_TOTAL_OCCURRENCES = 1;
    uint32 private constant MIN_RECURRING_TOTAL_OCCURRENCES = 2;

    uint24 private constant ONE_TIME_MAX_EXPIRES_AFTER = 28 days;
    uint24 private constant DAILY_MAX_EXPIRES_AFTER = 1 days;
    uint24 private constant WEEKLY_MAX_EXPIRES_AFTER = 1 weeks;
    uint24 private constant MONTHLY_MAX_EXPIRES_AFTER = 28 days;
    uint24 private constant LAST_OF_MONTH_MAX_EXPIRES_AFTER = 28 days;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");
        // Safe because the test timestamp plus one day is well below `type(uint40).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + VALID_EXECUTE_AFTER_DELAY);

        scheduledProtocol = new ScheduledProtocol();
    }

    function test_CreatePayment_StoresPaymentSchedule() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);

        vm.stopPrank();

        assertEq(payment.payer, payer);
        assertEq(payment.recipient, recipient);
        assertEq(payment.amount, VALID_AMOUNT);
        assertEq(uint8(payment.recurrence), uint8(IScheduledProtocol.RecurrenceType.None));
        assertEq(payment.executeAfter, executeAfter);
        assertEq(payment.expiresAfter, VALID_EXPIRES_AFTER);
        assertEq(payment.totalOccurrences, ONE_TIME_TOTAL_OCCURRENCES);
        assertEq(payment.lastExecutedOccurrencePlusOne, 0);
        assertFalse(payment.cancelled);
    }

    function test_CreatePayment_AssignsSequentialPaymentIds() public {
        vm.startPrank(payer);

        uint256 paymentIdOne = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        uint256 paymentIdTwo = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();

        assertEq(paymentIdOne, 0);
        assertEq(paymentIdTwo, 1);
    }

    function test_CreatePayment_EmitsPaymentCreated() public {
        vm.startPrank(payer);

        // Check all indexed topics, event data, and the emitting contract.
        vm.expectEmit(true, true, true, true, address(scheduledProtocol));

        emit IScheduledProtocol.PaymentCreated(
            0,
            payer,
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_RecipientIsZeroAddress() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidRecipient.selector, address(0))
        );

        scheduledProtocol.createPayment(
            address(0),
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_AmountIsZero() public {
        vm.startPrank(payer);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidAmount.selector, 0));

        scheduledProtocol.createPayment(
            recipient,
            0,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_WhenAmountIsMinimumValidValue() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            MIN_VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_ExecuteAfterIsOneSecondInPast() public {
        vm.startPrank(payer);

        uint40 invalidExecuteAfter = uint40(block.timestamp - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolInvalidExecuteAfter.selector, invalidExecuteAfter
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            invalidExecuteAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_ExecuteAfterEqualsBlockTimestamp() public {
        vm.startPrank(payer);

        uint40 invalidExecuteAfter = uint40(block.timestamp);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolInvalidExecuteAfter.selector, invalidExecuteAfter
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            invalidExecuteAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_WhenExecuteAfterIsOneSecondInFuture() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            // Safe because the test timestamp plus one is well below `type(uint40).max`.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint40(block.timestamp + MIN_VALID_EXECUTE_AFTER_DELAY),
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_ExpiresAfterIsZero() public {
        vm.startPrank(payer);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidExpiresAfter.selector, 0));

        scheduledProtocol.createPayment(
            recipient, VALID_AMOUNT, IScheduledProtocol.RecurrenceType.None, executeAfter, 0, ONE_TIME_TOTAL_OCCURRENCES
        );
        vm.stopPrank();
    }

    function test_CreatePayment_WhenExpiresAfterIsMinimumValidValue() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            MIN_VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    // `RecurrenceType` bounds are enforced by Solidity's ABI decoder. These tests cover valid enum values and their
    // protocol-specific constraints.

    function test_CreatePayment_RevertWhen_NoneHasZeroTotalOccurrences() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolInvalidTotalOccurrences.selector,
                IScheduledProtocol.RecurrenceType.None,
                0
            )
        );

        scheduledProtocol.createPayment(
            recipient, VALID_AMOUNT, IScheduledProtocol.RecurrenceType.None, executeAfter, VALID_EXPIRES_AFTER, 0
        );
        vm.stopPrank();
    }

    function test_CreatePayment_WhenNoneHasOneTotalOccurrence() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_NoneHasMultipleTotalOccurrences() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolInvalidTotalOccurrences.selector,
                IScheduledProtocol.RecurrenceType.None,
                MIN_RECURRING_TOTAL_OCCURRENCES
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            MIN_RECURRING_TOTAL_OCCURRENCES
        );
        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_RecurringHasZeroTotalOccurrences() public {
        IScheduledProtocol.RecurrenceType[4] memory recurringTypes = _recurringTypes();

        vm.startPrank(payer);

        for (uint256 i; i < recurringTypes.length; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IScheduledProtocol.ScheduledProtocolInvalidTotalOccurrences.selector, recurringTypes[i], 0
                )
            );

            scheduledProtocol.createPayment(
                recipient, VALID_AMOUNT, recurringTypes[i], executeAfter, VALID_EXPIRES_AFTER, 0
            );
        }
        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_RecurringHasOneTotalOccurrence() public {
        IScheduledProtocol.RecurrenceType[4] memory recurringTypes = _recurringTypes();

        vm.startPrank(payer);

        for (uint256 i; i < recurringTypes.length; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IScheduledProtocol.ScheduledProtocolInvalidTotalOccurrences.selector,
                    recurringTypes[i],
                    ONE_TIME_TOTAL_OCCURRENCES
                )
            );

            scheduledProtocol.createPayment(
                recipient,
                VALID_AMOUNT,
                recurringTypes[i],
                executeAfter,
                VALID_EXPIRES_AFTER,
                ONE_TIME_TOTAL_OCCURRENCES
            );
        }
        vm.stopPrank();
    }

    function test_CreatePayment_WhenRecurringHasMinimumTotalOccurrences() public {
        IScheduledProtocol.RecurrenceType[4] memory recurringTypes = _recurringTypes();

        vm.startPrank(payer);

        for (uint256 i; i < recurringTypes.length; ++i) {
            scheduledProtocol.createPayment(
                recipient,
                VALID_AMOUNT,
                recurringTypes[i],
                executeAfter,
                VALID_EXPIRES_AFTER,
                MIN_RECURRING_TOTAL_OCCURRENCES
            );
        }
        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_OneTimeExecutionWindowIsTooLong() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolExecutionWindowTooLong.selector,
                IScheduledProtocol.RecurrenceType.None,
                ONE_TIME_MAX_EXPIRES_AFTER + 1,
                ONE_TIME_MAX_EXPIRES_AFTER
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            ONE_TIME_MAX_EXPIRES_AFTER + 1,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_WhenOneTimeExecutionWindowIsMaximum() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            ONE_TIME_MAX_EXPIRES_AFTER,
            ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_DailyExecutionWindowIsTooLong() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolExecutionWindowTooLong.selector,
                IScheduledProtocol.RecurrenceType.Daily,
                DAILY_MAX_EXPIRES_AFTER + 1,
                DAILY_MAX_EXPIRES_AFTER
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            DAILY_MAX_EXPIRES_AFTER + 1,
            MIN_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_WhenDailyExecutionWindowIsMaximum() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            DAILY_MAX_EXPIRES_AFTER,
            MIN_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_WeeklyExecutionWindowIsTooLong() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolExecutionWindowTooLong.selector,
                IScheduledProtocol.RecurrenceType.Weekly,
                WEEKLY_MAX_EXPIRES_AFTER + 1,
                WEEKLY_MAX_EXPIRES_AFTER
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            executeAfter,
            WEEKLY_MAX_EXPIRES_AFTER + 1,
            MIN_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_WhenWeeklyExecutionWindowIsMaximum() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            executeAfter,
            WEEKLY_MAX_EXPIRES_AFTER,
            MIN_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_MonthlyExecutionWindowIsTooLong() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolExecutionWindowTooLong.selector,
                IScheduledProtocol.RecurrenceType.Monthly,
                MONTHLY_MAX_EXPIRES_AFTER + 1,
                MONTHLY_MAX_EXPIRES_AFTER
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            MONTHLY_MAX_EXPIRES_AFTER + 1,
            MIN_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_WhenMonthlyExecutionWindowIsMaximum() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            MONTHLY_MAX_EXPIRES_AFTER,
            MIN_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_LastOfMonthExecutionWindowIsTooLong() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolExecutionWindowTooLong.selector,
                IScheduledProtocol.RecurrenceType.LastOfMonth,
                LAST_OF_MONTH_MAX_EXPIRES_AFTER + 1,
                LAST_OF_MONTH_MAX_EXPIRES_AFTER
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.LastOfMonth,
            executeAfter,
            LAST_OF_MONTH_MAX_EXPIRES_AFTER + 1,
            MIN_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_WhenLastOfMonthExecutionWindowIsMaximum() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.LastOfMonth,
            executeAfter,
            LAST_OF_MONTH_MAX_EXPIRES_AFTER,
            MIN_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    // Helper
    function _recurringTypes() private pure returns (IScheduledProtocol.RecurrenceType[4] memory recurringTypes) {
        recurringTypes = [
            IScheduledProtocol.RecurrenceType.Daily,
            IScheduledProtocol.RecurrenceType.Weekly,
            IScheduledProtocol.RecurrenceType.Monthly,
            IScheduledProtocol.RecurrenceType.LastOfMonth
        ];
    }
}
