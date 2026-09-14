// Adds Viem's EIP-1193 typing for the injected browser wallet provider.
import 'viem/window'
import {
  createWalletClient,
  createPublicClient,
  custom,
  http
} from 'viem'

import { chain } from './config'

// Public client is available independently of MetaMask and wallet connection.
export const publicClient = createPublicClient({
  chain,
  transport: http(),
})

export async function connectWallet() {
  if (!window.ethereum) {
    throw new Error('MetaMask not found')
  }

  const [account] = await window.ethereum.request({
    method: 'eth_requestAccounts',
  })

  if (!account) {
    throw new Error('No wallet account found')
  }

  const walletClient = createWalletClient({
    account,
    chain,
    transport: custom(window.ethereum),
  })

  await walletClient.switchChain({
    id: chain.id,
  })

  return {
    walletClient,
    account,
  }
}
