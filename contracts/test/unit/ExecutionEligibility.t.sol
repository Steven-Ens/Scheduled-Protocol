// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract ExecutionEligibilityTest is Test {
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

    // Execution validation

    function test_ExecutePayment_RevertWhen_InvalidPaymentId() public {
        vm.startPrank(payer);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidPaymentId.selector, 0));

        scheduledProtocol.executePayment(0);

        vm.stopPrank();
    }

    function test_ExecutePayment_RevertWhen_BeforeExecuteAfter() public {
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

        vm.expectRevert(
            abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolExecutionNotStarted.selector, executeAfter)
        );

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    function test_ExecutePayment_RevertWhen_PaymentIsCancelled() public {
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

        vm.warp(executeAfter);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScheduledProtocol.ScheduledProtocolInvalidPaymentStatus.selector,
                IScheduledProtocol.PaymentStatus.Cancelled
            )
        );

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    function test_ExecutePayment_RevertWhen_PaymentIsCompleted() public {
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

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    function test_ExecutePayment_SuccessWhen_AtOccurrenceStart() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient, VALID_AMOUNT, IScheduledProtocol.RecurrenceType.Daily, executeAfter, VALID_EXPIRES_AFTER, 3
        );

        vm.warp(executeAfter);

        scheduledProtocol.executePayment(paymentId);
    }

    function test_ExecutePayment_SuccessWhen_AtOccurrenceEnd() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient, VALID_AMOUNT, IScheduledProtocol.RecurrenceType.Daily, executeAfter, VALID_EXPIRES_AFTER, 3
        );

        vm.warp(executeAfter + VALID_EXPIRES_AFTER - 1);

        scheduledProtocol.executePayment(paymentId);
    }

    function test_ExecutePayment_RevertWhen_PastOccurrenceEnd() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter + VALID_EXPIRES_AFTER);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolExecutionWindowExpired.selector, 0));

        scheduledProtocol.executePayment(paymentId);
    }

    function test_ExecutePayment_SuccessWhen_AtNextOccurrenceStart() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter + 1 days);

        scheduledProtocol.executePayment(paymentId);
    }

    function test_ExecutePayment_RevertWhen_BeforeLastOfMonthOccurrenceStart() public {
        // April 30, 2026 @ 10:00 UTC
        executeAfter = uint40(BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 4, 30, 10, 0, 0));

        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.LastOfMonth,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        // May 30, 2026 @ 10:00 UTC
        uint256 invalidExecutionWindow = BokkyPooBahsDateTimeLibrary.timestampFromDateTime(2026, 5, 30, 10, 0, 0);
        vm.warp(invalidExecutionWindow);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolExecutionWindowExpired.selector, 0));

        scheduledProtocol.executePayment(paymentId);
    }
}
