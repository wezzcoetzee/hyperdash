import SwiftUI

struct AgentKeyBadge: View {
    let expiry: AgentKeyExpiry
    var compact: Bool = false

    private var status: AgentKeyExpiry.Status { expiry.status() }

    private var fill: Color {
        switch status {
        case .healthy: return .gain
        case .warning: return .caution
        case .expired: return .loss
        }
    }

    private var text: Color {
        switch status {
        case .healthy: return .gainText
        case .warning: return .cautionText
        case .expired: return .lossText
        }
    }

    private var title: String {
        switch status {
        case .expired:
            return compact ? "EXPIRED" : "Key expired"
        default:
            let d = max(expiry.daysRemaining(), 0)
            return compact ? "\(d)d" : "Key: \(d)d left"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if !compact {
                Image(systemName: status == .expired ? "key.slash.fill" : "key.fill")
                    .font(.caption2)
            }
            Text(title).font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(fill.opacity(Theme.badgeFillOpacity))
        .foregroundStyle(text)
        .clipShape(Capsule())
    }
}
