---
target: hyperdash iOS app
total_score: 31
p0_count: 0
p1_count: 2
timestamp: 2026-07-24T05-43-50Z
slug: hyperdash-ios-app
---
# Design Critique — Hyperdash (iOS)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Skeleton layout doesn't match loaded content; otherwise strong |
| 2 | Match System / Real World | 4 | Native SF, correct perps vocabulary for the audience |
| 3 | User Control and Freedom | 4 | Cancel/Close everywhere, swipe actions, retry, interactiveDismissDisabled during submit |
| 4 | Consistency and Standards | 2 | Two competing summary components; card-grid drift from the stated North Star |
| 5 | Error Prevention | 4 | Biometric gate + confirmation sheet + destructive-red; hard to fat-finger |
| 6 | Recognition Rather Than Recall | 3 | Network badge + labeled icons good; agent-key state slightly buried |
| 7 | Flexibility and Efficiency | 3 | Swipe actions + pull-to-refresh; no bulk beyond close-all |
| 8 | Aesthetic and Minimalist Design | 2 | Dashboard is a stack of rounded-card grids — the look DESIGN.md bans |
| 9 | Error Recovery | 3 | Clear inline errors + retry; trade-fail message passes through raw API text |
| 10 | Help and Documentation | 3 | Good inline footers (agent key, Face ID); no deeper help, acceptable for single user |
| **Total** | | **31/40** | **Good — solid foundation, one identity drift to correct** |

## Anti-Patterns Verdict

**LLM assessment:** This does NOT read as generic AI slop — it reads as a competently built native app that has quietly drifted away from its own design system. The engineering discipline is real (biometric gating, skeletons, empty states, swipe actions, confirmation sheets). The problem is the opposite of most AI output: not strangeness, but a regression toward safe fintech-card sameness that the project explicitly rejected.

**Deterministic scan:** `detect.mjs` returned `[]` (exit 0). It only parses HTML/CSS, so a SwiftUI codebase is out of scope; treat this as N/A, not a pass.

**Visual overlays:** Not available — no browser-renderable target for a native iOS app.

## Overall Impression
The app is calm, legible, and native — most of the brand promise is intact. But the single most distinctive element in DESIGN.md, the Stocks-style hero balance in SF Rounded largeTitle, has been replaced by 2×2 grids of identical rounded stat cards (`VaultStatCard`) on both the Dashboard and Wallet Detail. That is verbatim the "generic fintech / neobank hero-metric template + interchangeable rounded-card grid" the design system bans. The original `AccountSummaryCard` that embodied the North Star is now dead, unreferenced code. Biggest opportunity: restore the one-headline balance and stop leading screens with card grids.

## What's Working
1. **Money-under-stress safety.** Every spend routes through a sheet with a monospaced review table, a caution warning slot, a destructive-styled verb button, and a Face ID footer. `interactiveDismissDisabled` during submit prevents mid-flight dismissal. This is the brand's "hard to fat-finger" principle, fully realized.
2. **State completeness.** Loading skeletons (not spinners), `ContentUnavailableView` empty states that teach the next action, and error rows with Retry — the product-register "every component has all its states" bar is met.
3. **Signal discipline.** Direction is always reinforced by word + sign (LONG/SHORT tag, signed PnL), never hue alone; light-mode gain/loss colors are darkened for contrast. Reads correctly for accessibility.

## Priority Issues

- **[P1] Card-grid drift abandons the North Star.** `VaultStatGrid` (2×2 `VaultStatCard`) leads Wallet Detail, and the Dashboard stacks four stat cards + a 2-card PnL-leaders grid + an Open-Interest card. DESIGN.md's signature move — the balance as a single SF Rounded largeTitle figure, "not a floating card" — is gone, and `AccountSummaryCard` (which implements exactly that) is unused. The comment "styled after the copy-trade vault dashboard" confirms a deliberate borrow of the look the brand rejects.
  - **Why it matters:** This is the difference between "shipped alongside Wallet and Stocks" and "another neobank." The card grid is the app's identity leaking away.
  - **Fix:** Restore `AccountSummaryCard` (or fold its headline balance into the grid header) so each screen has one dominant number, then demote the secondary metrics to a lighter row instead of equal-weight cards.
  - **Suggested command:** `$impeccable layout`

- **[P1] Loading skeleton misrepresents the loaded screen.** `WalletDetailView.loadingSkeleton` renders the OLD layout — "Total Value" largeTitle + Perps Equity / Spot Value / Withdrawable — but the loaded content is `VaultStatGrid` (Balance / Leverage / P/L / Positions) + charts. The placeholder promises a screen the app no longer shows.
  - **Why it matters:** Skeletons exist to reserve the real layout; a mismatched one produces a visible jump and undercuts "visibility of system status."
  - **Fix:** Make the skeleton mirror the current `content()` structure (stat grid + chart cards), or drive both from one shared layout.
  - **Suggested command:** `$impeccable polish`

- **[P2] Two competing summary components / dead code.** `AccountSummaryCard` is fully implemented, has richer risk data (Margin Used, Maint. Margin, leverage tint), and is referenced nowhere. `VaultStatGrid` won by usage but carries less risk information.
  - **Why it matters:** Ambiguity about the canonical component invites future inconsistency and hides the more informative summary.
  - **Fix:** Decide on one. If `VaultStatGrid` stays, delete `AccountSummaryCard`; if the headline balance returns, retire the grid.
  - **Suggested command:** `$impeccable distill`

- **[P2] Corner-radius token drift.** Cards use `cornerRadius: 12` throughout while DESIGN.md's `rounded.surface` token is 10px. Small, but it's the kind of drift that compounds.
  - **Fix:** Centralize the radius in one constant and apply it.
  - **Suggested command:** `$impeccable polish`

- **[P2] Trade-failure copy passes through raw API text.** `TradeConfirmationView` renders `model.stage.failed(message)` directly. Hyperliquid error strings can be terse/technical at the exact 2am high-stakes moment the brand is designed for.
  - **Fix:** Map known failure cases to plain-language guidance; fall back to raw text only for the unknown.
  - **Suggested command:** `$impeccable clarify`

## Persona Red Flags

**Alex (Power User / the actual owner):** Close-all exists, but there's no way to act on multiple wallets at once from the Dashboard — every trade requires drilling into a wallet. The 2×2 grids cost vertical space he'd trade for density. No haptic confirmation noted on submit.

**Casey (Distracted Mobile, one-handed, 2am):** Primary actions live in sheets (good, bottom-reachable), but the Wallet Detail's key affordances (Close all, agent-key row) sit far down a long scroll. The trade verb button in the confirmation sheet is destructive-red even for a benign spot sell — under stress, red-everywhere dilutes the signal that should mean "irreversible."

**Sam (Accessibility):** Strong — labeled icons, direction reinforced by text, darkened contrast colors. Watch `minimumScaleFactor(0.6)` on `VaultStatCard`: a large balance under Dynamic Type XXL could shrink below comfortable size inside the small card, which the largeTitle hero would not.

## Minor Observations
- `ShortLongRatioCard` bar segments are pure green/red with no inline label, but the stats beneath carry the numbers — acceptable, meaning isn't hue-only.
- Chart mint (`brandMint`) is hardcoded because Swift Charts ignores `.tint`; fine, but it's a second source of truth for the brand color vs. the asset catalog.
- `AddWalletView` uses `DispatchQueue.main.asyncAfter(0.1)` to focus the name field — works, but fragile; `.defaultFocus`/presentation-detent focus is sturdier.

## Questions to Consider
- What if each screen had exactly one number the eye lands on first, the way Stocks does — would the card grid survive that test?
- Does the Dashboard need four equal-weight stat cards, or is Total Balance the only headline and the rest a quiet supporting row?
- Should destructive-red be reserved for genuinely irreversible closes, with spot sells styled as ordinary primary actions?
