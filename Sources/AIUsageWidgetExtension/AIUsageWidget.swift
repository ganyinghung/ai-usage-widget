import SwiftUI
import WidgetKit

private let widgetKind = "AIUsageWidget"
private let unusedUsageColor = Color(red: 0.20, green: 0.50, blue: 0.96)
private let usedUsageColor = Color(red: 0.93, green: 0.20, blue: 0.24)

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        if context.isPreview {
            completion(UsageEntry(date: .now, snapshot: .placeholder))
        } else {
            completion(UsageEntry(date: .now, snapshot: loadSnapshot()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let now = Date()
        let entry = UsageEntry(date: now, snapshot: loadSnapshot())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
    }

    private func loadSnapshot() -> UsageSnapshot {
        SnapshotStore.appGroup()?.load() ?? .empty
    }
}

struct AIUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageEntry

    var body: some View {
        Group {
            if entry.snapshot.providers.isEmpty {
                emptyView
            } else if family == .systemSmall {
                compactView
            } else {
                mediumView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "aiusagewidget://status"))
    }

    private var compactView: some View {
        VStack(alignment: .leading, spacing: 7) {
            header

            ForEach(entry.snapshot.providers.prefix(2)) { provider in
                CompactProviderView(provider: provider)
            }

            Spacer(minLength: 0)
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            HStack(alignment: .top, spacing: 10) {
                ForEach(entry.snapshot.providers.prefix(2)) { provider in
                    MediumProviderView(provider: provider)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .foregroundStyle(.secondary)
            Text("AI Usage")
                .font(.system(.caption, design: .rounded, weight: .bold))
            Spacer()
            Text(entry.snapshot.generatedAt, style: .relative)
                .font(.system(size: 8.5, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("AI Usage")
                .font(.headline)
            Text("Open the AI Usage app once to refresh Claude and Codex.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct CompactProviderView: View {
    let provider: ProviderUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            providerHeader

            if provider.windows.isEmpty {
                Text("Unavailable")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(provider.windows.prefix(2)) { window in
                        MiniWindowView(window: window)
                    }
                }
            }
        }
    }

    private var providerHeader: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
            Text(provider.name)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            if provider.isStale {
                Text("STALE")
                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var accent: Color { providerAccent(provider.id) }
}

private struct MediumProviderView: View {
    let provider: ProviderUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                Text(provider.name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                if provider.isStale {
                    Text("STALE")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }

            if provider.windows.isEmpty {
                Text(provider.statusMessage ?? "Usage unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                ForEach(provider.windows.prefix(2)) { window in
                    MediumWindowView(window: window)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var accent: Color { providerAccent(provider.id) }
}

private struct MiniWindowView: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(shortLabel)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                Spacer(minLength: 1)
                Text("\(Int(window.usedPercent.rounded()))%")
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(usedUsageColor)
            }
            UsageBar(usedPercent: window.usedPercent)
            if let reset = window.resetsAt {
                Text(resetLabel(for: reset))
                    .font(.system(size: 7.5, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var shortLabel: String {
        window.label == "Weekly" ? "Week" : window.label
    }
}

private struct MediumWindowView: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                Spacer()
                Text("\(Int(window.usedPercent.rounded()))% used")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(usedUsageColor)
            }
            UsageBar(usedPercent: window.usedPercent)
            if let reset = window.resetsAt {
                Text("Resets \(resetLabel(for: reset))")
                    .font(.system(size: 8.5, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}

private struct UsageBar: View {
    let usedPercent: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(unusedUsageColor)
            Capsule()
                .fill(usedUsageColor)
                .scaleEffect(x: min(max(usedPercent / 100, 0), 1), anchor: .leading)
        }
        .frame(height: 4)
    }
}

private func providerAccent(_ id: String) -> Color {
    id == "claude"
        ? Color(red: 0.93, green: 0.49, blue: 0.30)
        : Color(red: 0.25, green: 0.79, blue: 0.62)
}

private func resetLabel(for date: Date) -> String {
    let time = date.formatted(date: .omitted, time: .shortened)
    let interval = date.timeIntervalSinceNow
    if interval >= 0, interval <= 24 * 60 * 60 {
        return time
    }

    let calendar = Calendar.autoupdatingCurrent
    let day: String
    if calendar.isDateInToday(date) {
        day = "Today"
    } else if calendar.isDateInTomorrow(date) {
        day = "Tomorrow"
    } else if let daysAway = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: Date()),
        to: calendar.startOfDay(for: date)
    ).day, (2...6).contains(daysAway) {
        day = date.formatted(.dateTime.weekday(.wide))
    } else {
        day = date.formatted(.dateTime.month(.abbreviated).day())
    }

    return "\(day) \(time)"
}

struct AIUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: UsageTimelineProvider()) { entry in
            AIUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("AI Usage")
        .description("Claude and OpenAI Codex usage and reset times.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AIUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        AIUsageWidget()
    }
}

private extension UsageSnapshot {
    static var placeholder: UsageSnapshot {
        UsageSnapshot(
            providers: [
                ProviderUsage(
                    id: "claude",
                    name: "Claude",
                    windows: [
                        UsageWindow(id: "5h", label: "5 hr", usedPercent: 32, resetsAt: .now.addingTimeInterval(90 * 60)),
                        UsageWindow(id: "week", label: "Weekly", usedPercent: 48, resetsAt: .now.addingTimeInterval(3 * 86_400)),
                    ],
                    source: "Claude live"
                ),
                ProviderUsage(
                    id: "codex",
                    name: "Codex",
                    windows: [
                        UsageWindow(id: "5h", label: "5 hr", usedPercent: 18, resetsAt: .now.addingTimeInterval(3 * 60 * 60)),
                        UsageWindow(id: "week", label: "Weekly", usedPercent: 61, resetsAt: .now.addingTimeInterval(5 * 86_400)),
                    ],
                    source: "Codex live"
                ),
            ]
        )
    }
}
