// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

contract OccurrenceDerivationTest is Test {
    address private payer;
    address private recipient;

    ScheduledProtocol private scheduledProtocol;

    function setUp() public {
        payer = makeAddr("payer");
        recipient = makeAddr("recipient");

        scheduledProtocol = new ScheduledProtocol();
    }

    function test_OccurrenceDerivation_RevertWhen_InvalidPaymentId() public {
        vm.startPrank(payer);

        vm.expectRevert(abi.encodeWithSelector(IScheduledProtocol.ScheduledProtocolInvalidPaymentId.selector, 0));

        scheduledProtocol.executePayment(0);

        vm.stopPrank();
    }
}
