import {
  getAddress,
  parseEther,
  type Address,
} from 'viem'

export interface CreatePaymentInput {
  recipient: Address
  amount: bigint
  recurrence: number
  executeAfter: number
  expiresAfter: number
  totalOccurrences: number
}

export function parseRecipient(value: string): Address {
  return getAddress(value)
}

export function parseAmount(value: string): bigint {
  return parseEther(value)
}

export function parseRecurrence(value: string): number {
  return Number(value)
}

export function parseExecuteAfter(value: string): number {
  return Math.floor(new Date(value).getTime() / 1000)
}

export function parseExpiresAfter(value: string): number {
  return Number(value)
}

export function parseTotalOccurrences(value: string): number {
  return Number(value)
}
