import Foundation

/// Live core-DEX mids over Hyperliquid's WebSocket `allMids` subscription.
/// App-only: the widget extension polls and never compiles this.
///
/// The stream keeps just the newest update, so a slow consumer skips ahead
/// instead of queueing. It reconnects with backoff until cancelled.
enum MidsFeed {
    private static let pingInterval: Duration = .seconds(50)
    private static let maxBackoff: Duration = .seconds(30)

    static func stream(network: HyperliquidNetwork) -> AsyncStream<[String: Double]> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                var backoff: Duration = .seconds(1)
                while !Task.isCancelled {
                    let delivered = await connect(to: network.webSocketURL) { continuation.yield($0) }
                    if delivered { backoff = .seconds(1) }
                    try? await Task.sleep(for: backoff)
                    backoff = min(backoff * 2, maxBackoff)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Mids from one `allMids` message; nil for any other channel or shape
    /// (`pong`, `subscriptionResponse`, ...).
    static func decodeMids(_ message: Data) -> [String: Double]? {
        struct Channel: Decodable { let channel: String }
        struct AllMids: Decodable {
            struct Payload: Decodable { let mids: [String: String] }
            let data: Payload
        }
        let decoder = JSONDecoder()
        guard let channel = try? decoder.decode(Channel.self, from: message),
              channel.channel == "allMids",
              let allMids = try? decoder.decode(AllMids.self, from: message) else { return nil }
        return allMids.data.mids.mapValues { $0.hlDouble }
    }

    /// One connection's lifetime: subscribe, keep alive, deliver mids until the
    /// socket fails or the task is cancelled. Returns whether any mids arrived,
    /// so a connection that worked resets the reconnect backoff.
    private static func connect(
        to url: URL, onMids: ([String: Double]) -> Void
    ) async -> Bool {
        let socket = URLSession.shared.webSocketTask(with: url)
        socket.resume()
        defer { socket.cancel(with: .goingAway, reason: nil) }

        let ping = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: pingInterval)
                try? await socket.send(.string(#"{"method":"ping"}"#))
            }
        }
        defer { ping.cancel() }

        var delivered = false
        do {
            try await socket.send(.string(#"{"method":"subscribe","subscription":{"type":"allMids"}}"#))
            while !Task.isCancelled {
                let message = try await socket.receive()
                let payload: Data
                switch message {
                case .string(let text): payload = Data(text.utf8)
                case .data(let data): payload = data
                @unknown default: continue
                }
                if let mids = decodeMids(payload) {
                    delivered = true
                    onMids(mids)
                }
            }
        } catch {}
        return delivered
    }
}
