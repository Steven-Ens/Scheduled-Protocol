import './style.css'
import { connectWallet } from './clients'
import {
  parseAmount,
  parseExecuteAfter,
  parseExpiresAfter,
  parseRecurrence,
  parseRecipient,
  parseTotalOccurrences,
  type CreatePaymentInput,
} from './payments'

const connectButton =
  document.querySelector<HTMLButtonElement>('#connect-wallet')

const walletAddress =
  document.querySelector<HTMLParagraphElement>('#wallet-address')

const createPaymentForm =
  document.querySelector<HTMLFormElement>('#create-payment-form')

connectButton?.addEventListener('click', async () => {
  try {
    const { account } = await connectWallet()

    connectButton.textContent = 'Connected'
    connectButton.disabled = true

    if (walletAddress) {
      walletAddress.textContent = account
    }
  } catch (error) {
    console.error(error)
  }
})

createPaymentForm?.addEventListener('submit', (event) => {
  event.preventDefault()

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

  console.log(payment)
})
