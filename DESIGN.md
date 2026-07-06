---
name: Hyperdash
description: A native iOS Hyperliquid trading client with the calm of a precision instrument.
colors:
  hyperliquid-mint: "#32E7CD"
  mint-pressed: "#22B8A3"
  gain: "#34C759"
  loss: "#FF3B30"
  caution: "#FF9500"
  ink: "#0B100F"
  ink-muted: "#6C7A78"
  paper: "#F5F9F8"
  paper-raised: "#FCFEFD"
typography:
  display:
    fontFamily: "SF Pro Rounded, -apple-system, system-ui, sans-serif"
    fontSize: "34pt"
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: "normal"
  title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "22pt"
    fontWeight: 700
    lineHeight: 1.1
  headline:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "17pt"
    fontWeight: 600
    lineHeight: 1.2
  body:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "17pt"
    fontWeight: 400
    lineHeight: 1.3
  mono:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "15pt"
    fontWeight: 600
    lineHeight: 1.2
  label:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "11pt"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "0.02em"
rounded:
  pill: "4px"
  surface: "10px"
spacing:
  xs: "2px"
  sm: "4px"
  md: "8px"
  lg: "12px"
  xl: "16px"
components:
  button-primary:
    backgroundColor: "{colors.hyperliquid-mint}"
    textColor: "{colors.ink}"
    rounded: "{rounded.surface}"
    padding: "12px 20px"
  button-primary-pressed:
    backgroundColor: "{colors.mint-pressed}"
    textColor: "{colors.ink}"
  badge-long:
    textColor: "{colors.gain}"
    rounded: "{rounded.pill}"
    padding: "2px 6px"
  badge-short:
    textColor: "{colors.loss}"
    rounded: "{rounded.pill}"
    padding: "2px 6px"
  badge-testnet:
    textColor: "{colors.caution}"
    rounded: "{rounded.pill}"
    padding: "3px 8px"
---

# Design System: Hyperdash

## 1. Overview

**Creative North Star: "The Precision Instrument"**

Hyperdash is a finely-machined trading tool, not a crypto app. The scene it is built for is exact: one person, one hand on an iPhone, checking a perps position or firing an order, sometimes in bright daylight and sometimes at 2am with real money on the line. Everything answers to that moment. The interface stays quiet so the numbers can be trusted at a glance, and the single mint accent behaves like the one live indicator on an otherwise calm instrument face.

The system leans on iOS itself. Native grouped lists, SF typography, system materials, and standard sheets do the structural work, which is what earns the app its "shipped alongside Wallet and Stocks" feel. Design here is close to invisible: its job is legibility and dependability, never persuasion. There is nothing to sell, so nothing decorates. The one deliberate flourish is the account balance, set large in SF Rounded, the way Stocks renders a headline figure, so the most important number in the app reads instantly.

This system explicitly rejects the **neon crypto casino**: no glowing gradients, no hype-green candles, no gamified dopamine, no confetti, no saturated neon on black. It equally rejects the **cluttered pro-trader terminal** (a wall of tiny numbers) and the **generic fintech / neobank** look (interchangeable rounded cards and hero-metric templates). Restraint is the identity.

**Key Characteristics:**
- Native-first: iOS grouped lists, SF type, system semantic colors, standard sheets.
- One brand voice: Hyperliquid mint (`#32E7CD`) as the sole accent, used sparingly.
- Money reads first: SF Rounded for the balance, monospaced figures for sizes and addresses.
- Adaptive: full light and dark support; legible in daylight and in the dark.
- Flat and calm: tonal grouping for depth, never shadows or glows.

## 2. Colors

A near-monochrome adaptive neutral base carrying iOS system semantics, lit by a single mint accent and the conventional gain/loss signal pair.

### Primary
- **Hyperliquid Mint** (`#32E7CD`, `oklch(83% 0.14 178)`): The brand's one voice, wired through SwiftUI's `.tint`. It marks interactive and identity elements only: the primary action button, the wallet glyph, the lock/Face ID affordance. It is a signal, not a surface.
- **Mint Pressed** (`#22B8A3`): The deeper mint for the primary button's pressed state; provides contrast without introducing a second hue.

### Secondary (signal colors)
- **Gain Green** (`#34C759`, iOS system green): Positive PnL, positive ROE, buy-side order tags, and long-position markers. Meaning is always reinforced by a `+` sign or the word "Long", never carried by hue alone.
- **Loss Red** (`#FF3B30`, iOS system red): Negative PnL, sell-side tags, short-position markers, close/delete actions, and near-liquidation warnings.
- **Caution Orange** (`#FF9500`, iOS system orange): Testnet state and non-destructive warnings (secure-storage notices, testnet network badge). Signals "pay attention", distinct from loss.

### Neutral
- **Ink** (`#0B100F`): Primary text (light mode) and base surface (dark mode). A near-black faintly tinted toward the mint hue, never pure `#000`.
- **Ink Muted** (`#6C7A78`): Secondary text, captions, labels, and dividers. Maps to SwiftUI `.secondary`.
- **Paper** (`#F5F9F8`): The grouped-list backdrop on light; a near-white faintly tinted toward mint, never pure `#fff`.
- **Paper Raised** (`#FCFEFD`): Individual list rows and section content that sit above the backdrop.

Neutrals are driven by iOS adaptive system colors so both appearances stay correct. The hex values above are the sanctioned tint target: any custom (non-system) surface should carry the faint mint tint rather than a neutral gray.

### Named Rules
**The One Voice Rule.** Mint appears on no more than ~10% of any screen. It is reserved for the single primary action and identity glyphs. If two things are mint, one of them is wrong.

**The Signal-Not-Decoration Rule.** Green, red, and orange only ever encode state. They never style a heading, a border, or a background for looks. If a color is not reporting a fact, it is not allowed.

## 3. Typography

**Display Font:** SF Pro Rounded (with `-apple-system` fallback)
**Body Font:** SF Pro (system default)
**Mono Font:** SF Mono (with `ui-monospace` fallback)

**Character:** Pure Apple system type. SF Rounded softens the single hero number so it reads as approachable rather than austere; SF Mono keeps every price, size, and address in perfect vertical alignment so figures can be scanned and compared without drift. Everything else is stock SF, which is the point: it disappears into the OS.

### Hierarchy
- **Display** (SF Rounded, Bold, 34pt): The account balance only. One per screen, the app's single visual headline.
- **Title** (SF, Bold, 22pt / `.title2`): Trade confirmation and result screen titles.
- **Headline** (SF, Semibold, 17pt / `.headline`): Coin symbols, wallet names, empty-state titles, section anchors.
- **Body** (SF, Regular, 17pt / `.body`): Standard row and sheet content. Its monospaced sibling (`.body.monospaced()`) renders wallet addresses.
- **Mono** (SF Mono, Semibold, 15pt / `.subheadline.monospaced` weighted): PnL values, position sizes, spot amounts, order figures. All money is monospaced.
- **Label** (SF, Bold, 11pt / `.caption2`): Uppercase-weight pills and tags (Long/Short, network, order side), with slight tracking.

### Named Rules
**The Monospaced Money Rule.** Every number that represents money, size, or an address is set in SF Mono. Prose and labels are proportional SF; figures are never proportional. Columns of numbers must align on the digit.

**The One Headline Rule.** SF Rounded at display size is spent on exactly one element per screen: the balance. Nothing else earns that weight.

## 4. Elevation

Flat by default. Depth comes entirely from iOS tonal layering: the grouped-list backdrop (`Paper`) sits behind slightly lighter rows (`Paper Raised`), and sheets slide over a system dim. There are no drop shadows, no glows, no glassmorphism. A row is distinguished from its background by tone and inset, the way native Settings and Wallet do it, not by a floating shadow.

Sheets (Add Wallet, Trade Confirmation) use the standard iOS sheet presentation and its system material; that system-provided separation is the only "elevation" in the app.

### Named Rules
**The No-Glow Rule.** Nothing glows. The instant an element has a colored halo or blur behind it, the app has drifted toward the neon-casino aesthetic it rejects. Separation is tonal, never luminous.

## 5. Components

### Buttons
- **Shape:** Continuous iOS corners at the system default (~`{rounded.surface}`, 10px).
- **Primary:** SwiftUI `.borderedProminent` tinted mint. Mint fill, `Ink` label, used for the single committing action per screen (Unlock, Confirm Trade, Add). Pressed state deepens to `Mint Pressed`.
- **Secondary:** `.bordered` / plain, label in `.tint` mint on a neutral surface.
- **Destructive:** Red-tinted swipe actions and buttons for Close Position and Delete Wallet. Destructive intent is always red and always requires a deliberate gesture.

### Badges / Pills
- **Style:** Small `{rounded.pill}` (4px) rectangles, colored text over the same color at ~18–25% opacity fill. No border.
- **Long / Short:** `Gain`/`Loss` text on a matching 18% tint.
- **Order side (Buy / Sell):** `Gain`/`Loss` `.caption2` bold text.
- **Network:** `Gain` at 20% for Mainnet, `Caution` at 25% for Testnet, so environment is unmistakable before any trade.

### Cards / Containers
- **Corner Style:** System grouped-list corners (~10px); the app does not hand-roll card shapes.
- **The Account Summary is not a floating card.** It is section content inside a grouped list (balance, then a metrics row for margin/leverage/PnL). Leverage tints from `Gain` toward `Loss` as it climbs, as a risk read.
- **Background:** `Paper Raised` rows on a `Paper` backdrop; detail lists use `.listRowBackground(.clear)` to sit directly on the grouped surface.
- **Shadow Strategy:** None. See Elevation.
- **Internal Padding:** Vertical rhythm at `{spacing.sm}`–`{spacing.xl}` (4–16px); rows breathe with `.padding(.vertical, 4)`.

### Inputs / Fields
- **Style:** Standard iOS text fields inside grouped `Form` sections. Address and key entry uses `.body.monospaced()` so hex is legible and verifiable.
- **Validation:** Errors surface in `Loss` red as inline `.caption`; storage/security notices use `Caution` orange.
- **Focus:** System default focus treatment; no custom glow.

### Navigation
- **Structure:** Root `TabView` with two tabs, Wallets (`wallet.bifold`) and Settings (`gearshape`). Wallet detail pushes in a navigation stack; Add Wallet and Trade Confirmation present as sheets.
- **States:** System tab-bar tint (mint) for the active tab. Standard large-title navigation.
- **Lock:** A full-screen lock gate (`lock.shield`, mint) precedes the tabs when biometric lock is on; Face ID unlock is a prominent mint button.

## 6. Do's and Don'ts

### Do:
- **Do** keep mint to ~10% of any screen: one primary action, identity glyphs only (The One Voice Rule).
- **Do** set every price, size, PnL, and address in SF Mono, aligned on the digit (The Monospaced Money Rule).
- **Do** reinforce gain/loss with a `+`/`-` sign or a word ("Long", "Buy"), never hue alone.
- **Do** convey depth through tonal grouping and insets, the way native Settings and Wallet do.
- **Do** gate every money-spending action behind explicit, deliberate confirmation (sheet + biometric), and color destructive paths red.
- **Do** faintly tint custom neutral surfaces toward the mint hue rather than using flat gray.
- **Do** support light and dark equally; verify legibility in bright daylight and in a dark room.

### Don't:
- **Don't** build the **neon crypto casino**: no glowing gradients, no hype-green candles, no gamified dopamine, no confetti, no saturated neon on black.
- **Don't** let anything glow, blur, or float on a colored halo (The No-Glow Rule); no glassmorphism.
- **Don't** drift into the **cluttered pro-trader terminal**: no wall of tiny numbers that trades legibility for coverage.
- **Don't** ship the **generic fintech / neobank** look: no interchangeable rounded-card grids, no hero-metric template (big number + gradient accent + supporting stat cards). The balance is a native Stocks-style figure, not a marketing hero.
- **Don't** use gradient text (`background-clip: text`) or side-stripe accent borders anywhere.
- **Don't** introduce a second accent hue. Mint is the only voice; green/red/orange are signals, not styling.
- **Don't** use pure `#000` or `#fff`; neutrals are faintly mint-tinted or adaptive system colors.
- **Don't** animate for decoration; motion is functional feedback only, and must respect Reduce Motion.
