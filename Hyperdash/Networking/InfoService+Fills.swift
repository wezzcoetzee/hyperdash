import Foundation

extension InfoService {
    static let fillsPageSize = 2000

    /// Fills between `startMs` and `endMs` (inclusive), aggregated by time. The
    /// API returns at most `fillsPageSize` fills, oldest first, so a full page
    /// means there may be more: keep going from just after the last fill.
    func fills(address: String, startMs: Int, endMs: Int) async throws -> [Fill] {
        var fills: [Fill] = []
        var cursor = startMs
        while true {
            let page = try await client.info(
                ["type": "userFillsByTime", "user": address, "startTime": cursor,
                 "endTime": endMs, "aggregateByTime": true],
                as: [Fill].self
            )
            fills += page
            guard page.count >= Self.fillsPageSize, let last = page.last, last.timeMs < endMs else { return fills }
            cursor = last.timeMs + 1
        }
    }
}
