# Hyperdash

A native SwiftUI iOS app for monitoring and trading Hyperliquid wallets.

## What it does (v1)

- **Monitor** any wallet by public address: total value, perp positions (leverage,
  liquidation price + distance, funding, uPnL), spot balances, open orders.
- **Trade** with an approved agent (API) wallet key: close positions, cancel
  orders, sell spot → USDC. Every trade is confirmed and gated by Face ID.
- **Storage**: wallet metadata in UserDefaults + iCloud key-value store; agent
  keys in the Keychain (optionally iCloud-synced).

## Requirements

- **Full Xcode** (App Store) — the Command Line Tools alone cannot build iOS apps.
- A free Apple ID is enough to sideload to your own device (7-day rebuild cycle).
  TestFlight and push notifications need the paid Apple Developer Program.

## Build & run

```sh
brew install xcodegen          # already installed if you followed setup
xcodegen generate              # regenerate Hyperdash.xcodeproj after adding files
open Hyperdash.xcodeproj
```

In Xcode: select the **Hyperdash** scheme → your device → set your Team under
*Signing & Capabilities* (Automatic) → Run.

Run the tests (`⌘U`) first — `SigningTests` proves the crypto pipeline works on
your machine before you trust it with real orders.

## Project layout

```
Hyperdash/
  App/           App entry, root/tab/lock views
  Models/        Decodable API models + formatting
  Networking/    /info + /exchange clients, meta resolver
  Signing/       msgpack, keccak, secp256k1, EIP-712, action builders
  Security/      Keychain (KeyStore), biometrics
  Store/         ObservableObject state + view models
  Views/         SwiftUI screens and components
HyperdashTests/  Signing self-checks
```

## Safety

- Start on **Testnet** (Settings → Network). Verify signing end to end before
  switching to Mainnet — see `docs/SIGNING_NOTES.md`.
- Agent keys can trade but **cannot withdraw** (Hyperliquid design). Generate one
  at https://app.hyperliquid.xyz/API.

## Roadmap

- Phase 5: monitoring backend + APNs push for liquidation/leverage alerts,
  TestFlight distribution (requires Apple Developer Program).
- Later: open positions, order placement, adjust leverage.
