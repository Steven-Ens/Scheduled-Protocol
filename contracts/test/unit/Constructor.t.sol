// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract ConstructorTest is Test {
    address private owner;

    function setUp() public {
        owner = makeAddr("owner");
    }

    function test_Constructor_SuccessWhen_SetsInitialOwner() public {
        MockUSDC mockUSDC = new MockUSDC();

        vm.startPrank(owner);

        ScheduledProtocol scheduledProtocol = new ScheduledProtocol(mockUSDC);

        vm.stopPrank();

        assertEq(scheduledProtocol.owner(), owner);
    }

    function test_Constructor_RevertWhen_USDCIsZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidUSDCAddress.selector)
        );

        new ScheduledProtocol(IERC20(address(0)));

        vm.stopPrank();
    }
}
