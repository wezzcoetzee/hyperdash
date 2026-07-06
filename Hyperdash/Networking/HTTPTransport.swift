import Foundation

/// Seam between the Hyperliquid client and the network. Production uses
/// `URLSessionTransport`; tests substitute an in-memory adapter with canned
/// responses.
protocol HTTPTransport: Sendable {
    func post(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    var session: URLSession = .shared

    func post(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HyperliquidError.invalidResponse
        }
        return (data, http)
    }
}
