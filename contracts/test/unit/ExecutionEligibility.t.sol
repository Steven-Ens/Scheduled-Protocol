// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract ExecutionEligibilityTest is Test {
    address private payer;
    address private recipient;
    address private executor;
    uint40 private executeAfter;

    MockUSDC private mockUSDC;
    ScheduledProtocol private scheduledProtocol;

    uint96 private constant VALID_AMOUNT = 100e6;
    // Delay added to `block.timestamp` to produce a valid future `executeAfter`.
    uint256 private constant VALID_EXECUTE_AFTER_DELAY = 1 days;
    uint24 private constant VALID_EXPIRES_AFTER = 1 hours;
    uint32 private constant VALID_ONE_TIME_TOTAL_OCCURRENCES = 1;
    uint32 private constant VALID_RECURRING_TOTAL_OCCURRENCES = 10;

    // 0.80 USDC
    uint256 private constant EXECUTOR_FEE = 800_000;
    // 0.20 USDC
    uint256 private constant PROTOCOL_FEE = 200_000;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");
        executor = makeAddr("executor");
        // Safe because the test timestamp plus one day is well below `type(uint40).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + VALID_EXECUTE_AFTER_DELAY);

        mockUSDC = new MockUSDC();
        scheduledProtocol = new ScheduledProtocol(mockUSDC);

        vm.startPrank(payer);
        mockUSDC.mint(payer, VALID_AMOUNT + EXECUTOR_FEE + PROTOCOL_FEE);
        mockUSDC.approve(address(scheduledProtocol), VALID_AMOUNT + EXECUTOR_FEE + PROTOCOL_FEE);
        vm.stopPrank();
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

        vm.stopPrank();

        vm.startPrank(executor);

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

        vm.stopPrank();

        vm.startPrank(executor);

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

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    function test_ExecutePayment_SuccessWhen_AtOccurrenceStart() public {
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

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    function test_ExecutePayment_SuccessWhen_BeforeOccurrenceEnd() public {
        vm.startPrank(payer);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );

        vm.warp(executeAfter + VALID_EXPIRES_AFTER - 1);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    function test_ExecutePayment_RevertWhen_AtOccurrenceEnd() public {
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

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
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

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
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

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }
}
