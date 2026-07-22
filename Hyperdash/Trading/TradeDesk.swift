import Foundation

/// What the trade confirmation sheet renders and what execute submits.
/// The action is opaque to callers — only the desk reads it back.
struct TradePlan {
    let rows: [(String, String)]
    let warning: String?
    /// One or more signed submissions. Closing everything needs two: a batched
    /// reduce-only order action and a batched cancel action.
    let actions: [MsgPackValue]

    init(rows: [(String, String)], warning: String?, actions: [MsgPackValue]) {
        self.rows = rows
        self.warning = warning
        self.actions = actions
    }

    init(rows: [(String, String)], warning: String?, action: MsgPackValue) {
        self.init(rows: rows, warning: warning, actions: [action])
    }

    /// The primary action — the only one for single-step plans.
    var action: MsgPackValue { actions[0] }
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
        case .closeAll(let positions, let orders):
            return try await closeAllPlan(positions: positions, orders: orders)
        }
    }

    func execute(_ plan: TradePlan, reason: String) async throws -> TradeReceipt {
        let key = try await vault.signingKey(for: wallet, reason: reason)
        let exchange = try session.exchange(agentKeyHex: key)
        var messages: [String] = []
        for action in plan.actions {
            let response = try await exchange.submit(action: action)
            messages.append(Self.receiptMessage(response))
        }
        return TradeReceipt(message: messages.joined(separator: "\n"))
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

    /// Flattens the account in up to two signed submissions: one batched
    /// reduce-only order that markets out every open position, and one batched
    /// cancel that pulls every resting order.
    private func closeAllPlan(positions: [Position], orders: [OpenOrder]) async throws -> TradePlan {
        guard !positions.isEmpty || !orders.isEmpty else {
            throw HyperliquidError.exchange("Nothing open to close.")
        }

        var actions: [MsgPackValue] = []

        if !positions.isEmpty {
            let mids = try await session.info.allMids()
            var entries: [MsgPackValue] = []
            for position in positions {
                let asset = try await session.meta.perpAsset(coin: position.coin)
                guard let markPrice = mids[asset.midKey], markPrice > 0 else {
                    throw HyperliquidError.exchange("No current price for \(position.coin).")
                }
                let isBuy = !position.isLong
                let price = TradeActions.aggressivePrice(mark: markPrice, isBuy: isBuy)
                entries.append(TradeActions.orderEntry(
                    asset: asset, isBuy: isBuy, price: price,
                    size: position.absoluteSize, reduceOnly: true
                ))
            }
            actions.append(TradeActions.ordersAction(entries))
        }

        if !orders.isEmpty {
            var cancels: [(assetId: Int, oid: Int)] = []
            for order in orders {
                let assetId = try await session.meta.orderAssetId(coin: order.coin)
                cancels.append((assetId: assetId, oid: order.oid))
            }
            actions.append(TradeActions.cancelsAction(cancels))
        }

        let totalPnl = positions.reduce(0.0) { $0 + $1.unrealizedPnlValue }
        return TradePlan(
            rows: [
                ("Positions to close", String(positions.count)),
                ("Orders to cancel", String(orders.count)),
                ("Unrealized PnL", Format.signedUSD(totalPnl))
            ],
            warning: "Markets out every open position (IOC, up to \(Int(TradeActions.defaultSlippage * 100))% slippage) and cancels every resting order.",
            actions: actions
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
