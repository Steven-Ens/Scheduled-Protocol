import './style.css'

import { connectWallet } from './clients'

const connectButton =
  document.querySelector<HTMLButtonElement>('#connect-wallet')

const walletAddress =
  document.querySelector<HTMLParagraphElement>('#wallet-address')

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
