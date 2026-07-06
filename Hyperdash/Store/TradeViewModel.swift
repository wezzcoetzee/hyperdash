import Foundation
import Combine

@MainActor
final class TradeViewModel: ObservableObject {
    enum Stage: Equatable {
        case preparing
        case ready
        case submitting
        case success(String)
        case failed(String)
    }

    @Published private(set) var stage: Stage = .preparing
    @Published private(set) var plan: TradePlan?

    let wallet: Wallet
    let context: TradeContext
    private let desk: TradeDesk

    init(wallet: Wallet, context: TradeContext, desk: TradeDesk) {
        self.wallet = wallet
        self.context = context
        self.desk = desk
    }

    func prepare() async {
        stage = .preparing
        do {
            plan = try await desk.prepare(context)
            stage = .ready
        } catch {
            stage = .failed(error.userMessage)
        }
    }

    func execute() async {
        guard let plan else { return }
        stage = .submitting
        do {
            let receipt = try await desk.execute(plan, reason: context.title)
            stage = .success(receipt.message)
        } catch {
            stage = .failed(error.userMessage)
        }
    }
}
