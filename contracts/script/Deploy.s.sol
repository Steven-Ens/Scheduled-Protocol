// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Script} from "forge-std/Script.sol";

import {MockUSDC} from "../test/mocks/MockUSDC.sol";

import {ScheduledProtocol} from "../src/ScheduledProtocol.sol";

contract Deploy is Script {
    function run() external returns (MockUSDC mockUSDC, ScheduledProtocol scheduledProtocol) {
        vm.startBroadcast();

        mockUSDC = new MockUSDC();
        scheduledProtocol = new ScheduledProtocol(mockUSDC);

        vm.stopBroadcast();
    }
}
