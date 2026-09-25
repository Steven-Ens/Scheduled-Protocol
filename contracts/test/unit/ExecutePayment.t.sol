// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/IERC6093.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract ExecutePaymentTest is Test {
    using SafeERC20 for MockUSDC;

    address private payer;
    address private recipient;
    address private executor;
    address private tokenSink;
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

    uint256 private constant TOTAL_REQUIRED_AMOUNT = VALID_AMOUNT + EXECUTOR_FEE + PROTOCOL_FEE;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");
        executor = makeAddr("executor");
        tokenSink = makeAddr("tokenSink");
        // Safe because the test timestamp plus one day is well below `type(uint40).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + VALID_EXECUTE_AFTER_DELAY);

        mockUSDC = new MockUSDC();
        scheduledProtocol = new ScheduledProtocol(mockUSDC);

        vm.startPrank(payer);
        mockUSDC.mint(payer, TOTAL_REQUIRED_AMOUNT);
        mockUSDC.approve(address(scheduledProtocol), TOTAL_REQUIRED_AMOUNT);
        vm.stopPrank();
    }

    // Settlement

    function test_ExecutePayment_SuccessWhen_TransfersPrincipalAndDebitsTotalAmount() public {
        vm.startPrank(payer);

        uint256 paymentId = _createOneTimePayment();

        uint256 payerBalanceBefore = mockUSDC.balanceOf(payer);
        uint256 recipientBalanceBefore = mockUSDC.balanceOf(recipient);

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(payer), payerBalanceBefore - TOTAL_REQUIRED_AMOUNT);
        assertEq(mockUSDC.balanceOf(recipient), recipientBalanceBefore + VALID_AMOUNT);
    }

    function test_ExecutePayment_SuccessWhen_TransfersExecutorFee() public {
        vm.startPrank(payer);

        uint256 paymentId = _createOneTimePayment();

        uint256 executorBalanceBefore = mockUSDC.balanceOf(executor);

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(executor), executorBalanceBefore + EXECUTOR_FEE);
    }

    function test_ExecutePayment_SuccessWhen_TransfersProtocolFee() public {
        vm.startPrank(payer);

        uint256 paymentId = _createOneTimePayment();

        uint256 scheduledProtocolBalanceBefore = mockUSDC.balanceOf(address(scheduledProtocol));

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(scheduledProtocol)), scheduledProtocolBalanceBefore + PROTOCOL_FEE);
    }

    function test_ExecutePayment_SuccessWhen_AccruesProtocolFee() public {
        vm.startPrank(payer);

        uint256 paymentId = _createOneTimePayment();

        uint256 accumulatedProtocolFeesBefore = scheduledProtocol.getAccumulatedProtocolFees();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();

        assertEq(scheduledProtocol.getAccumulatedProtocolFees(), accumulatedProtocolFeesBefore + PROTOCOL_FEE);
    }

    function test_ExecutePayment_SuccessWhen_EmitsPaymentExecuted() public {
        vm.startPrank(payer);

        uint256 paymentId = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        // Check the first, second and third indexed topics and the emitting contract.
        vm.expectEmit(true, true, true, false, address(scheduledProtocol));

        emit IScheduledProtocol.PaymentExecuted(paymentId, 0, executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    // Execution progress

    function test_ExecutePayment_SuccessWhen_RecordsExecutedOccurrence() public {
        vm.startPrank(payer);

        uint256 paymentId = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);

        vm.stopPrank();

        assertEq(payment.lastExecutedOccurrencePlusOne, 1);
    }

    function test_ExecutePayment_RevertWhen_OccurrenceAlreadyExecuted() public {
        vm.startPrank(payer);

        // Enough funds and approval to call executePayment twice
        mockUSDC.mint(payer, TOTAL_REQUIRED_AMOUNT);
        mockUSDC.approve(address(scheduledProtocol), TOTAL_REQUIRED_AMOUNT * 2);

        uint256 paymentId = _createRecurringPayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.expectRevert(
            abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolOccurrenceAlreadyExecuted.selector, 0)
        );

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    function test_ExecutePayment_SuccessWhen_PreviousOccurrenceWasMissed() public {
        vm.startPrank(payer);

        uint256 paymentId = _createRecurringPayment();

        vm.warp(executeAfter + 1 days);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);

        vm.stopPrank();

        assertEq(payment.lastExecutedOccurrencePlusOne, 2);
    }

    // Payment lifecycle

    function test_ExecutePayment_SuccessWhen_IntermediateOccurrenceRemainsActive() public {
        vm.startPrank(payer);

        uint256 paymentId = _createRecurringPayment();

        vm.warp(executeAfter + 1 days);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Active));
    }

    function test_ExecutePayment_SuccessWhen_FinalOccurrenceCompletesPayment() public {
        vm.startPrank(payer);

        uint256 paymentId = _createRecurringPayment();

        vm.warp(executeAfter + ((VALID_RECURRING_TOTAL_OCCURRENCES - 1) * 1 days));

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        IScheduledProtocol.PaymentStatus status = scheduledProtocol.getPaymentStatus(paymentId);

        vm.stopPrank();

        assertEq(uint8(status), uint8(IScheduledProtocol.PaymentStatus.Completed));
    }

    // Settlement failure and recovery

    function test_ExecutePayment_RevertWhen_InsufficientBalance() public {
        vm.startPrank(payer);

        mockUSDC.safeTransfer(tokenSink, mockUSDC.balanceOf(payer));

        uint256 paymentId = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, payer, 0, VALID_AMOUNT));

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    function test_ExecutePayment_RevertWhen_InsufficientAllowance() public {
        vm.startPrank(payer);

        mockUSDC.approve(address(scheduledProtocol), 0);

        uint256 paymentId = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(scheduledProtocol), 0, VALID_AMOUNT
            )
        );

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();
    }

    function test_ExecutePayment_RevertWhen_FailedTransferDoesNotRecordOccurrence() public {
        vm.startPrank(payer);

        mockUSDC.safeTransfer(tokenSink, mockUSDC.balanceOf(payer));

        uint256 paymentId = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, payer, 0, VALID_AMOUNT));

        scheduledProtocol.executePayment(paymentId);

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);

        vm.stopPrank();

        assertEq(payment.lastExecutedOccurrencePlusOne, 0);
    }

    function test_ExecutePayment_RevertWhen_FailedTransferDoesNotAccrueProtocolFee() public {
        vm.startPrank(payer);

        mockUSDC.safeTransfer(tokenSink, mockUSDC.balanceOf(payer));

        uint256 paymentId = _createOneTimePayment();

        uint256 accumulatedProtocolFeesBefore = scheduledProtocol.getAccumulatedProtocolFees();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, payer, 0, VALID_AMOUNT));

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();

        assertEq(scheduledProtocol.getAccumulatedProtocolFees(), accumulatedProtocolFeesBefore);
    }

    function test_ExecutePayment_RevertWhen_FailedSettlementRollsBackTransfers() public {
        vm.startPrank(payer);

        mockUSDC.safeTransfer(tokenSink, mockUSDC.balanceOf(payer) - (VALID_AMOUNT + EXECUTOR_FEE));

        uint256 paymentId = _createOneTimePayment();

        uint256 payerBalanceBefore = mockUSDC.balanceOf(payer);
        uint256 recipientBalanceBefore = mockUSDC.balanceOf(recipient);
        uint256 executorBalanceBefore = mockUSDC.balanceOf(executor);
        uint256 scheduledProtocolBalanceBefore = mockUSDC.balanceOf(address(scheduledProtocol));

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, payer, 0, PROTOCOL_FEE));

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(payer), payerBalanceBefore);
        assertEq(mockUSDC.balanceOf(recipient), recipientBalanceBefore);
        assertEq(mockUSDC.balanceOf(executor), executorBalanceBefore);
        assertEq(mockUSDC.balanceOf(address(scheduledProtocol)), scheduledProtocolBalanceBefore);
    }

    function test_ExecutePayment_SuccessWhen_FundingRestoredAfterFailedExecution() public {
        vm.startPrank(payer);

        mockUSDC.safeTransfer(tokenSink, mockUSDC.balanceOf(payer));

        uint256 paymentId = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, payer, 0, VALID_AMOUNT));

        scheduledProtocol.executePayment(paymentId);

        IScheduledProtocol.Payment memory payment = scheduledProtocol.getPayment(paymentId);

        vm.stopPrank();

        assertEq(payment.lastExecutedOccurrencePlusOne, 0);

        vm.startPrank(payer);

        mockUSDC.mint(payer, TOTAL_REQUIRED_AMOUNT);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        payment = scheduledProtocol.getPayment(paymentId);

        vm.stopPrank();

        assertEq(payment.lastExecutedOccurrencePlusOne, 1);
    }

    // Helpers

    function _createOneTimePayment() private returns (uint256 paymentId) {
        paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );
    }

    function _createRecurringPayment() private returns (uint256 paymentId) {
        paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.Daily,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_RECURRING_TOTAL_OCCURRENCES
        );
    }
}
