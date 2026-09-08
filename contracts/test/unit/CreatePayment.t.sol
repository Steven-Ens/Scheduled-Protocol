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
    uint32 private constant ONE_TIME_TOTAL_OCCURRENCES = 1;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");
        // Safe because the test timestamp plus one day is well below `type(uint40).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + VALID_EXECUTE_AFTER_DELAY);

        scheduledProtocol = new ScheduledProtocol();
    }

    function test_CreatePayment() public {
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
            // `block.timestamp + 1 days` is a uint256 expression, so it must be explicitly narrowed to uint40.
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

        // Check the three indexed event topics and all non-indexed event data.
        vm.expectEmit(true, true, true, true);

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

    function test_CreatePayment_RevertWhen_ExecuteAfterIsNotInFuture() public {
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
}
