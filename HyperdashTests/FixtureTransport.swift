import Foundation
@testable import Hyperdash

/// In-memory adapter for the transport seam. Answers `/info` requests by the
/// "type" field of their body and `/exchange` requests with one canned
/// response.
///
/// DEX-scoped requests are keyed "<type>:<dex>" and fall back to the bare type,
/// so a fixture set that ignores HIP-3 answers every DEX the same way.
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
                  let fixture = (parsed["dex"] as? String).flatMap({ infoFixtures["\(type):\($0)"] })
                      ?? infoFixtures[type] {
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

    static let portfolio = #"""
    [
      ["day",     {"accountValueHistory": [[1000, "100"], [2000, "110"]], "pnlHistory": [[1000, "0"], [2000, "10"]], "vlm": "0"}],
      ["week",    {"accountValueHistory": [[1000, "90"], [2000, "110"]],  "pnlHistory": [[1000, "-5"], [2000, "10"]], "vlm": "0"}],
      ["month",   {"accountValueHistory": [], "pnlHistory": [], "vlm": "0"}],
      ["allTime", {"accountValueHistory": [[1000, "50"]], "pnlHistory": [[1000, "0"]], "vlm": "0"}],
      ["perpDay", {"accountValueHistory": [], "pnlHistory": [], "vlm": "0"}]
    ]
    """#

    static let extraAgents = #"""
    [
      {"name": "hyperdash", "address": "0x00000000000000000000000000000000000000aa", "validUntil": 4102444800000},
      {"name": "other",     "address": "0x00000000000000000000000000000000000000bb", "validUntil": 1000000000000}
    ]
    """#

    /// The core perp dex is the leading null; "xyz" is a builder-deployed dex.
    static let perpDexs = #"""
    [
      null,
      {"name": "xyz", "fullName": "xyz equities", "deployer": "0xdead"}
    ]
    """#

    /// An AAPL long on the "xyz" dex, with its own margin summary.
    static let xyzPerps = #"""
    {
      "marginSummary": {"accountValue": "500", "totalNtlPos": "2000", "totalRawUsd": "0", "totalMarginUsed": "200"},
      "crossMarginSummary": {"accountValue": "500", "totalNtlPos": "2000", "totalRawUsd": "0", "totalMarginUsed": "200"},
      "crossMaintenanceMarginUsed": "50",
      "withdrawable": "300",
      "assetPositions": [
        {"type": "oneWay", "position": {
          "coin": "AAPL", "szi": "10", "entryPx": "190", "positionValue": "2000",
          "unrealizedPnl": "100", "returnOnEquity": "0.05", "liquidationPx": "150",
          "marginUsed": "200", "maxLeverage": 10,
          "leverage": {"type": "cross", "value": 4},
          "cumFunding": {"allTime": "0", "sinceOpen": "0", "sinceChange": "0"}
        }}
      ],
      "time": 0
    }
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
