import './style.css'

import {
  connectWallet,
  type WalletConnection,
} from './clients'
import {
  parseAmount,
  parseExecuteAfter,
  parseExpiresAfter,
  parseRecurrence,
  parseRecipient,
  parseTotalOccurrences,
  type CreatePaymentInput,
} from './payments'
import { createPayment } from './protocol'

const connectButton =
  document.querySelector<HTMLButtonElement>('#connect-wallet')

const walletAddress =
  document.querySelector<HTMLParagraphElement>('#wallet-address')

const createPaymentForm =
  document.querySelector<HTMLFormElement>('#create-payment-form')

const paymentResult =
  document.querySelector<HTMLDivElement>('#payment-result')

let walletConnection: WalletConnection | undefined

connectButton?.addEventListener('click', async () => {
  try {
    walletConnection = await connectWallet()

    connectButton.textContent = 'Connected'
    connectButton.disabled = true

    if (walletAddress) {
      walletAddress.textContent = walletConnection.account
    }
  } catch (error) {
    console.error(error)
  }
})

createPaymentForm?.addEventListener('submit', async (event) => {
  event.preventDefault()

  try {
    if (!walletConnection) {
      throw new Error('Connect wallet before creating a payment')
    }

    const formData = new FormData(createPaymentForm)

    const payment: CreatePaymentInput = {
      recipient: parseRecipient(String(formData.get('recipient'))),
      amount: parseAmount(String(formData.get('amount'))),
      recurrence: parseRecurrence(String(formData.get('recurrence'))),
      executeAfter: parseExecuteAfter(String(formData.get('executeAfter'))),
      expiresAfter: parseExpiresAfter(String(formData.get('expiresAfter'))),
      totalOccurrences: parseTotalOccurrences(
        String(formData.get('totalOccurrences')),
      ),
    }

    const result = await createPayment(
      walletConnection.walletClient,
      payment,
    )

    if (paymentResult) {
      paymentResult.innerHTML = `
        <h2>Payment Created</h2>
        <p>Payment ID: ${result.paymentId}</p>
        <p>Transaction: ${result.hash}</p>
        <p>Payer: ${result.payment.payer}</p>
        <p>Recipient: ${result.payment.recipient}</p>
        <p>Amount: ${result.payment.amount}</p>
        <p>Recurrence: ${result.payment.recurrence}</p>
        <p>Execute After: ${result.payment.executeAfter}</p>
        <p>Execution Window: ${result.payment.expiresAfter}</p>
        <p>Total Occurrences: ${result.payment.totalOccurrences}</p>
      `
    }
  } catch (error) {
    console.error(error)
  }
})
