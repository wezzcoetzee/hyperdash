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
    @Published private(set) var context: TradeContext
    /// True while a revised plan is being prepared. The previous plan stays on
    /// screen, but it no longer matches the inputs, so it can't be submitted.
    @Published private(set) var isRevising = false

    private let desk: TradeDesk

    init(context: TradeContext, desk: TradeDesk) {
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

    /// Re-prepares for an edited context (a new partial-close amount) without
    /// leaving the confirmation screen. A newer revision cancels this one.
    func revise(_ context: TradeContext) async {
        self.context = context
        isRevising = true
        do {
            let revised = try await desk.prepare(context)
            guard !Task.isCancelled else { return }
            plan = revised
            isRevising = false
        } catch {
            guard !Task.isCancelled else { return }
            isRevising = false
            stage = .failed(error.userMessage)
        }
    }

    func execute() async {
        guard let plan, !isRevising else { return }
        stage = .submitting
        do {
            let receipt = try await desk.execute(plan, reason: context.title)
            stage = .success(receipt.message)
        } catch {
            stage = .failed(error.userMessage)
        }
    }
}
