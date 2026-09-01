// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

/**
 * @dev External interface for ScheduledProtocol.
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
     * block.timestamp, and is not stored directly.
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
        // Account that created the payment schedule and funds its payment executions. 
        address payer;
        // Account that receives each successful payment.
        address recipient;
        // USDC transferred to `recipient` per occurrence.
        uint96 amount;
        // Immutable payment schedule anchor representing the UTC timestamp of occurrence 0.
        uint40 executeAfter;
        // Duration of each occurrence's execution window.
        uint24 expiresAfter;
        // Total number of occurrences in the payment schedule including occurrence 0.
        uint32 totalOccurrences;
        // Last successfully executed occurrence index plus one. Zero means no occurrences have executed.
        uint32 lastExecutedOccurrencePlusOne;
        // Payment schedule recurrence type.
        RecurrenceType recurrence;
        // Whether the payer explicitly cancelled the payment schedule.
        bool cancelled;
    }

    // Errors

    /**
     * @dev Emitted when payment schedule `paymentId` is created by `payer`.
     */
    event PaymentCreated(
        uint256 indexed paymentId,
        address indexed payer,
        address indexed recipient,
        uint96 amount,
        uint40 executeAfter,
        uint24 expiresAfter,
        uint32 totalOccurrences,
        RecurrenceType recurrence
    );

    /**
     * @dev Emitted when occurrence `ocurrenceIndex` of payment schedule `paymentId` is successfully executed. 
     */
    event PaymentExecuted(
        uint256 indexed paymentId,
        uint32 indexed occurrenceIndex,
        addressed indexed executor 
    );

    /**
     * @dev Emitted when payment schedule `paymentId` is cancelled by its payer. 
     */
    event PaymentCancelled(uint256 indexed paymentId);

    // Functions
}
