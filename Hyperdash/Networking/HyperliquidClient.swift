import Foundation

enum HyperliquidError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String)
    case decoding(String)
    case exchange(String)
    case signingUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Hyperliquid."
        case .httpStatus(let code, let body):
            return "Request failed (HTTP \(code)). \(body)"
        case .decoding(let detail):
            return "Could not read response: \(detail)"
        case .exchange(let message):
            return message
        case .signingUnavailable(let detail):
            return "Signing unavailable: \(detail)"
        }
    }
}

extension Error {
    /// Message suitable for showing the user.
    var userMessage: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }
}

/// Speaks to the two Hyperliquid endpoints through the transport seam.
/// `/info` is public; `/exchange` carries signed actions.
struct HyperliquidClient {
    let network: HyperliquidNetwork
    var transport: HTTPTransport = URLSessionTransport()

    private func post(path: String, body: [String: Any]) async throws -> Data {
        let url = network.apiBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, http) = try await transport.post(request)
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw HyperliquidError.httpStatus(http.statusCode, text)
        }
        return data
    }

    func info<T: Decodable>(_ body: [String: Any], as type: T.Type) async throws -> T {
        let data = try await post(path: "info", body: body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HyperliquidError.decoding("\(error)")
        }
    }

    /// Posts a pre-signed action envelope to `/exchange`.
    func exchange(envelope: [String: Any]) async throws -> ExchangeResponse {
        let data = try await post(path: "exchange", body: envelope)
        do {
            return try JSONDecoder().decode(ExchangeResponse.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw HyperliquidError.decoding("\(error). Raw: \(raw)")
        }
    }
}
