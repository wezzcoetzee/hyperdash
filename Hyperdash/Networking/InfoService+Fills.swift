import Foundation

extension InfoService {
    static let fillsPageSize = 2000

    /// Fills between `startMs` and `endMs` (inclusive), aggregated by time. The
    /// API returns at most `fillsPageSize` fills, oldest first, so a full page
    /// means there may be more. The next page restarts at the last fill's own
    /// millisecond, not after it, so fills sharing that millisecond aren't lost;
    /// `tid` dedupes the overlap, and a page with nothing new ends the walk.
    func fills(address: String, startMs: Int, endMs: Int) async throws -> [Fill] {
        var fills: [Fill] = []
        var seen = Set<Int>()
        var cursor = startMs
        while true {
            let page = try await client.info(
                ["type": "userFillsByTime", "user": address, "startTime": cursor,
                 "endTime": endMs, "aggregateByTime": true],
                as: [Fill].self
            )
            let fresh = page.filter { seen.insert($0.tid).inserted }
            fills += fresh
            guard page.count >= Self.fillsPageSize, !fresh.isEmpty, let last = page.last else { return fills }
            cursor = last.timeMs
        }
    }
}
