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

    uint96 private constant MIN_VALID_AMOUNT = 1;
    uint256 private constant MIN_VALID_EXECUTE_AFTER_DELAY = 1 seconds;
    uint24 private constant MIN_VALID_EXPIRES_AFTER = 1 seconds;
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

        scheduledProtocol = new ScheduledProtocol();
    }

    function test_CreatePayment_SuccessWhen_StoresPaymentSchedule() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);

        vm.stopPrank();

        // Confirm msg.sender is stored.
        assertEq(payment.payer, payer);
        assertEq(payment.recipient, recipient);
        assertEq(payment.amount, VALID_AMOUNT);
        assertEq(uint8(payment.recurrence), uint8(IScheduledProtocol.RecurrenceType.None));
        assertEq(payment.executeAfter, executeAfter);
        assertEq(payment.expiresAfter, VALID_EXPIRES_AFTER);
        assertEq(payment.totalOccurrences, VALID_ONE_TIME_TOTAL_OCCURRENCES);
        // Confirm default type values for mutable state.
        assertEq(payment.lastExecutedOccurrencePlusOne, 0);
        assertFalse(payment.cancelled);
    }

    function test_CreatePayment_SuccessWhen_AssignsSequentialPaymentIds() public {
        vm.startPrank(payer);

        uint256 paymentIdOne = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        uint256 paymentIdTwo = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();

        assertEq(paymentIdOne, 0);
        assertEq(paymentIdTwo, 1);
    }

    function test_CreatePayment_SuccessWhen_EmitsPaymentCreated() public {
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
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
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
            VALID_ONE_TIME_TOTAL_OCCURRENCES
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
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_AmountIsMinimumValidValue() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            MIN_VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_AmountIsMaximumValidValue() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            MAX_VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);

        vm.stopPrank();

        assertEq(payment.amount, MAX_VALID_AMOUNT);
    }

    function test_CreatePayment_RevertWhen_ExecuteAfterIsOneSecondInPast() public {
        uint40 invalidPastExecuteAfter = uint40(block.timestamp - 1);

        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolInvalidExecuteAfter.selector, invalidPastExecuteAfter
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            invalidPastExecuteAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_ExecuteAfterEqualsBlockTimestamp() public {
        uint40 invalidCurrentExecuteAfter = uint40(block.timestamp);

        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolInvalidExecuteAfter.selector, invalidCurrentExecuteAfter
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            invalidCurrentExecuteAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_ExecuteAfterIsMinimumValidValue() public {
        // Safe because the test timestamp plus one second is well below `type(uint40).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint40 minValidExecuteAfter = uint40(block.timestamp + MIN_VALID_EXECUTE_AFTER_DELAY);

        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            minValidExecuteAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_ExecuteAfterIsMaximumValidValue() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            MAX_VALID_EXECUTE_AFTER,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);

        vm.stopPrank();

        assertEq(payment.executeAfter, MAX_VALID_EXECUTE_AFTER);
    }

    function test_CreatePayment_RevertWhen_ExpiresAfterIsZero() public {
        vm.startPrank(payer);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidExpiresAfter.selector, 0));

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            0,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_ExpiresAfterIsMinimumValidValue() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            MIN_VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_OneTimeExecutionWindowIsMaximumValidValue() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            MAX_VALID_ONE_TIME_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_OneTimeExecutionWindowIsTooLong() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolExecutionWindowTooLong.selector,
                IScheduledProtocol.RecurrenceType.None,
                MAX_VALID_ONE_TIME_EXPIRES_AFTER + 1,
                MAX_VALID_ONE_TIME_EXPIRES_AFTER
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            MAX_VALID_ONE_TIME_EXPIRES_AFTER + 1,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_DailyExecutionWindowIsMaximumValidValue() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            MAX_VALID_DAILY_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_DailyExecutionWindowIsTooLong() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolExecutionWindowTooLong.selector,
                IScheduledProtocol.RecurrenceType.Daily,
                MAX_VALID_DAILY_EXPIRES_AFTER + 1,
                MAX_VALID_DAILY_EXPIRES_AFTER
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            MAX_VALID_DAILY_EXPIRES_AFTER + 1,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_WeeklyExecutionWindowIsMaximumValidValue() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            executeAfter,
            MAX_VALID_WEEKLY_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_WeeklyExecutionWindowIsTooLong() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolExecutionWindowTooLong.selector,
                IScheduledProtocol.RecurrenceType.Weekly,
                MAX_VALID_WEEKLY_EXPIRES_AFTER + 1,
                MAX_VALID_WEEKLY_EXPIRES_AFTER
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Weekly,
            executeAfter,
            MAX_VALID_WEEKLY_EXPIRES_AFTER + 1,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_MonthlyExecutionWindowIsMaximumValidValue() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            MAX_VALID_MONTHLY_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_MonthlyExecutionWindowIsTooLong() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolExecutionWindowTooLong.selector,
                IScheduledProtocol.RecurrenceType.Monthly,
                MAX_VALID_MONTHLY_EXPIRES_AFTER + 1,
                MAX_VALID_MONTHLY_EXPIRES_AFTER
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Monthly,
            executeAfter,
            MAX_VALID_MONTHLY_EXPIRES_AFTER + 1,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_LastOfMonthExecutionWindowIsMaximumValidValue() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.LastOfMonth,
            executeAfter,
            MAX_VALID_LAST_OF_MONTH_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_LastOfMonthExecutionWindowIsTooLong() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolExecutionWindowTooLong.selector,
                IScheduledProtocol.RecurrenceType.LastOfMonth,
                MAX_VALID_LAST_OF_MONTH_EXPIRES_AFTER + 1,
                MAX_VALID_LAST_OF_MONTH_EXPIRES_AFTER
            )
        );

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.LastOfMonth,
            executeAfter,
            MAX_VALID_LAST_OF_MONTH_EXPIRES_AFTER + 1,
            VALID_RECURRING_TOTAL_OCCURRENCES
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

    function test_CreatePayment_SuccessWhen_NoneHasOneTotalOccurrences() public {
        vm.startPrank(payer);

        scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();
    }

    function test_CreatePayment_RevertWhen_NoneHasMultipleTotalOccurrences() public {
        vm.startPrank(payer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolInvalidTotalOccurrences.selector,
                IScheduledProtocol.RecurrenceType.None,
                2
            )
        );

        scheduledProtocol.createPayment(
            recipient, VALID_AMOUNT, IScheduledProtocol.RecurrenceType.None, executeAfter, VALID_EXPIRES_AFTER, 2
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

    function test_CreatePayment_RevertWhen_RecurringHasOneTotalOccurrences() public {
        IScheduledProtocol.RecurrenceType[4] memory recurringTypes = _recurringTypes();

        vm.startPrank(payer);

        for (uint256 i; i < recurringTypes.length; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IScheduledProtocol.ScheduledProtocolInvalidTotalOccurrences.selector, recurringTypes[i], 1
                )
            );

            scheduledProtocol.createPayment(
                recipient, VALID_AMOUNT, recurringTypes[i], executeAfter, VALID_EXPIRES_AFTER, 1
            );
        }

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_RecurringHasMinimumValidTotalOccurrences() public {
        IScheduledProtocol.RecurrenceType[4] memory recurringTypes = _recurringTypes();

        vm.startPrank(payer);

        for (uint256 i; i < recurringTypes.length; ++i) {
            scheduledProtocol.createPayment(
                recipient,
                VALID_AMOUNT,
                recurringTypes[i],
                executeAfter,
                VALID_EXPIRES_AFTER,
                MIN_VALID_RECURRING_TOTAL_OCCURRENCES
            );
        }

        vm.stopPrank();
    }

    function test_CreatePayment_SuccessWhen_RecurringHasMaximumValidTotalOccurrences() public {
        IScheduledProtocol.RecurrenceType[4] memory recurringTypes = _recurringTypes();

        vm.startPrank(payer);

        for (uint256 i; i < recurringTypes.length; ++i) {
            uint256 paymentId = scheduledProtocol.createPayment(
                recipient,
                VALID_AMOUNT,
                recurringTypes[i],
                executeAfter,
                VALID_EXPIRES_AFTER,
                MAX_VALID_RECURRING_TOTAL_OCCURRENCES
            );

            IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);

            assertEq(payment.totalOccurrences, MAX_VALID_RECURRING_TOTAL_OCCURRENCES);
        }

        vm.stopPrank();
    }

    function _recurringTypes() private pure returns (IScheduledProtocol.RecurrenceType[4] memory recurringTypes) {
        recurringTypes = [
            IScheduledProtocol.RecurrenceType.Daily,
            IScheduledProtocol.RecurrenceType.Weekly,
            IScheduledProtocol.RecurrenceType.Monthly,
            IScheduledProtocol.RecurrenceType.LastOfMonth
        ];
    }
}
