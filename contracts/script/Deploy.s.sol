// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Script} from "forge-std/Script.sol";

import {ScheduledProtocol} from "../src/ScheduledProtocol.sol";

contract Deploy is Script {
    function run() external returns (ScheduledProtocol scheduledProtocol) {
        vm.startBroadcast();

        scheduledProtocol = new ScheduledProtocol();

        vm.stopBroadcast();
    }
}
