import Foundation
import Combine

@MainActor
final class WalletDetailViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var snapshot: WalletSnapshot?

    let wallet: Wallet

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    func load(session: HyperliquidSession) async {
        if snapshot == nil { state = .loading }
        do {
            let snap = try await session.info.snapshot(address: wallet.address)
            snapshot = snap
            state = .loaded
        } catch {
            state = .failed(error.userMessage)
        }
    }
}
