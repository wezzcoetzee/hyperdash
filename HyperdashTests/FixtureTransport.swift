import Foundation
@testable import Hyperdash

/// In-memory adapter for the transport seam. Answers `/info` requests by the
/// "type" field of their body and `/exchange` requests with one canned
/// response.
struct FixtureTransport: HTTPTransport {
    var infoFixtures: [String: String]
    var exchangeFixture: String = #"{"status":"ok","response":{"type":"default"}}"#

    func post(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let json: String
        if request.url?.lastPathComponent == "exchange" {
            json = exchangeFixture
        } else if let body = request.httpBody,
                  let parsed = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let type = parsed["type"] as? String,
                  let fixture = infoFixtures[type] {
            json = fixture
        } else {
            json = "{}"
        }
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(json.utf8), http)
    }
}

enum Fixtures {
    static let flatPerps = #"""
    {
      "marginSummary": {"accountValue": "1000", "totalNtlPos": "0", "totalRawUsd": "0", "totalMarginUsed": "0"},
      "crossMarginSummary": {"accountValue": "1000", "totalNtlPos": "0", "totalRawUsd": "0", "totalMarginUsed": "0"},
      "crossMaintenanceMarginUsed": "0",
      "withdrawable": "1000",
      "assetPositions": [],
      "time": 0
    }
    """#

    static let spotWithPURR = #"""
    {"balances": [
      {"coin": "USDC", "token": 0, "total": "100", "hold": "0"},
      {"coin": "PURR", "token": 1, "total": "10", "hold": "0"}
    ]}
    """#

    static let spotMeta = #"""
    {
      "tokens": [
        {"name": "USDC", "szDecimals": 2, "index": 0},
        {"name": "PURR", "szDecimals": 0, "index": 1}
      ],
      "universe": [
        {"name": "PURR/USDC", "tokens": [1, 0], "index": 1}
      ]
    }
    """#

    static let perpMeta = #"""
    {"universe": [{"name": "ETH", "szDecimals": 4}]}
    """#

    static let longETHPosition = #"""
    {
      "coin": "ETH", "szi": "1.5", "entryPx": "1800", "positionValue": "3000",
      "unrealizedPnl": "300", "returnOnEquity": "0.5", "liquidationPx": "100",
      "marginUsed": "300", "maxLeverage": 50,
      "leverage": {"type": "cross", "value": 10},
      "cumFunding": {"allTime": "0", "sinceOpen": "0", "sinceChange": "0"}
    }
    """#
}
