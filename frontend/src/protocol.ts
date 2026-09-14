import scheduledProtocolAbi from './abi/ScheduledProtocol.json'

import { scheduledProtocolAddress } from './config'
import { publicClient } from './clients'

export async function getPayment(paymentId: bigint) {
  return publicClient.readContract({
    address: scheduledProtocolAddress,
    abi: scheduledProtocolAbi,
    functionName: 'getPayment',
    args: [paymentId],
  })
}
