import {
  parseEventLogs,
  type Address,
} from 'viem'

import scheduledProtocolAbi from './abi/ScheduledProtocol.json'

import {
  publicClient,
  type WalletConnection,
} from './clients'
import { scheduledProtocolAddress } from './config'
import type { CreatePaymentInput } from './payments'

interface Payment {
  payer: Address
  recipient: Address
  amount: bigint
  recurrence: number
  executeAfter: number
  expiresAfter: number
  totalOccurrences: number
  lastExecutedOccurrencePlusOne: number
  cancelled: boolean
}

function isPayment(payment: unknown): payment is Payment {
  if (typeof payment !== 'object' || payment === null) {
    return false
  }

  const value = payment as Record<string, unknown>

  return (
    typeof value.payer === 'string' &&
    typeof value.recipient === 'string' &&
    typeof value.amount === 'bigint' &&
    typeof value.recurrence === 'number' &&
    typeof value.executeAfter === 'number' &&
    typeof value.expiresAfter === 'number' &&
    typeof value.totalOccurrences === 'number' &&
    typeof value.lastExecutedOccurrencePlusOne === 'number' &&
    typeof value.cancelled === 'boolean'
  )
}

export async function getPayment(paymentId: bigint): Promise<Payment> {
  const payment = await publicClient.readContract({
    address: scheduledProtocolAddress,
    abi: scheduledProtocolAbi,
    functionName: 'getPayment',
    args: [paymentId],
  })

  if (!isPayment(payment)) {
    throw new Error('Invalid payment returned by contract')
  }

  return payment
}

export async function createPayment(
  walletClient: WalletConnection['walletClient'],
  payment: CreatePaymentInput,
) {
  const { request } = await publicClient.simulateContract({
    account: walletClient.account,
    address: scheduledProtocolAddress,
    abi: scheduledProtocolAbi,
    functionName: 'createPayment',
    args: [
      payment.recipient,
      payment.amount,
      payment.recurrence,
      payment.executeAfter,
      payment.expiresAfter,
      payment.totalOccurrences,
    ],
  })

  const hash = await walletClient.writeContract(request)

  const receipt = await publicClient.waitForTransactionReceipt({
    hash,
  })

  const logs = parseEventLogs({
    abi: scheduledProtocolAbi,
    eventName: 'PaymentCreated',
    logs: receipt.logs,
  })

  const paymentCreatedLog = logs[0]

  if (!paymentCreatedLog || !('args' in paymentCreatedLog)) {
    throw new Error('PaymentCreated event not found')
  }

  const args = paymentCreatedLog.args

  if (
    typeof args !== 'object' ||
    args === null ||
    !('paymentId' in args) ||
    typeof args.paymentId !== 'bigint'
  ) {
    throw new Error('PaymentCreated payment ID not found')
  }

  const paymentId = args.paymentId
  const createdPayment = await getPayment(paymentId)

  return {
    hash,
    paymentId,
    payment: createdPayment,
  }
}
