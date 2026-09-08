// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

/**
 * @dev External interface for Scheduled Protocol.
 */
interface IScheduledProtocol {
    /**
     * @dev Defines how a payment schedule recurs.
     */
    enum RecurrenceType {
        None,
        Daily,
        Weekly,
        Monthly,
        LastOfMonth
    }

    /**
     * @dev Represents the lifecycle state of a payment schedule. Derived from the payment schedule's stored state and
     * `block.timestamp`, and is not stored directly.
     */
    enum PaymentStatus {
        Active,
        Cancelled,
        Completed
    }

    /**
     * @dev Stores a payment schedule and its minimal mutable state.
     */
    struct Payment {
        // Account that created the payment schedule and funds its executions.
        address payer;
        // Account that receives each successful payment.
        address recipient;
        // USDC transferred to `recipient` per occurrence.
        uint96 amount;
        // Payment schedule recurrence type.
        RecurrenceType recurrence;
        // Immutable payment schedule anchor representing the UTC timestamp of occurrence 0.
        uint40 executeAfter;
        // Duration of each occurrence's execution window.
        uint24 expiresAfter;
        // Total number of occurrences in the payment schedule, including occurrence 0.
        uint32 totalOccurrences;
        // Last successfully executed occurrence index plus one. Zero means no occurrences have executed.
        uint32 lastExecutedOccurrencePlusOne;
        // Whether the payer explicitly cancelled the payment schedule.
        bool cancelled;
    }

    /**
     * @dev `recipient` is the zero address.
     */
    error ScheduledProtocolInvalidRecipient(address recipient);

    /**
     * @dev `amount` is zero.
     */
    error ScheduledProtocolInvalidAmount(uint96 amount);

    /**
     * @dev Emitted when payment schedule `paymentId` is created by `payer`.
     */
    event PaymentCreated(
        uint256 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        uint96 amount,
        RecurrenceType recurrence,
        uint40 executeAfter,
        uint24 expiresAfter,
        uint32 totalOccurrences
    );

    /**
     * @dev Emitted when occurrence `occurrenceIndex` of payment schedule `paymentId` is successfully executed.
     */
    event PaymentExecuted(uint256 indexed paymentId, uint32 indexed occurrenceIndex, address indexed executor);

    /**
     * @dev Emitted when payment schedule `paymentId` is cancelled by its payer.
     */
    event PaymentCancelled(uint256 indexed paymentId);

    /**
     * @dev Emitted when `amount` of accumulated protocol fees is withdrawn by `owner`.
     */
    event ProtocolFeesWithdrawn(address indexed owner, uint256 amount);

    /**
     * @dev Creates a new payment schedule for the caller.
     *
     * Emits a {PaymentCreated} event.
     */
    function createPayment(
        address recipient,
        uint96 amount,
        RecurrenceType recurrence,
        uint40 executeAfter,
        uint24 expiresAfter,
        uint32 totalOccurrences
    ) external returns (uint256 paymentId);

    /**
     * @dev Executes the currently eligible occurrence of payment schedule `paymentId`.
     *
     * Emits a {PaymentExecuted} event.
     */
    function executePayment(uint256 paymentId) external;

    /**
     * @dev Cancels payment schedule `paymentId`.
     *
     * Emits a {PaymentCancelled} event.
     */
    function cancelPayment(uint256 paymentId) external;

    /**
     * @dev Returns payment schedule `paymentId`.
     */
    function getPayment(uint256 paymentId) external view returns (Payment memory payment);

    /**
     * @dev Returns the current lifecycle state of payment schedule `paymentId`.
     */
    function getPaymentStatus(uint256 paymentId) external view returns (PaymentStatus status);

    /**
     * @dev Withdraws accumulated protocol fees to the owner.
     *
     * Emits a {ProtocolFeesWithdrawn} event.
     */
    function withdrawProtocolFees() external;
}
