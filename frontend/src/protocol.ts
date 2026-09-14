import scheduledProtocolAbi from './abi/ScheduledProtocol.json'

import {
  publicClient,
  type WalletConnection,
} from './clients'
import { scheduledProtocolAddress } from './config'
import type { CreatePaymentInput } from './payments'

export async function getPayment(paymentId: bigint) {
  return publicClient.readContract({
    address: scheduledProtocolAddress,
    abi: scheduledProtocolAbi,
    functionName: 'getPayment',
    args: [paymentId],
  })
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

  return {
    hash,
    receipt,
  }
}
