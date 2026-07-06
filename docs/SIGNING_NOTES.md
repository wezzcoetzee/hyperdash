# Signing verification (READ before trading real funds)

The signing code (`Hyperdash/Signing/*`) mirrors the official Hyperliquid Python
SDK, but **it was written without an on-device compile/run**. Treat it as
"correct by construction, unverified in practice" until you complete the checks
below. Rounding of price/size and msgpack field order are the classic causes of
`signature invalid` or silently rejected orders.

## The scheme (what the code implements)

For an L1 action (`order`, `cancel`):

1. `connectionId = keccak256( msgpack(action) || nonce_be64 || vaultFlag[+addr] )`
   - `vaultFlag` = `0x00` (no vault) — Hyperdash always uses `0x00`.
2. phantom agent = `{ source: "a" (mainnet) | "b" (testnet), connectionId }`.
3. EIP-712 digest of `Agent(string source, bytes32 connectionId)` under domain
   `{ name:"Exchange", version:"1", chainId:1337, verifyingContract:0x0…0 }`.
4. secp256k1 **recoverable** signature over that digest → `{ r, s, v(27|28) }`.
5. POST `{ action, nonce, signature }` to `/exchange`.

## Verification ladder

1. **Unit tests (`⌘U`).** `SigningTests` checks msgpack bytes, the secp256k1
   vector (privkey 1 → `0x7e5f…95bdf`), a sign→recover round-trip, and action-hash
   determinism. All must pass. If `import secp256k1` fails to resolve the C
   symbols, that's the only place to fix — see "secp256k1 API" below.

2. **Cross-check against the Python SDK.** Install `hyperliquid-python-sdk`, sign
   the *same* cancel action with the *same* key + nonce, and compare the produced
   `connectionId` and `r/s/v`. They must match byte-for-byte.

   ```python
   from hyperliquid.utils.signing import sign_l1_action, action_hash
   ```

3. **Testnet dry run.** Settings → Network → Testnet. Fund a testnet account,
   approve an API wallet at app.hyperliquid.xyz (testnet), add it in Hyperdash,
   then cancel a resting order and close a small position. Confirm the fills on
   the Hyperliquid testnet UI.

4. **Only then** switch to Mainnet.

## Known places that may need adjustment

- **secp256k1 API.** `Secp256k1Signer` calls the C library from
  `21-DOT-DEV/swift-secp256k1` via `import libsecp256k1` (product `libsecp256k1`,
  confirmed against v0.23.x — the C symbols `secp256k1_context_create`,
  `secp256k1_ecdsa_sign_recoverable`, `secp256k1_ecdsa_recover`, etc. are public).
  If a future version renames the module, this file is the only place to change.
- **Price rounding (`Wire.price`).** Implements "≤5 significant figures AND
  ≤ (MAX_DECIMALS − szDecimals) decimals". Verify against a few live assets; if an
  order is rejected for tick size, this is the suspect.
- **Spot mids key.** `MetaService.spotAssetToUSDC` uses `@<pairIndex>` for the
  `allMids` lookup. Confirm the key format for the asset you're selling.
- **Bool JSON encoding.** The `/exchange` envelope is built with
  `JSONSerialization`; booleans (`b`, `r`) must serialise as `true/false`. Verify
  in a proxy if orders are rejected.
