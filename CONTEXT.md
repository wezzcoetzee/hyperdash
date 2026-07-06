# Domain Glossary

Terms used in code, docs, and conversation. One meaning each; don't drift.

- **Wallet** — a tracked Hyperliquid account: a name plus a public address. Metadata lives in UserDefaults (optionally mirrored to iCloud KVS); the agent key, if any, lives only in the Keychain.
- **Agent key** — an API-wallet private key approved to trade (never withdraw) for a Wallet. The app's most sensitive material.
- **Vault** — the module that releases a Wallet's agent key, and the only path to it at trade time. Enforces the biometric-gate-before-Keychain ordering internally; callers make one call (`signingKey(for:reason:)`) and never sequence Face ID + Keychain themselves.
- **Environment** — mainnet or testnet (`HyperliquidNetwork`). Selected in Settings; testnet is always visibly badged.
- **Session** — one resolved Environment: the client bound to its network plus the shared meta cache (`HyperliquidSession`). Anything talking to the API takes a Session; nothing re-derives network → client.
- **Transport** — the seam between the client and the network (`HTTPTransport`). Two adapters: URLSession in the app, fixtures in tests.
- **Snapshot** — the read-model of a Wallet at a moment (`WalletSnapshot`): perps state, spot balances, open orders, mids. The only code that knows how `allMids` is keyed (perp marks by coin name, spot mids by `"@<pair index>"`); all USD valuation questions are answered by it.
- **Trade Desk** — the trade-execution module (`TradeDesk`). Everything between the confirmation sheet and the wire: asset resolution, aggressive IOC pricing, action building, Vault key release, signing, submission. Interface: `prepare(context) → Plan`, `execute(plan) → Receipt`.
- **Plan** — a prepared, not-yet-submitted trade (`TradePlan`): the rows the confirmation sheet shows, an optional warning, and the signed-format action (opaque to callers).
- **Receipt** — the outcome of an executed trade (`TradeReceipt`), reduced to the message the result screen shows.
- **Trade context** — which trade the user is confirming (`TradeContext`): close a perps position, cancel an open order, or sell a spot balance to USDC.
- **App lock** — the policy gating the UI behind Face ID (`AppLock`): unlocks biometrically, re-locks whenever the app leaves the foreground.
