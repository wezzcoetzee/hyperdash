import Foundation

/// Parsed `/exchange` response. Handles both the success envelope
/// (`{status:"ok", response:{data:{statuses:[…]}}}`) and the error envelope
/// (`{status:"err", response:"<message>"}`).
struct ExchangeResponse: Decodable {
    let status: String
    let errorMessage: String?
    let statuses: [ActionStatus]

    var isOK: Bool { status == "ok" }

    /// First per-order error, if any (an "ok" envelope can still contain
    /// individual rejected orders).
    var firstStatusError: String? {
        statuses.compactMap { if case .error(let m) = $0 { return m } else { return nil } }.first
    }

    private enum Top: String, CodingKey { case status, response }
    private enum Resp: String, CodingKey { case data }
    private enum DataKeys: String, CodingKey { case statuses }

    init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: Top.self)
        status = try top.decode(String.self, forKey: .status)

        if status != "ok" {
            errorMessage = (try? top.decode(String.self, forKey: .response)) ?? "Unknown error"
            statuses = []
            return
        }

        errorMessage = nil
        if let resp = try? top.nestedContainer(keyedBy: Resp.self, forKey: .response),
           let data = try? resp.nestedContainer(keyedBy: DataKeys.self, forKey: .data),
           let parsed = try? data.decode([ActionStatus].self, forKey: .statuses) {
            statuses = parsed
        } else {
            statuses = []
        }
    }
}

enum ActionStatus: Decodable {
    case success
    case resting(oid: Int)
    case filled(oid: Int, totalSz: String, avgPx: String)
    case error(String)
    case other(String)

    private enum Keys: String, CodingKey { case error, resting, filled }
    private enum Resting: String, CodingKey { case oid }
    private enum Filled: String, CodingKey { case oid, totalSz, avgPx }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let str = try? single.decode(String.self) {
            self = str == "success" ? .success : .other(str)
            return
        }
        let container = try decoder.container(keyedBy: Keys.self)
        if let message = try? container.decode(String.self, forKey: .error) {
            self = .error(message)
        } else if let resting = try? container.nestedContainer(keyedBy: Resting.self, forKey: .resting) {
            self = .resting(oid: (try? resting.decode(Int.self, forKey: .oid)) ?? 0)
        } else if let filled = try? container.nestedContainer(keyedBy: Filled.self, forKey: .filled) {
            self = .filled(
                oid: (try? filled.decode(Int.self, forKey: .oid)) ?? 0,
                totalSz: (try? filled.decode(String.self, forKey: .totalSz)) ?? "0",
                avgPx: (try? filled.decode(String.self, forKey: .avgPx)) ?? "0"
            )
        } else {
            self = .other("unrecognized status")
        }
    }
}
