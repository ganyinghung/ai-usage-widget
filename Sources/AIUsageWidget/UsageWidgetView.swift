#if SWIFT_PACKAGE
import AIUsageCore
#endif
import SwiftUI

private let unusedUsageColor = Color(red: 0.20, green: 0.50, blue: 0.96)
private let usedUsageColor = Color(red: 0.93, green: 0.20, blue: 0.24)

struct UsageWidgetView: View {
    @ObservedObject var model: UsageViewModel
    let refresh: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

            VStack(spacing: 12) {
                ForEach(model.snapshot.providers) { provider in
                    ProviderRow(provider: provider)
                }

                if model.snapshot.providers.isEmpty {
                    ProgressView("Reading usage…")
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)

            footer
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
        }
        .frame(width: 390)
        .padding(15)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI USAGE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(.secondary)
                Text("Capacity at a glance")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            Spacer()
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .rotationEffect(model.isRefreshing ? .degrees(360) : .zero)
                    .animation(
                        model.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: model.isRefreshing
                    )
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.isRefreshing)
            .help("Refresh usage")

            Button(action: quit) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Quit background updates")
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.isRefreshing ? Color.orange : Color.green)
                .frame(width: 6, height: 6)
            Text(model.isRefreshing ? "Refreshing" : updatedText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text("updates every 5 min")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }

    private var updatedText: String {
        guard !model.snapshot.providers.isEmpty else { return "Waiting for data" }
        return "Updated " + model.snapshot.generatedAt.formatted(.relative(presentation: .named))
    }
}

private struct ProviderRow: View {
    let provider: ProviderUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(accent.opacity(0.18))
                    Text(provider.id == "claude" ? "C" : "⌁")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(provider.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        if provider.isStale {
                            Text("STALE")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(provider.source)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            if provider.windows.isEmpty {
                Text(provider.statusMessage ?? "Usage unavailable")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 18) {
                    ForEach(provider.windows.prefix(2)) { window in
                        UsageMeter(window: window)
                    }
                }
                if let message = provider.statusMessage {
                    Text(message)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.9))
                        .lineLimit(1)
                }
            }
        }
        .padding(13)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var accent: Color {
        provider.id == "claude" ? Color(red: 0.93, green: 0.49, blue: 0.30) : Color(red: 0.25, green: 0.79, blue: 0.62)
    }
}

private struct UsageMeter: View {
    let window: UsageWindow

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(unusedUsageColor, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: window.usedPercent / 100)
                    .stroke(usedUsageColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(window.usedPercent.rounded()))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(usedUsageColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text("\(Int(window.remainingPercent.rounded()))% left")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(unusedUsageColor)
                if let reset = window.resetsAt {
                    Text(resetLabel(for: reset))
                        .font(.system(size: 8.5, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resetLabel(for date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let interval = date.timeIntervalSinceNow
        if interval >= 0, interval <= 24 * 60 * 60 {
            return "Resets at \(time)"
        }

        let calendar = Calendar.autoupdatingCurrent
        let day: String

        if calendar.isDateInToday(date) {
            day = "today"
        } else if calendar.isDateInTomorrow(date) {
            day = "tomorrow"
        } else if let daysAway = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: date)
        ).day, (2...6).contains(daysAway) {
            day = date.formatted(.dateTime.weekday(.wide))
        } else {
            day = date.formatted(.dateTime.month(.abbreviated).day())
        }

        return "Resets \(day) at \(time)"
    }
}
