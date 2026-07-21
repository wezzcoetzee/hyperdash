import Foundation

struct AgentKeyExpiry: Equatable {
    let validUntil: Date
    let source: Source

    enum Source: Equatable { case onChain, estimated }
    enum Status: Equatable { case healthy, warning, expired }

    static let warningWindow: TimeInterval = 7 * 24 * 3600
    static let agentKeyLifetime: TimeInterval = 180 * 24 * 3600

    func daysRemaining(now: Date = Date()) -> Int {
        let secs = validUntil.timeIntervalSince(now)
        return Int((secs / 86_400).rounded(.down))
    }

    func status(now: Date = Date()) -> Status {
        let remaining = validUntil.timeIntervalSince(now)
        if remaining <= 0 { return .expired }
        if remaining <= Self.warningWindow { return .warning }
        return .healthy
    }
}

enum AgentKeyExpiryResolver {
    static func resolve(agentAddress: String?,
                        agents: [ExtraAgent],
                        keyAddedAt: Date?) -> AgentKeyExpiry? {
        if let addr = agentAddress?.lowercased(),
           let match = agents.first(where: { $0.address.lowercased() == addr }) {
            return AgentKeyExpiry(validUntil: match.validUntil, source: .onChain)
        }
        if let added = keyAddedAt {
            return AgentKeyExpiry(validUntil: added.addingTimeInterval(AgentKeyExpiry.agentKeyLifetime),
                                  source: .estimated)
        }
        return nil
    }
}
