// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract CancelPaymentTest is Test {
    address private payer;
    address private recipient;
    uint40 private executeAfter;

    ScheduledProtocol private scheduledProtocol;

    uint96 private constant VALID_AMOUNT = 100e6;
    // Delay added to `block.timestamp` to produce a valid future `executeAfter`.
    uint256 private constant VALID_EXECUTE_AFTER_DELAY = 1 days;
    uint24 private constant VALID_EXPIRES_AFTER = 1 hours;
    uint32 private constant VALID_ONE_TIME_TOTAL_OCCURRENCES = 1;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");
        // Safe because the test timestamp plus one day is well below `type(uint40).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + VALID_EXECUTE_AFTER_DELAY);

        scheduledProtocol = new ScheduledProtocol();
    }

    function test_CancelPayment_RevertWhen_InvalidPaymentId() public {
        vm.startPrank(payer);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidPaymentId.selector, 0));

        scheduledProtocol.cancelPayment(0);

        vm.stopPrank();
    }

    function test_CancelPayment_RevertWhen_UnauthorizedCaller() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();

        vm.startPrank(recipient);

        vm.expectRevert(
            abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolUnauthorizedCaller.selector, recipient)
        );

        scheduledProtocol.cancelPayment(paymentId);

        vm.stopPrank();
    }

    function test_CancelPayment_SuccessWhen_PaymentIsActive() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        scheduledProtocol.cancelPayment(paymentId);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Cancelled));
    }

    function test_CancelPayment_SuccessWhen_EmitsPaymentCancelled() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        // Check the first indexed topic and the emitting contract.
        vm.expectEmit(true, false, false, false, address(scheduledProtocol));

        emit IScheduledProtocol.PaymentCancelled(paymentId);

        scheduledProtocol.cancelPayment(paymentId);

        vm.stopPrank();
    }

    function test_CancelPayment_RevertWhen_PaymentIsCompleted() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter + VALID_EXPIRES_AFTER);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolInvalidPaymentStatus.selector,
                IScheduledProtocol.PaymentStatus.Completed
            )
        );

        scheduledProtocol.cancelPayment(paymentId);

        vm.stopPrank();
    }

    function test_CancelPayment_RevertWhen_PaymentIsAlreadyCancelled() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        scheduledProtocol.cancelPayment(paymentId);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolInvalidPaymentStatus.selector,
                IScheduledProtocol.PaymentStatus.Cancelled
            )
        );

        scheduledProtocol.cancelPayment(paymentId);

        vm.stopPrank();
    }
}
