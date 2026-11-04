# Domain Glossary

Terms used in code, docs, and conversation. One meaning each; don't drift.

- **Wallet** — a tracked Hyperliquid account: a name plus a public address. Metadata lives in UserDefaults (optionally mirrored to iCloud KVS); the agent key, if any, lives only in the Keychain.
- **Agent key** — an API-wallet private key approved to trade (never withdraw) for a Wallet. The app's most sensitive material.
- **Vault** — the module that releases a Wallet's agent key, and the only path to it at trade time. Enforces the biometric-gate-before-Keychain ordering internally; callers make one call (`signingKey(for:reason:)`) and never sequence Face ID + Keychain themselves.
- **Environment** — mainnet or testnet (`HyperliquidNetwork`). Selected in Settings; testnet is always visibly badged.
- **Session** — one resolved Environment: the client bound to its network plus the shared meta cache (`HyperliquidSession`). Anything talking to the API takes a Session; nothing re-derives network → client.
- **Transport** — the seam between the client and the network (`HTTPTransport`). Two adapters: URLSession in the app, fixtures in tests.
- **Snapshot** — the read-model of a Wallet at a moment (`WalletSnapshot`): perps state, spot balances, open orders, mids, abstraction. The only code that knows how `allMids` is keyed (perp marks by coin name, spot mids by `"@<pair index>"`); all USD valuation questions are answered by it.
- **Wallet data** — the shared per-wallet cache (`WalletDataStore`): each Wallet's latest Snapshot, portfolio and fetch time. Dashboard, the wallets tab and wallet detail all read it; the app refreshes it every 30s while active and clears it when the Environment changes.
- **24h change** — a Wallet's move over the portfolio `day` window (`DayChange`), taken from PnL history so deposits and withdrawals never count as gains.
- **Abstraction** — which balances back an address's positions (`AccountAbstraction`, from `userAbstraction`). Standard keeps perps and spot balances apart, so account value sums them. Unified account and portfolio margin share one balance per asset, reported whole in `spotClearinghouseState` — perps equity there is a slice of the spot value, never an addend.
- **Trade Desk** — the trade-execution module (`TradeDesk`). Everything between the confirmation sheet and the wire: asset resolution, aggressive IOC pricing, action building, Vault key release, signing, submission. Interface: `prepare(context) → Plan`, `execute(plan) → Receipt`.
- **Plan** — a prepared, not-yet-submitted trade (`TradePlan`): the rows the confirmation sheet shows, an optional warning, and the signed-format action (opaque to callers).
- **Receipt** — the outcome of an executed trade (`TradeReceipt`), reduced to the message the result screen shows.
- **Trade context** — which trade the user is confirming (`TradeContext`): close a perps position, cancel an open order, or sell a spot balance to USDC.
- **App lock** — the policy gating the UI behind Face ID (`AppLock`): unlocks biometrically, re-locks whenever the app leaves the foreground.
- **Funding** — perp funding paid or received by a Wallet (`userFunding`), summarised as net 24h, net 7d and a per-coin 7d breakdown (`FundingSummary`). Negative means paid.
- **Position group** — open positions across every Wallet that share a coin, side and DEX (`PositionGroup`), with total size, combined uPnL and the nearest liquidation distance.
