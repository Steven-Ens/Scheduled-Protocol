// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.35;

import {IScheduledProtocol} from "./interfaces/IScheduledProtocol.sol";

/**
 * @dev Core implementation of Scheduled Protocol.
 */
contract ScheduledProtocol is IScheduledProtocol {
    uint256 private _nextPaymentId;
    uint256 private _accumulatedProtocolFees;

    mapping(uint256 paymentId => Payment payment) private _payments;

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
    function executePayment(uint256 paymentId) external override {}

    /**
     * @inheritdoc IScheduledProtocol
     */
    function cancelPayment(uint256 paymentId) external override {}

    /**
     * @inheritdoc IScheduledProtocol
     */
    function getPayment(uint256 paymentId) external view override returns (Payment memory payment) {
        return _payments[paymentId];
    }

    /**
     * @inheritdoc IScheduledProtocol
     */
    function getPaymentStatus(uint256 paymentId) external view override returns (PaymentStatus status) {}

    /**
     * @inheritdoc IScheduledProtocol
     */
    function withdrawProtocolFees() external override {}
}
