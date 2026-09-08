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
    ) external returns (uint256 paymentId) {
        if (recipient == address(0)) {
            revert ScheduledProtocolInvalidRecipient(recipient);
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
