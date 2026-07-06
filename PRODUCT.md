# Product

## Register

product

## Users

A single power user (the developer) trading on Hyperliquid from their own iPhone. Crypto-native and fluent in perps and spot mechanics: no explanation of leverage, margin, or order types is needed. Uses the app to check positions and balances and to place and confirm trades against their own wallets, without opening a browser or an exchange UI. Keys are held locally and every session is biometric-locked, so the physical context is a phone in hand, one person, real money.

## Product Purpose

A private, secure iOS client for Hyperliquid. It shows wallets, perps positions, spot balances, and open orders, and it signs and submits trades locally using the owner's keys (EIP-712 / secp256k1) behind Face ID. It exists to make routine account checks and trade execution fast and low-anxiety on mobile, without the weight of a full exchange interface. Success is a trade placed with confidence and zero hesitation about whether it did the right thing.

## Brand Personality

Calm, deliberate, native. Three words: composed, precise, trustworthy. It should feel like a first-party iOS app that shipped alongside Wallet and Stocks, not a third-party crypto product. Confidence is expressed through restraint and finish rather than energy or persuasion. There is nothing to sell here; the interface's only job is to be legible and dependable while the owner moves money.

## Anti-references

- **Neon crypto casino** (primary): glowing gradients, hype-green candles, gamified dopamine, confetti, saturated neon on black. Explicitly rejected.
- Cluttered pro-trader terminal: wall-of-numbers density and tiny fonts that trade legibility for coverage.
- Generic fintech / neobank SaaS: rounded-card blandness and hero-metric templates that feel interchangeable.

## Design Principles

- **Native by default.** Reach for system materials, SF typography, and standard iOS affordances before inventing anything. If Apple's own apps solve it, solve it their way.
- **Calm under money.** Every screen should lower anxiety around irreversible, expensive actions. Clarity and confirmation win over raw speed.
- **Hard to fat-finger.** The path to spending money is always deliberate: explicit confirmation, biometric gating, and unambiguous review before submit. Never make the destructive action the easy one.
- **High signal, low chrome.** Show the numbers that matter at a glance. No decoration competes with data; no container exists without a reason.
- **Trust through restraint.** This is a security-first product holding real keys. The finish itself is the promise that the owner's money is safe.

## Accessibility & Inclusion

- Single-user app, so no formal WCAG conformance target, but legibility is non-negotiable: maintain strong text contrast and support Dynamic Type.
- Gains and losses use conventional red/green. Where it is cheap, reinforce direction with sign and position so meaning does not rest on hue alone.
- Respect Reduce Motion; motion is functional, never decorative.
