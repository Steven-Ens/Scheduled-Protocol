// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.35;

import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

import {IScheduledProtocol} from "./interfaces/IScheduledProtocol.sol";

/**
 * @dev Core implementation of Scheduled Protocol.
 */
contract ScheduledProtocol is IScheduledProtocol {
    uint256 private _nextPaymentId;
    uint256 private _accumulatedProtocolFees;

    mapping(uint256 paymentId => Payment payment) private _payments;

    /**
     * @dev Reverts is `paymentId` does not exist.
     */
    modifier isValidPaymentId(uint256 paymentId) {
        if (paymentId >= _nextPaymentId) {
            revert ScheduledProtocolInvalidPaymentId(paymentId);
        }
        _;
    }

    /**
     * @inheritdoc IScheduledProtocol
     */
    function createPayment(
        address recipient,
        uint96 amount,
        RecurrenceType recurrence,
        uint40 executeAfter,
        uint24 expiresAfter,
        uint32 totalOccurrences
    ) external override returns (uint256 paymentId) {
        if (recipient == address(0)) {
            revert ScheduledProtocolInvalidRecipient(recipient);
        }

        if (amount == 0) {
            revert ScheduledProtocolInvalidAmount(amount);
        }

        // `block.timestamp` is intentionally used as the protocol's authoritative scheduling clock.
        // forge-lint: disable-next-line(block-timestamp)
        if (executeAfter <= block.timestamp) {
            revert ScheduledProtocolInvalidExecuteAfter(executeAfter);
        }

        if (recurrence == RecurrenceType.LastOfMonth) {
            uint256 dayOfMonth = BokkyPooBahsDateTimeLibrary.getDay(executeAfter);
            uint256 lastDayOfMonth = BokkyPooBahsDateTimeLibrary.getDaysInMonth(executeAfter);

            if (dayOfMonth != lastDayOfMonth) {
                revert ScheduledProtocolInvalidLastOfMonthExecuteAfter(executeAfter);
            }
        }

        if (expiresAfter == 0) {
            revert ScheduledProtocolInvalidExpiresAfter(expiresAfter);
        }

        // Solidity's ABI decoder guarantees `recurrence` is a valid enum value, so any value other than `None` is a
        // recurring type.
        if (recurrence == RecurrenceType.None) {
            if (totalOccurrences != 1) {
                revert ScheduledProtocolInvalidTotalOccurrences(recurrence, totalOccurrences);
            }
        } else {
            if (totalOccurrences <= 1) {
                revert ScheduledProtocolInvalidTotalOccurrences(recurrence, totalOccurrences);
            }
        }

        uint24 maxExpiresAfter;
        if (recurrence == RecurrenceType.None) {
            maxExpiresAfter = 28 days;
        } else if (recurrence == RecurrenceType.Daily) {
            maxExpiresAfter = 1 days;
        } else if (recurrence == RecurrenceType.Weekly) {
            maxExpiresAfter = 1 weeks;
        } else if (recurrence == RecurrenceType.Monthly || recurrence == RecurrenceType.LastOfMonth) {
            maxExpiresAfter = 28 days;
        }

        // Enforce the maximum execution window for the selected recurrence type.
        if (expiresAfter > maxExpiresAfter) {
            revert ScheduledProtocolExecutionWindowTooLong(recurrence, expiresAfter, maxExpiresAfter);
        }

        paymentId = _nextPaymentId;
        Payment storage payment = _payments[paymentId];

        payment.payer = msg.sender;
        payment.recipient = recipient;
        payment.amount = amount;
        payment.recurrence = recurrence;
        payment.executeAfter = executeAfter;
        payment.expiresAfter = expiresAfter;
        payment.totalOccurrences = totalOccurrences;

        _nextPaymentId++;

        emit PaymentCreated(
            paymentId, msg.sender, recipient, amount, recurrence, executeAfter, expiresAfter, totalOccurrences
        );
    }

    /**
     * @inheritdoc IScheduledProtocol
     */
    function executePayment(uint256 paymentId) external override isValidPaymentId(paymentId) {
        Payment storage payment = _payments[paymentId];

        // `block.timestamp` is intentionally used as the protocol's authoritative scheduling clock.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp < payment.executeAfter) {
            revert ScheduledProtocolExecutionNotStarted(payment.executeAfter);
        }
    }

    /**
     * @inheritdoc IScheduledProtocol
     */
    function cancelPayment(uint256 paymentId) external override {}

    /**
     * @inheritdoc IScheduledProtocol
     */
    function getPayment(uint256 paymentId)
        external
        view
        override
        isValidPaymentId(paymentId)
        returns (Payment memory payment)
    {
        return _payments[paymentId];
    }

    /**
     * @inheritdoc IScheduledProtocol
     */
    function getPaymentStatus(uint256 paymentId)
        external
        view
        override
        isValidPaymentId(paymentId)
        returns (PaymentStatus status)
    {
        // `block.timestamp` is intentionally used as the protocol's authoritative scheduling clock.
        // forge-lint: disable-next-line(block-timestamp)
        uint256 timestamp = block.timestamp;
        Payment storage payment = _payments[paymentId];

        if (payment.recurrence == RecurrenceType.None && timestamp >= payment.executeAfter + payment.expiresAfter) {
            return PaymentStatus.Completed;
        } else if (
            payment.recurrence == RecurrenceType.Daily
                && timestamp >= payment.executeAfter + ((payment.totalOccurrences - 1) * 1 days) + payment.expiresAfter
        ) {
            return PaymentStatus.Completed;
        } else if (
            payment.recurrence == RecurrenceType.Weekly
                && timestamp >= payment.executeAfter + ((payment.totalOccurrences - 1) * 1 weeks) + payment.expiresAfter
        ) {
            return PaymentStatus.Completed;
        } else if (
            payment.recurrence == RecurrenceType.Monthly
                && timestamp
                    >= BokkyPooBahsDateTimeLibrary.addMonths(payment.executeAfter, payment.totalOccurrences - 1)
                        + payment.expiresAfter
        ) {
            return PaymentStatus.Completed;
        } else if (
            payment.recurrence == RecurrenceType.LastOfMonth
                && timestamp
                    >= _lastOfMonthOccurrenceStart(
                            BokkyPooBahsDateTimeLibrary.addMonths(payment.executeAfter, payment.totalOccurrences - 1)
                        ) + payment.expiresAfter
        ) {
            return PaymentStatus.Completed;
        }
        return PaymentStatus.Active;
    }

    /**
     * @inheritdoc IScheduledProtocol
     */
    function withdrawProtocolFees() external override {}

    /**
     * @dev Derives the current `occurrenceIndex` and `occurrenceStart` for a payment schedule.
     */
    function _deriveOccurrence(RecurrenceType recurrence, uint40 executeAfter, uint256 timestamp)
        internal
        pure
        returns (uint256 occurrenceIndex, uint256 occurrenceStart)
    {
        if (recurrence == RecurrenceType.None) {
            return (0, uint256(executeAfter));
        } else if (recurrence == RecurrenceType.Daily) {
            occurrenceIndex = (timestamp - executeAfter) / 1 days;
            occurrenceStart = executeAfter + occurrenceIndex * 1 days;
        } else if (recurrence == RecurrenceType.Weekly) {
            occurrenceIndex = (timestamp - executeAfter) / 7 days;
            occurrenceStart = executeAfter + occurrenceIndex * 7 days;
        } else if (recurrence == RecurrenceType.Monthly) {
            occurrenceIndex = BokkyPooBahsDateTimeLibrary.diffMonths(executeAfter, timestamp);
            occurrenceStart = BokkyPooBahsDateTimeLibrary.addMonths(executeAfter, occurrenceIndex);
            if (occurrenceStart > timestamp) {
                occurrenceIndex--;
                occurrenceStart = BokkyPooBahsDateTimeLibrary.addMonths(executeAfter, occurrenceIndex);
            }
        } else if (recurrence == RecurrenceType.LastOfMonth) {
            occurrenceIndex = BokkyPooBahsDateTimeLibrary.diffMonths(executeAfter, timestamp);
            uint256 targetMonthTimestamp = BokkyPooBahsDateTimeLibrary.addMonths(executeAfter, occurrenceIndex);
            occurrenceStart = _lastOfMonthOccurrenceStart(targetMonthTimestamp);
            if (occurrenceStart > timestamp) {
                occurrenceIndex--;
                targetMonthTimestamp = BokkyPooBahsDateTimeLibrary.addMonths(executeAfter, occurrenceIndex);
                occurrenceStart = _lastOfMonthOccurrenceStart(targetMonthTimestamp);
            }
        }
    }

    /**
     * @dev Returns an `occurrenceStart` for the target month's last day, preserving the original anchor's time of day.
     */
    function _lastOfMonthOccurrenceStart(uint256 targetMonthTimestamp) internal pure returns (uint256 occurrenceStart) {
        (uint256 year, uint256 month,, uint256 hour, uint256 minute, uint256 second) =
            BokkyPooBahsDateTimeLibrary.timestampToDateTime(targetMonthTimestamp);

        uint256 lastDayOfMonth = BokkyPooBahsDateTimeLibrary.getDaysInMonth(targetMonthTimestamp);

        occurrenceStart =
            BokkyPooBahsDateTimeLibrary.timestampFromDateTime(year, month, lastDayOfMonth, hour, minute, second);
    }
}
