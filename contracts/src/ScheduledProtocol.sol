// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.35;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

import {IScheduledProtocol} from "./interfaces/IScheduledProtocol.sol";

/**
 * @dev Core implementation of Scheduled Protocol.
 */
contract ScheduledProtocol is IScheduledProtocol, Ownable2Step {
    using SafeERC20 for IERC20;

    IERC20 private immutable USDC;
    // 0.80 in USDC
    uint256 private constant EXECUTOR_FEE = 800_000;
    // 0.20 in USDC
    uint256 private constant PROTOCOL_FEE = 200_000;

    uint256 private _nextPaymentId;
    uint256 private _accumulatedProtocolFees;

    mapping(uint256 paymentId => Payment payment) private _payments;

    /**
     * @dev Reverts if `paymentId` does not exist.
     */
    modifier isValidPaymentId(uint256 paymentId) {
        if (paymentId >= _nextPaymentId) {
            revert ScheduledProtocolInvalidPaymentId(paymentId);
        }
        _;
    }

    /**
     * @dev Sets the USDC token used for payment settlement.
     */
    constructor(IERC20 usdc_) Ownable(msg.sender) {
        USDC = usdc_;
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
        uint256 timestamp = block.timestamp;
        if (timestamp < payment.executeAfter) {
            revert ScheduledProtocolExecutionNotStarted(payment.executeAfter);
        }

        PaymentStatus status = _getPaymentStatus(paymentId);
        if (status != PaymentStatus.Active) {
            revert ScheduledProtocolInvalidPaymentStatus(status);
        }

        (uint256 occurrenceIndex, uint256 occurrenceStart) =
            _deriveOccurrence(payment.recurrence, payment.executeAfter, timestamp);

        if (timestamp >= occurrenceStart + payment.expiresAfter) {
            revert ScheduledProtocolExecutionWindowExpired(occurrenceIndex);
        }

        if (payment.lastExecutedOccurrencePlusOne == occurrenceIndex + 1) {
            revert ScheduledProtocolOccurrenceAlreadyExecuted(occurrenceIndex);
        }

        // Effects are applied before external calls per checks-effects-interactions.

        // Safe because `occurrenceIndex` is always less than the `uint32` `totalOccurrences` count, so casting it and
        // adding one cannot exceed `type(uint32).max`.
        // forge-lint: disable-next-line(unsafe-typecast)
        payment.lastExecutedOccurrencePlusOne = uint32(occurrenceIndex) + 1;
        _accumulatedProtocolFees += PROTOCOL_FEE;

        // Principal
        USDC.safeTransferFrom(payment.payer, payment.recipient, payment.amount);
        // Executor fee
        USDC.safeTransferFrom(payment.payer, msg.sender, EXECUTOR_FEE);
        // Protocol fee
        USDC.safeTransferFrom(payment.payer, address(this), PROTOCOL_FEE);

        emit PaymentExecuted(paymentId, occurrenceIndex, msg.sender);
    }

    /**
     * @inheritdoc IScheduledProtocol
     */
    function cancelPayment(uint256 paymentId) external override isValidPaymentId(paymentId) {
        Payment storage payment = _payments[paymentId];
        if (msg.sender != payment.payer) {
            revert ScheduledProtocolUnauthorizedCaller(msg.sender);
        }

        PaymentStatus status = _getPaymentStatus(paymentId);
        if (status != PaymentStatus.Active) {
            revert ScheduledProtocolInvalidPaymentStatus(status);
        }

        payment.cancelled = true;
        emit PaymentCancelled(paymentId);
    }

    /**
     * @inheritdoc IScheduledProtocol
     */
    function getPayment(uint256 paymentId) external view override isValidPaymentId(paymentId) returns (Payment memory) {
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
        returns (PaymentStatus)
    {
        return _getPaymentStatus(paymentId);
    }

    /**
     * @inheritdoc IScheduledProtocol
     */
    function getAccumulatedProtocolFees() external view override returns (uint256) {
        return _accumulatedProtocolFees;
    }

    /**
     * @inheritdoc IScheduledProtocol
     */
    function withdrawProtocolFees() external override onlyOwner {
        uint256 accumulatedProtocolFees = _accumulatedProtocolFees;

        if (accumulatedProtocolFees == 0) {
            revert ScheduledProtocolNoProtocolFeesAccumulated();
        }

        delete _accumulatedProtocolFees;

        USDC.safeTransfer(owner(), accumulatedProtocolFees);

        emit ProtocolFeesWithdrawn(owner(), accumulatedProtocolFees);
    }

    /**
     * @dev Ownership renunciation is disabled to prevent the protocol from becoming ownerless.
     */
    function renounceOwnership() public pure override {
        revert ScheduledProtocolOwnershipRenunciationDisabled();
    }

    /**
     * @dev Derives payment status from cancellation and expiration.
     */
    function _getPaymentStatus(uint256 paymentId) internal view returns (PaymentStatus status) {
        Payment storage payment = _payments[paymentId];

        if (payment.cancelled) {
            return PaymentStatus.Cancelled;
        }

        if (payment.lastExecutedOccurrencePlusOne == payment.totalOccurrences) {
            return PaymentStatus.Completed;
        }

        // `block.timestamp` is intentionally used as the protocol's authoritative scheduling clock.
        // forge-lint: disable-next-line(block-timestamp)
        uint256 timestamp = block.timestamp;
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
            occurrenceIndex = (timestamp - executeAfter) / 1 weeks;
            occurrenceStart = executeAfter + occurrenceIndex * 1 weeks;
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
