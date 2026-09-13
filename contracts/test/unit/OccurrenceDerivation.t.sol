// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

import {Test} from "forge-std/Test.sol";

import {IScheduledProtocol} from "../../src/interfaces/IScheduledProtocol.sol";
import {ScheduledProtocol} from "../../src/ScheduledProtocol.sol";

// external wrapper for _deriveOccurrence.
contract ScheduledProtocolHarness is ScheduledProtocol {
    function deriveOccurrence(RecurrenceType recurrence, uint40 executeAfter, uint256 timestamp)
        external
        pure
        returns (uint256 occurrenceIndex, uint256 occurrenceStart)
    {
        return _deriveOccurrence(recurrence, executeAfter, timestamp);
    }
}

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

    function test_OccurrenceDerivation_SuccessWhen_NoneDerivesOccurrenceZero() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint40 executeAfter = uint40(block.timestamp + 1 days);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.None, executeAfter, block.timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, executeAfter);
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsWithinFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint40 executeAfter = uint40(block.timestamp + 1 days);
        // Within first occurrence
        uint256 timestamp = uint256(executeAfter) + 12 hours;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 0);
        assertEq(occurrenceStart, uint256(executeAfter));
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsAtFirstOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint40 executeAfter = uint40(block.timestamp + 1 days);
        uint256 timestamp = uint256(executeAfter + 1 days);

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 1);
        assertEq(occurrenceStart, uint256(executeAfter) + 1 days);
    }

    function test_OccurrenceDerivation_SuccessWhen_DailyIsWithinFutureOccurrence() public {
        ScheduledProtocolHarness harness = new ScheduledProtocolHarness();

        uint40 executeAfter = uint40(block.timestamp + 1 days);
        // Within first occurrence
        uint256 timestamp = uint256(executeAfter) + 2 days + 12 hours;

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            harness.deriveOccurrence(IScheduledProtocol.RecurrenceType.Daily, executeAfter, timestamp);

        assertEq(occurrenceIndex, 2);
        assertEq(occurrenceStart, uint256(executeAfter) + 2 days);
    }
}
