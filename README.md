# Scheduled Protocol

**Open Protocol for Scheduled Onchain Payments.**

Scheduled Protocol is a non-custodial protocol for creating deterministic onchain payment schedules.

## Capstone MVP

* Connect MetaMask.
* Create a scheduled payment through the frontend.
* Validate inputs before submission.
* Simulate the contract call with Viem.
* Approve and submit the transaction through MetaMask.
* Wait for confirmation on Arbitrum Sepolia.
* Decode the `PaymentCreated` event.
* Read the created payment back from the contract.
* Display the persisted payment in the browser.

## Tech Stack

* Solidity `0.8.35`
* Foundry / Forge
* OpenZeppelin where applicable
* Vite `8.3.0`
* TypeScript `6.0.3`
* Viem `2.56.3`
* Vanilla HTML/CSS
* MetaMask / EIP-1193
* Arbitrum Sepolia

## Frontend Architecture

* `config.ts` — chain and deployed contract configuration.
* `clients.ts` — Viem Public Client and Wallet Client.
* `payments.ts` — frontend input parsing and conversion.
* `protocol.ts` — contract reads, simulation, writes, receipts, and event decoding.
* `main.ts` — DOM events and UI updates.
* `ScheduledProtocol.json` — ABI generated directly from Foundry.

## Contract Deployment

* Network: **Arbitrum Sepolia**
* Chain ID: `421614`
* Contract:
  `0x071c3EAAA79e4360244f4226881EaA3CC04B1daA`
* Contract verified through Sourcify with an exact match.
* Deployment handled through `Deploy.s.sol`.

## Local Setup

```bash
git clone https://github.com/Steven-Ens/Scheduled-Protocol.git
cd Scheduled-Protocol/contracts

forge install --no-git \
  foundry-rs/forge-std \
  OpenZeppelin/openzeppelin-contracts \
  bokkypoobah/BokkyPooBahsDateTimeLibrary

forge build
forge test -vvv

cd ../frontend
npm ci
npm run build
npm run dev
```

## ABI Generation

The frontend ABI is generated directly from the compiled Foundry contract:

```bash
forge inspect --json ScheduledProtocol abi > ../frontend/src/abi/ScheduledProtocol.json
```

This keeps Foundry as the source of truth rather than maintaining a handwritten ABI.

## Security

* MetaMask retains all private keys.
* Frontend transactions are simulated before submission.
* Contract validation remains authoritative.
* No secret keys are stored in frontend code.
* Important npm dependencies are exact-pinned.
* `npm audit` and package-signature checks are used after dependency changes.
* OpenZeppelin is used where appropriate.
* Oracles and governance are not added because they are not currently required by the protocol.

## Testing

Completed:

* Foundry unit tests for payment creation and validation.
* Invalid payment-ID testing.
* Occurrence-derivation testing in progress.
* Manual end-to-end frontend testing on Arbitrum Sepolia.

Planned:

* Additional fuzz testing.
* Invariant/property testing.
* Fork testing where useful.
* Vitest frontend unit tests.
* Automated end-to-end frontend testing.

## Current Limitations

* Full recurring execution is still under development.
* Executor-driven token transfers are not complete.
* Production USDC settlement is not complete.
* Frontend styling is intentionally minimal.
* Current frontend input constraints will be reviewed against the final Solidity validation rules.
* Strongly typed ABI generation will be evaluated later.
* TypeScript `strict: true` will be evaluated during frontend hardening.

## Roadmap

* Complete Daily, Weekly, Monthly, and Last-of-Month occurrence derivation.
* Complete execution windows and replay protection.
* Finish executor-driven token transfers and protocol fees.
* Add fuzz and invariant tests.
* Add Vitest frontend tests.
* Improve frontend validation and styling.
* Add historical payment discovery.
* Evaluate strongly typed Foundry-to-Viem ABI generation.
* Complete production security review and deployment.

## Capstone Summary

* Working Solidity contract deployed to testnet.
* Working frontend connected to MetaMask.
* Real scheduled payment created on Arbitrum Sepolia.
* Created payment read back from contract state.
* Modular frontend architecture designed for future testing.
* Clear roadmap for completing the full Scheduled Protocol execution lifecycle.
