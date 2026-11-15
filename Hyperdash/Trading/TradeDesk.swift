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
        case .closePosition(let position, let fraction):
            return try await closePositionPlan(position, fraction: fraction)
        case .cancelOrder(let order):
            return try await cancelOrderPlan(order)
        case .sellSpot(let balance):
            return try await sellSpotPlan(balance)
        case .closeAll(let positions, let orders):
            return try await closeAllPlan(positions: positions, orders: orders)
        case .openPosition(let ticket):
            return try await openPositionPlan(ticket)
        case .setProtection(let position, let takeProfit, let stopLoss, let replacing):
            return try await protectionPlan(position, takeProfit: takeProfit, stopLoss: stopLoss, replacing: replacing)
        }
    }

    func execute(_ plan: TradePlan, reason: String) async throws -> TradeReceipt {
        let key = try await vault.signingKey(for: wallet, reason: reason)
        let exchange = try session.exchange(agentKeyHex: key)
        var messages: [String] = []
        for action in plan.actions {
            let response = try await exchange.submit(action: action)
            messages += Self.receiptMessages(response)
        }
        return TradeReceipt(message: messages.isEmpty ? "Submitted." : messages.joined(separator: "\n"))
    }

    private func mark(for key: String) async throws -> Double {
        let mids = try await session.info.allMids()
        guard let mark = mids[key], mark > 0 else {
            throw HyperliquidError.exchange("No current price for \(key).")
        }
        return mark
    }

    private func closePositionPlan(_ position: Position, fraction: Double) async throws -> TradePlan {
        let asset = try await session.meta.perpAsset(coin: position.coin)
        let markPrice = try await mark(for: asset.midKey)
        let isBuy = !position.isLong
        let price = TradeActions.aggressivePrice(mark: markPrice, isBuy: isBuy)
        let isPartial = fraction < 1
        let size = isPartial ? position.absoluteSize * fraction : position.absoluteSize
        let action = TradeActions.orderAction(
            asset: asset, isBuy: isBuy, price: price, size: size, reduceOnly: true
        )
        let sizeText = Format.number(size, fractionDigits: 4)
        return TradePlan(
            rows: [
                ("Market", position.coin),
                ("Action", "Close \(position.directionLabel) (\(isBuy ? "Buy" : "Sell"))"),
                ("Size", isPartial ? "\(sizeText) of \(Format.number(position.absoluteSize, fractionDigits: 4))" : sizeText),
                ("Mark price", Format.price(markPrice)),
                ("Limit (IOC)", Format.price(price)),
                (isPartial ? "Est. realised" : "Unrealized PnL", Format.signedUSD(position.unrealizedPnlValue * fraction))
            ],
            warning: "Closes \(isPartial ? Format.percent(fraction * 100, fractionDigits: 0) + " of" : "the full") position as a market (IOC) order with up to \(Self.slippagePct)% slippage.",
            action: action
        )
    }

    /// Sets leverage, then sends the entry with any TP/SL attached as
    /// `normalTpsl` children: reduce-only market triggers on the opposite side,
    /// sized to the entry, that arm once it fills.
    private func openPositionPlan(_ ticket: OrderTicket) async throws -> TradePlan {
        let asset = try await session.meta.perpAsset(coin: ticket.coin)
        let markPrice = try await mark(for: asset.midKey)
        if let problem = ticket.problem(available: .infinity, maxLeverage: asset.maxLeverage) {
            throw HyperliquidError.exchange(problem)
        }
        let isBuy = ticket.isLong
        let size = ticket.size(mark: markPrice)

        let entry: MsgPackValue
        let priceRow: (String, String)
        switch ticket.kind {
        case .market:
            let price = TradeActions.aggressivePrice(mark: markPrice, isBuy: isBuy)
            entry = TradeActions.orderEntry(asset: asset, isBuy: isBuy, price: price, size: size, reduceOnly: false)
            priceRow = ("Limit (IOC)", Format.price(price))
        case .limit(let price):
            entry = TradeActions.orderEntry(asset: asset, isBuy: isBuy, price: price, size: size,
                                            reduceOnly: false, kind: .gtc)
            priceRow = ("Limit (GTC)", Format.price(price))
        }

        let triggers = [
            ticket.takeProfitPrice(mark: markPrice).map { (price: $0, isTakeProfit: true) },
            ticket.stopLossPrice(mark: markPrice).map { (price: $0, isTakeProfit: false) }
        ].compactMap { $0 }
        let children = triggers.map {
            triggerEntry(asset: asset, closingLong: isBuy, triggerPrice: $0.price, isTakeProfit: $0.isTakeProfit, size: size)
        }

        var rows: [(String, String)] = [
            ("Market", ticket.coin),
            ("Side", isBuy ? "Long (Buy)" : "Short (Sell)"),
            ("Size", "\(Format.number(size, fractionDigits: min(asset.szDecimals, 4))) \(ticket.coin)"),
            ("Notional", Format.usd(ticket.notional)),
            ("Leverage", "\(ticket.leverage)x \(ticket.isCross ? "cross" : "isolated")"),
            ("Margin", Format.usd(ticket.margin)),
            ("Mark price", Format.price(markPrice)),
            priceRow
        ]
        for trigger in triggers {
            rows.append((trigger.isTakeProfit ? "Take profit" : "Stop loss", Format.price(trigger.price)))
        }

        return TradePlan(
            rows: rows,
            warning: ticket.kind == .market
                ? "Opens at market (IOC) with up to \(Self.slippagePct)% slippage."
                : nil,
            actions: [
                TradeActions.updateLeverageAction(assetId: asset.assetId, isCross: ticket.isCross, leverage: ticket.leverage),
                TradeActions.ordersAction([entry] + children, grouping: children.isEmpty ? .na : .normalTpsl)
            ]
        )
    }

    /// Places the new position triggers before cancelling the old ones, so the
    /// position is never left unguarded if the second step fails.
    private func protectionPlan(_ position: Position, takeProfit: Double?, stopLoss: Double?,
                                replacing: [OpenOrder]) async throws -> TradePlan {
        guard takeProfit != nil || stopLoss != nil || !replacing.isEmpty else {
            throw HyperliquidError.exchange("No TP/SL to set or remove.")
        }
        let asset = try await session.meta.perpAsset(coin: position.coin)
        let levels = [takeProfit.map { (price: $0, isTakeProfit: true) },
                      stopLoss.map { (price: $0, isTakeProfit: false) }].compactMap { $0 }

        var actions: [MsgPackValue] = []
        if !levels.isEmpty {
            actions.append(TradeActions.ordersAction(levels.map {
                triggerEntry(asset: asset, closingLong: position.isLong, triggerPrice: $0.price,
                             isTakeProfit: $0.isTakeProfit, size: position.absoluteSize)
            }, grouping: .positionTpsl))
        }
        if !replacing.isEmpty {
            actions.append(TradeActions.cancelsAction(replacing.map { (assetId: asset.assetId, oid: $0.oid) }))
        }

        func describe(_ price: Double?) -> String {
            guard let price, let entry = position.entryPrice else { return "None" }
            let pnl = Protection.pnl(at: price, entry: entry, signedSize: position.size)
            return "\(Format.price(price))  \(Format.signedUSD(pnl))"
        }
        var rows: [(String, String)] = [
            ("Market", position.coin),
            ("Position", "\(position.directionLabel) \(Format.number(position.absoluteSize, fractionDigits: 4))"),
            ("Take profit", describe(takeProfit)),
            ("Stop loss", describe(stopLoss))
        ]
        if !replacing.isEmpty { rows.append(("Replaces", "\(replacing.count) trigger order\(replacing.count == 1 ? "" : "s")")) }

        return TradePlan(
            rows: rows,
            warning: levels.isEmpty ? nil
                : "Triggers close at market with up to \(Self.slippagePct)% slippage, and resize with the position.",
            actions: actions
        )
    }

    /// A reduce-only market trigger that closes a position of the given side.
    /// Its limit sits through the book from the trigger, like every market order.
    private func triggerEntry(asset: AssetInfo, closingLong: Bool, triggerPrice: Double,
                              isTakeProfit: Bool, size: Double) -> MsgPackValue {
        let isBuy = !closingLong
        return TradeActions.orderEntry(
            asset: asset, isBuy: isBuy,
            price: TradeActions.aggressivePrice(mark: triggerPrice, isBuy: isBuy),
            size: size, reduceOnly: true,
            kind: .trigger(triggerPrice: triggerPrice, isTakeProfit: isTakeProfit)
        )
    }

    private static var slippagePct: Int { Int(TradeActions.defaultSlippage * 100) }

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
            warning: "Markets out every open position (IOC, up to \(Self.slippagePct)% slippage) and cancels every resting order.",
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
            warning: "Sells your available \(balance.coin) at market (IOC) with up to \(Self.slippagePct)% slippage.",
            action: action
        )
    }

    /// One line per distinct order status. Leverage actions carry none.
    private static func receiptMessages(_ response: ExchangeResponse) -> [String] {
        var lines: [String] = []
        for status in response.statuses {
            let line = switch status {
            case .filled(_, let sz, let px): "Filled \(sz) @ \(Format.price(px.hlDouble))."
            case .resting(let oid): "Order resting (id \(oid))."
            case .success: "Done."
            case .other("waitingForTrigger"), .other("waitingForFill"): "Trigger set."
            case .other(let s): s
            case .error(let e): e
            }
            if !lines.contains(line) { lines.append(line) }
        }
        return lines
    }
}
