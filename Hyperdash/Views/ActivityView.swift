import SwiftUI

/// Wallet detail section: this month's net realised PnL, leading into `ActivityView`.
/// Owns the view model so the pushed screen reuses the month already fetched here.
struct ActivitySection: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var model: ActivityViewModel

    init(wallet: Wallet) {
        _model = StateObject(wrappedValue: ActivityViewModel(wallet: wallet))
    }

    var body: some View {
        Section("Activity") {
            switch model.state(for: model.currentMonthStart) {
            case .failed:
                HStack {
                    Text("Couldn't load activity")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Retry") { Task { await refresh(force: false) } }
                        .font(.footnote)
                }
            case .loading:
                row(net: nil).redacted(reason: .placeholder)
            case .loaded(let month):
                row(net: month.days.isEmpty ? nil : month.net)
            }
        }
        .task(id: settings.network) { await refresh(force: true) }
    }

    private func refresh(force: Bool) async {
        await model.load(model.currentMonthStart, session: settings.session, force: force)
    }

    private func row(net: Double?) -> some View {
        NavigationLink {
            ActivityView(model: model)
        } label: {
            LabeledContent("Realised this month") {
                if let net {
                    Text(Format.signedUSD(net))
                        .monospacedDigit()
                        .foregroundStyle(Color.directionText(isPositive: net >= 0))
                        .privacySensitive()
                } else {
                    Text("No fills").foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Calendar of daily net realised PnL for one month, with the selected day's fills below.
struct ActivityView: View {
    @ObservedObject var model: ActivityViewModel
    @EnvironmentObject private var settings: AppSettings

    private struct LoadKey: Equatable {
        let month: Date
        let network: HyperliquidNetwork
    }

    var body: some View {
        List {
            switch model.state {
            case .failed:
                Section {
                    HStack {
                        Text("Couldn't load activity")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Retry") { Task { await load(force: false) } }
                            .font(.footnote)
                    }
                }
            case .loading:
                content(ActivityMonth(fills: [], containing: model.month, calendar: model.calendar), isLoading: true)
                    .redacted(reason: .placeholder)
                    .accessibilityLabel("Loading activity")
            case .loaded(let month):
                content(month, isLoading: false)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Previous month", systemImage: "chevron.left") { model.step(by: -1) }
                Button("Next month", systemImage: "chevron.right") { model.step(by: 1) }
                    .disabled(model.isCurrentMonth)
            }
        }
        .refreshable { await load(force: true) }
        .task(id: LoadKey(month: model.month, network: settings.network)) { await load(force: false) }
    }

    private func load(force: Bool) async {
        await model.load(model.month, session: settings.session, force: force)
    }

    private var title: String {
        let sameYear = model.calendar.isDate(model.month, equalTo: Date(), toGranularity: .year)
        return Self.formatted(model.month, sameYear ? "LLLL" : "LLLL yyyy", model.calendar)
    }

    static func formatted(_ date: Date, _ format: String, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func content(_ month: ActivityMonth, isLoading: Bool) -> some View {
        let hidden = settings.privacyMode
        Section {
            VStack(alignment: .leading, spacing: 2) {
                Text(isLoading ? "+$0,000.00" : Format.signedUSD(month.net))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(hidden ? Color.primary : Color.directionText(isPositive: month.net >= 0))
                    .privacySensitive()
                Text("realised \(model.isCurrentMonth ? "this month" : "in \(Self.formatted(month.start, "LLLL", month.calendar))") · fees \(Format.usd(month.fees))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .privacySensitive()
            }
            .accessibilityElement(children: .combine)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
        }

        Section {
            CalendarGrid(month: month, selectedDay: $model.selectedDay, hideTint: hidden || isLoading)
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        }

        if let day = model.selectedDay, !isLoading {
            daySection(day, in: month)
        }
    }

    private func daySection(_ day: Date, in month: ActivityMonth) -> some View {
        let pnl = month.pnl(on: day)
        return Section {
            if let pnl {
                ForEach(Array(pnl.fills.enumerated()), id: \.offset) { _, fill in
                    FillRow(fill: fill)
                }
            } else {
                Text("No fills")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack(spacing: 4) {
                Text(Self.formatted(day, "EEE d MMM", month.calendar))
                if let pnl {
                    Text("·")
                    Text(Format.signedUSD(pnl.net))
                        .monospacedDigit()
                        .privacySensitive()
                }
            }
            .textCase(nil)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
        }
    }
}

private struct CalendarGrid: View {
    let month: ActivityMonth
    @Binding var selectedDay: Date?
    let hideTint: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdays.indices, id: \.self) { index in
                    Text(weekdays[index])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<month.leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 44).accessibilityHidden(true)
                }
                ForEach(month.monthDays, id: \.self) { day in
                    DayCell(day: day, month: month, isSelected: selectedDay == day, hideTint: hideTint)
                        .onTapGesture { selectedDay = day }
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: Date
    let month: ActivityMonth
    let isSelected: Bool
    let hideTint: Bool

    private var pnl: DailyPnL? { month.pnl(on: day) }

    private var fill: Color {
        guard let pnl else { return .clear }
        guard !hideTint, let opacity = month.tintOpacity(for: pnl.net) else {
            return Color(.tertiarySystemFill)
        }
        return Color.direction(isPositive: pnl.net > 0).opacity(opacity)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(fill)
            .frame(height: 44)
            .overlay(alignment: .topLeading) {
                Text("\(month.calendar.component(.day, from: day))")
                    .font(.caption2)
                    .monospacedDigit()
                    .padding(4)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var label: String {
        let date = ActivityView.formatted(day, "d MMMM", month.calendar)
        guard let pnl else { return "\(date), no fills" }
        let fills = pnl.fills.count == 1 ? "1 fill" : "\(pnl.fills.count) fills"
        if hideTint { return "\(date), \(fills)" }
        return "\(date), \(Self.spoken(pnl.net)), \(fills)"
    }

    private static func spoken(_ net: Double) -> String {
        if net == 0 { return "break even" }
        return "\(net > 0 ? "plus" : "minus") \(Format.usd(abs(net)))"
    }
}

private struct FillRow: View {
    let fill: Fill

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(fill.coin).font(.headline)
                    if !fill.dir.isEmpty { FillDirectionTag(dir: fill.dir, isBuy: fill.isBuy) }
                }
                Text("\(Format.number(fill.size, fractionDigits: 4)) @ \(Format.price(fill.price)) · \(time)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                if fill.realisesPnl {
                    Text(Format.signedUSD(fill.closedPnl))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.directionText(isPositive: fill.closedPnl >= 0))
                } else {
                    Text("–").font(.subheadline).foregroundStyle(.secondary)
                }
                Text("fee \(feeLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .privacySensitive()
        }
        .padding(.vertical, 2)
    }

    private var time: String {
        fill.time.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute())
    }

    private var feeLabel: String {
        if fill.feeIsUSDC { return Format.usd(fill.fee) }
        return "\(Format.number(fill.fee, fractionDigits: 4)) \(fill.feeToken ?? "")"
    }
}

/// `DirectionTag`'s styling for Hyperliquid's own direction label.
private struct FillDirectionTag: View {
    let dir: String
    let isBuy: Bool

    var body: some View {
        Text(dir)
            .textCase(.uppercase)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.direction(isPositive: isBuy).opacity(Theme.badgeFillOpacity))
            .foregroundStyle(Color.directionText(isPositive: isBuy))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
