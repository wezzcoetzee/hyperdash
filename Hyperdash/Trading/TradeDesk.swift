import Foundation

/// What the trade confirmation sheet renders and what execute submits.
/// The action is opaque to callers — only the desk reads it back.
struct TradePlan {
    let rows: [(String, String)]
    let warning: String?
    let action: MsgPackValue
}

struct TradeReceipt {
    let message: String
}

/// Everything between the trade confirmation sheet and the wire: resolves
/// assets, prices the order, builds the action, releases the signing key
/// through the vault, signs, and submits.
struct TradeDesk {
    let session: HyperliquidSession
    let vault: Vault
    let wallet: Wallet

    func prepare(_ context: TradeContext) async throws -> TradePlan {
        switch context {
        case .closePosition(let position):
            return try await closePositionPlan(position)
        case .cancelOrder(let order):
            return try await cancelOrderPlan(order)
        case .sellSpot(let balance):
            return try await sellSpotPlan(balance)
        }
    }

    func execute(_ plan: TradePlan, reason: String) async throws -> TradeReceipt {
        let key = try await vault.signingKey(for: wallet, reason: reason)
        let exchange = try session.exchange(agentKeyHex: key)
        let response = try await exchange.submit(action: plan.action)
        return TradeReceipt(message: Self.receiptMessage(response))
    }

    private func mark(for key: String) async throws -> Double {
        let mids = try await session.info.allMids()
        guard let mark = mids[key], mark > 0 else {
            throw HyperliquidError.exchange("No current price for \(key).")
        }
        return mark
    }

    private func closePositionPlan(_ position: Position) async throws -> TradePlan {
        let asset = try await session.meta.perpAsset(coin: position.coin)
        let markPrice = try await mark(for: asset.midKey)
        let isBuy = !position.isLong
        let price = TradeActions.aggressivePrice(mark: markPrice, isBuy: isBuy)
        let action = TradeActions.orderAction(
            asset: asset, isBuy: isBuy, price: price,
            size: position.absoluteSize, reduceOnly: true
        )
        return TradePlan(
            rows: [
                ("Market", position.coin),
                ("Action", "Close \(position.directionLabel) (\(isBuy ? "Buy" : "Sell"))"),
                ("Size", Format.number(position.absoluteSize, fractionDigits: 4)),
                ("Mark price", Format.price(markPrice)),
                ("Limit (IOC)", Format.price(price)),
                ("Unrealized PnL", Format.signedUSD(position.unrealizedPnlValue))
            ],
            warning: "Closes the full position as a market (IOC) order with up to \(Int(TradeActions.defaultSlippage * 100))% slippage.",
            action: action
        )
    }

    private func cancelOrderPlan(_ order: OpenOrder) async throws -> TradePlan {
        let assetId = try await session.meta.orderAssetId(coin: order.coin)
        let action = TradeActions.cancelAction(assetId: assetId, oid: order.oid)
        return TradePlan(
            rows: [
                ("Market", order.coin),
                ("Side", order.sideLabel),
                ("Size", Format.number(order.size, fractionDigits: 4)),
                ("Limit price", Format.price(order.limitPrice)),
                ("Order ID", String(order.oid))
            ],
            warning: nil,
            action: action
        )
    }

    private func sellSpotPlan(_ balance: SpotBalance) async throws -> TradePlan {
        let asset = try await session.meta.spotAssetToUSDC(coin: balance.coin)
        let markPrice = try await mark(for: asset.midKey)
        let size = balance.availableValue
        guard size > 0 else { throw HyperliquidError.exchange("No available \(balance.coin) to sell.") }
        let price = TradeActions.aggressivePrice(mark: markPrice, isBuy: false)
        let action = TradeActions.orderAction(
            asset: asset, isBuy: false, price: price, size: size, reduceOnly: false
        )
        return TradePlan(
            rows: [
                ("Market", "\(balance.coin)/USDC"),
                ("Action", "Sell"),
                ("Size", Format.number(size, fractionDigits: 4)),
                ("Mark price", Format.price(markPrice)),
                ("Limit (IOC)", Format.price(price)),
                ("Est. proceeds", Format.usd(size * markPrice))
            ],
            warning: "Sells your available \(balance.coin) at market (IOC) with up to \(Int(TradeActions.defaultSlippage * 100))% slippage.",
            action: action
        )
    }

    private static func receiptMessage(_ response: ExchangeResponse) -> String {
        for status in response.statuses {
            switch status {
            case .filled(_, let sz, let px):
                return "Filled \(sz) @ \(Format.price(px.hlDouble))."
            case .resting(let oid):
                return "Order resting (id \(oid))."
            case .success:
                return "Done."
            case .other(let s):
                return s
            case .error(let e):
                return e
            }
        }
        return "Submitted."
    }
}
