// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract PaymentExecutionHandler {
    ScheduledProtocol private scheduledProtocol;
    uint256 private paymentId;

    // Tracks how many times the one-time payment successfully executes.
    uint256 public successfulExecutions;

    constructor(ScheduledProtocol scheduledProtocol_, uint256 paymentId_) {
        scheduledProtocol = scheduledProtocol_;
        paymentId = paymentId_;
    }

    function executePayment() external {
        try scheduledProtocol.executePayment(paymentId) {
            successfulExecutions++;
        } catch {}
    }
}

contract PaymentExecutionInvariantTest is StdInvariant, Test {
    address private payer;
    address private recipient;
    uint40 private executeAfter;

    MockUSDC private mockUSDC;
    ScheduledProtocol private scheduledProtocol;
    PaymentExecutionHandler private handler;

    uint96 private constant VALID_AMOUNT = 100e6;
    uint256 private constant VALID_EXECUTE_AFTER_DELAY = 1 days;
    uint24 private constant VALID_EXPIRES_AFTER = 1 hours;
    uint32 private constant VALID_ONE_TIME_TOTAL_OCCURRENCES = 1;

    // 0.80 USDC
    uint256 private constant EXECUTOR_FEE = 800_000;
    // 0.20 USDC
    uint256 private constant PROTOCOL_FEE = 200_000;

    uint256 private constant TOTAL_REQUIRED_AMOUNT = VALID_AMOUNT + EXECUTOR_FEE + PROTOCOL_FEE;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");

        // Safe because the test timestamp plus one day is well below type(uint40).max.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + VALID_EXECUTE_AFTER_DELAY);

        vm.startPrank(payer);

        mockUSDC = new MockUSDC();
        scheduledProtocol = new ScheduledProtocol(mockUSDC);

        // Fund and approve two executions so insufficient funds cannot hide a replay bug.
        mockUSDC.mint(payer, TOTAL_REQUIRED_AMOUNT * 2);
        mockUSDC.approve(address(scheduledProtocol), TOTAL_REQUIRED_AMOUNT * 2);

        uint256 paymentId = scheduledProtocol.createPayment(
            recipient,
            VALID_AMOUNT,
            IScheduledProtocol.RecurrenceType.None,
            executeAfter,
            VALID_EXPIRES_AFTER,
            VALID_ONE_TIME_TOTAL_OCCURRENCES
        );

        vm.stopPrank();

        // Place the payment inside its valid execution window.
        vm.warp(executeAfter);

        handler = new PaymentExecutionHandler(scheduledProtocol, paymentId);

        // Restrict the invariant fuzzer to the handler.
        targetContract(address(handler));
    }

    function invariant_OneTimePaymentExecutesAtMostOnce() public view {
        // Less than or equal to 1 because the invariant is also checked before any successful execution, when the count is 0.
        assertLe(handler.successfulExecutions(), 1);
    }
}
