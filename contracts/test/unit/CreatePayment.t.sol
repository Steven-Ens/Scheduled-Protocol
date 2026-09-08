// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract CreatePaymentTest is Test {
    address private payer;
    address private recipient;
    ScheduledProtocol private scheduledProtocol;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");
        scheduledProtocol = new ScheduledProtocol();
    }

    function test_CreatePayment() public {
        uint96 amount = 100e6;
        IScheduledProtocol.RecurrenceType recurrence = IScheduledProtocol.RecurrenceType.None;
        uint40 executeAfter = uint40(block.timestamp + 1 days);
        uint24 expiresAfter = uint24(1 hours);
        uint32 totalOccurrences = 1;

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient, amount, recurrence, executeAfter, expiresAfter, totalOccurrences
        );

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);

        vm.stopPrank();

        assertEq(payment.payer, payer);
        assertEq(payment.recipient, recipient);
        assertEq(payment.amount, amount);
        assertEq(uint8(payment.recurrence), uint8(IScheduledProtocol.RecurrenceType.None));
        assertEq(payment.executeAfter, executeAfter);
        assertEq(payment.expiresAfter, expiresAfter);
        assertEq(payment.totalOccurrences, totalOccurrences);
        assertEq(payment.lastExecutedOccurrencePlusOne, 0);
        assertFalse(payment.cancelled);
    }

    function test_CreatePayment_AssignsSequentialPaymentIds() public {
        vm.startPrank(payer);

        uint256 paymentIdOne = scheduledProtocol.createPayment(
            recipient,
            100e6,
            IScheduledProtocol.RecurrenceType.None,
            // `block.timestamp + 1 days` is a uint256 expression, so it must be explicitly narrowed to uint40.
            uint40(block.timestamp + 1 days),
            1 hours,
            1
        );

        uint256 paymentIdTwo = scheduledProtocol.createPayment(
            recipient, 100e6, IScheduledProtocol.RecurrenceType.None, uint40(block.timestamp + 1 days), 1 hours, 1
        );

        vm.stopPrank();

        assertEq(paymentIdOne, 0);
        assertEq(paymentIdTwo, 1);
    }

    function test_CreatePayment_EmitsPaymentCreated() public {
        uint96 amount = 100e6;
        IScheduledProtocol.RecurrenceType recurrence = IScheduledProtocol.RecurrenceType.None;
        uint40 executeAfter = uint40(block.timestamp + 1 days);
        uint24 expiresAfter = uint24(1 hours);
        uint32 totalOccurrences = 1;

        vm.startPrank(payer);

        // Check the three indexed event topics and all non-indexed event data.
        vm.expectEmit(true, true, true, true);

        emit IScheduledProtocol.PaymentCreated(
            0, payer, recipient, amount, recurrence, executeAfter, expiresAfter, totalOccurrences
        );

        scheduledProtocol.createPayment(recipient, amount, recurrence, executeAfter, expiresAfter, totalOccurrences);

        vm.stopPrank();
    }
}
