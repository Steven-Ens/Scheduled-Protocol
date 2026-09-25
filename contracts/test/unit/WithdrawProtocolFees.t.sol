// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract WithdrawProtocolFeesTest is Test {
    using SafeERC20 for MockUSDC;

    address private payer;
    address private recipient;
    address private executor;
    address private owner;
    address private newOwner;
    address private other;
    uint40 private executeAfter;

    MockUSDC private mockUSDC;
    ScheduledProtocol private scheduledProtocol;

    uint96 private constant VALID_AMOUNT = 100e6;
    // Delay added to `block.timestamp` to produce a valid future `executeAfter`.
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
        executor = makeAddr("executor");
        owner = makeAddr("owner");
        newOwner = makeAddr("newOwner");
        other = makeAddr("other");
        // Safe because the test timestamp plus one day is well below `type(uint40).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        executeAfter = uint40(block.timestamp + VALID_EXECUTE_AFTER_DELAY);

        vm.startPrank(owner);
        mockUSDC = new MockUSDC();
        scheduledProtocol = new ScheduledProtocol(mockUSDC);
        vm.stopPrank();

        vm.startPrank(payer);
        mockUSDC.mint(payer, TOTAL_REQUIRED_AMOUNT);
        mockUSDC.approve(address(scheduledProtocol), TOTAL_REQUIRED_AMOUNT);
        vm.stopPrank();
    }

    // Constructor

    function test_Constructor_SuccessWhen_SetsInitialOwner() public view {
        assertEq(scheduledProtocol.owner(), owner);
    }

    // Protocol fee withdrawal

    function test_WithdrawProtocolFees_RevertWhen_CallerIsNotOwner() public {
        vm.startPrank(other);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));

        scheduledProtocol.withdrawProtocolFees();

        vm.stopPrank();
    }

    function test_WithdrawProtocolFees_RevertWhen_NoProtocolFeesAccumulated() public {
        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolNoProtocolFeesAccumulated.selector));

        scheduledProtocol.withdrawProtocolFees();

        vm.stopPrank();
    }

    function test_WithdrawProtocolFees_SuccessWhen_TransfersAccumulatedFeesAndResetsAccounting() public {
        uint256 accumulatedProtocolFeesBefore = scheduledProtocol.getAccumulatedProtocolFees();
        uint256 scheduledProtocolBalanceBefore = mockUSDC.balanceOf(address(scheduledProtocol));
        uint256 ownerBalanceBefore = mockUSDC.balanceOf(owner);

        vm.startPrank(payer);

        uint256 paymentId = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();

        assertEq(scheduledProtocol.getAccumulatedProtocolFees(), accumulatedProtocolFeesBefore + PROTOCOL_FEE);
        assertEq(mockUSDC.balanceOf(address(scheduledProtocol)), scheduledProtocolBalanceBefore + PROTOCOL_FEE);
        assertEq(mockUSDC.balanceOf(owner), ownerBalanceBefore);

        vm.startPrank(owner);

        scheduledProtocol.withdrawProtocolFees();

        vm.stopPrank();

        assertEq(scheduledProtocol.getAccumulatedProtocolFees(), accumulatedProtocolFeesBefore);
        assertEq(mockUSDC.balanceOf(address(scheduledProtocol)), scheduledProtocolBalanceBefore);
        assertEq(mockUSDC.balanceOf(owner), ownerBalanceBefore + PROTOCOL_FEE);
    }

    function test_WithdrawProtocolFees_SuccessWhen_EmitsProtocolFeesWithdrawn() public {
        vm.startPrank(payer);

        uint256 paymentId = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();

        vm.startPrank(owner);

        // Check the first indexed topic, event data, and the emitting contract.
        vm.expectEmit(true, false, false, true, address(scheduledProtocol));

        emit IScheduledProtocol.ProtocolFeesWithdrawn(owner, PROTOCOL_FEE);

        scheduledProtocol.withdrawProtocolFees();

        vm.stopPrank();
    }

    function test_WithdrawProtocolFees_SuccessWhen_MultipleExecutionsAccumulateFees() public {
        uint256 accumulatedProtocolFeesBefore = scheduledProtocol.getAccumulatedProtocolFees();
        uint256 scheduledProtocolBalanceBefore = mockUSDC.balanceOf(address(scheduledProtocol));

        vm.startPrank(payer);

        // Enough funds and approval to call executePayment twice.
        mockUSDC.mint(payer, TOTAL_REQUIRED_AMOUNT);
        mockUSDC.approve(address(scheduledProtocol), TOTAL_REQUIRED_AMOUNT * 2);

        uint256 paymentIdOne = _createOneTimePayment();

        uint256 paymentIdTwo = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentIdOne);

        assertEq(scheduledProtocol.getAccumulatedProtocolFees(), accumulatedProtocolFeesBefore + PROTOCOL_FEE);
        assertEq(mockUSDC.balanceOf(address(scheduledProtocol)), scheduledProtocolBalanceBefore + PROTOCOL_FEE);

        scheduledProtocol.executePayment(paymentIdTwo);

        vm.stopPrank();

        assertEq(scheduledProtocol.getAccumulatedProtocolFees(), accumulatedProtocolFeesBefore + PROTOCOL_FEE * 2);
        assertEq(mockUSDC.balanceOf(address(scheduledProtocol)), scheduledProtocolBalanceBefore + PROTOCOL_FEE * 2);
    }

    function test_WithdrawProtocolFees_SuccessWhen_LeavesUnaccountedUSDCInContract() public {
        uint256 accumulatedProtocolFeesBefore = scheduledProtocol.getAccumulatedProtocolFees();
        uint256 scheduledProtocolBalanceBefore = mockUSDC.balanceOf(address(scheduledProtocol));
        uint256 ownerBalanceBefore = mockUSDC.balanceOf(owner);

        uint256 unaccountedUSDC = 1_000_000;

        vm.startPrank(payer);

        uint256 paymentId = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(other);

        mockUSDC.mint(other, unaccountedUSDC);

        mockUSDC.safeTransfer(address(scheduledProtocol), unaccountedUSDC);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();

        assertEq(scheduledProtocol.getAccumulatedProtocolFees(), accumulatedProtocolFeesBefore + PROTOCOL_FEE);
        assertEq(
            mockUSDC.balanceOf(address(scheduledProtocol)),
            scheduledProtocolBalanceBefore + PROTOCOL_FEE + unaccountedUSDC
        );
        assertEq(mockUSDC.balanceOf(owner), ownerBalanceBefore);

        vm.startPrank(owner);

        scheduledProtocol.withdrawProtocolFees();

        vm.stopPrank();

        assertEq(scheduledProtocol.getAccumulatedProtocolFees(), accumulatedProtocolFeesBefore);
        assertEq(mockUSDC.balanceOf(address(scheduledProtocol)), scheduledProtocolBalanceBefore + unaccountedUSDC);
        assertEq(mockUSDC.balanceOf(owner), ownerBalanceBefore + PROTOCOL_FEE);
    }

    // Ownership transfer

    function test_TransferOwnership_SuccessWhen_PendingOwnerAcceptsAndCanWithdrawProtocolFees() public {
        assertEq(scheduledProtocol.owner(), owner);
        assertEq(scheduledProtocol.pendingOwner(), address(0));

        uint256 oldOwnerBalanceBefore = mockUSDC.balanceOf(owner);
        uint256 newOwnerBalanceBefore = mockUSDC.balanceOf(newOwner);

        vm.startPrank(payer);

        uint256 paymentId = _createOneTimePayment();

        vm.warp(executeAfter);

        vm.stopPrank();

        vm.startPrank(executor);

        scheduledProtocol.executePayment(paymentId);

        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(owner), oldOwnerBalanceBefore);
        assertEq(mockUSDC.balanceOf(newOwner), newOwnerBalanceBefore);

        vm.startPrank(owner);

        scheduledProtocol.transferOwnership(newOwner);

        vm.stopPrank();

        assertEq(scheduledProtocol.owner(), owner);
        assertEq(scheduledProtocol.pendingOwner(), newOwner);

        vm.startPrank(newOwner);

        scheduledProtocol.acceptOwnership();

        assertEq(scheduledProtocol.owner(), newOwner);
        assertEq(scheduledProtocol.pendingOwner(), address(0));

        scheduledProtocol.withdrawProtocolFees();

        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(owner), oldOwnerBalanceBefore);
        assertEq(mockUSDC.balanceOf(newOwner), newOwnerBalanceBefore + PROTOCOL_FEE);
    }

    // Ownership renunciation

    function test_RenounceOwnership_RevertWhen_Called() public {
        vm.startPrank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolOwnershipRenunciationDisabled.selector)
        );

        scheduledProtocol.renounceOwnership();

        vm.stopPrank();

        assertEq(scheduledProtocol.owner(), owner);
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
}
