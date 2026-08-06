import Foundation

/// Response of the `userAbstraction` info request: the account abstraction mode
/// an address trades under.
///
/// The distinction matters for every valuation question. Under a standard
/// account the perps and spot clearinghouses hold separate balances, so account
/// value is their sum. Under unified account and portfolio margin there is one
/// balance per asset shared by spot and cross-margin positions, and Hyperliquid
/// reports all of it — including the collateral backing perp margin, held as
/// `hold` on the spot balance — in `spotClearinghouseState`. Adding perps equity
/// on top of that counts the same collateral twice.
///
/// The endpoint has returned both a bare string and an object wrapper across API
/// revisions, so decoding accepts either shape and treats anything unrecognised
/// as `.standard` — the pre-existing behaviour.
enum AccountAbstraction: String, Decodable, Equatable {
    case standard
    case unifiedAccount
    case portfolioMargin

    /// True when `spotClearinghouseState` is the source of truth for the whole
    /// trading account, and perps equity is a slice of it rather than an addend.
    var spotHoldsWholeAccount: Bool { self != .standard }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let raw = try? container.decode(String.self) {
            self = AccountAbstraction(raw: raw)
        } else if let object = try? container.decode([String: String].self),
                  let raw = Self.modeKeys.compactMap({ object[$0] }).first {
            self = AccountAbstraction(raw: raw)
        } else {
            self = .standard
        }
    }

    private static let modeKeys = ["type", "mode", "abstraction", "userAbstraction"]

    private init(raw: String) {
        let value = raw.lowercased()
        if value.contains("unified") {
            self = .unifiedAccount
        } else if value.contains("portfolio") {
            self = .portfolioMargin
        } else {
            self = .standard
        }
    }
}
