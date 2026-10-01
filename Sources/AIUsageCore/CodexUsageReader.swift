import Foundation

public struct CodexUsageReader {
    private let fileManager: FileManager
    private let homeDirectory: URL

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    public func fetch() throws -> ProviderUsage {
        let codex = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        let roots = [
            codex.appendingPathComponent("sessions", isDirectory: true),
            codex.appendingPathComponent("archived_sessions", isDirectory: true),
        ]

        let files = roots
            .flatMap(jsonlFiles(in:))
            .sorted { modificationDate(of: $0) > modificationDate(of: $1) }

        for file in files.prefix(80) {
            if let limits = try latestRateLimits(in: file) {
                var windows: [UsageWindow] = []
                if let primary = limits["primary"] as? [String: Any],
                   let window = makeWindow(primary, fallbackID: "primary") {
                    windows.append(window)
                }
                if let secondary = limits["secondary"] as? [String: Any],
                   let window = makeWindow(secondary, fallbackID: "secondary") {
                    windows.append(window)
                }
                guard !windows.isEmpty else { continue }

                let plan = limits["plan_type"] as? String
                let source = plan.map { "Codex logs · \($0.capitalized)" } ?? "Codex logs"
                return ProviderUsage(
                    id: "codex",
                    name: "Codex",
                    windows: windows,
                    source: source
                )
            }
        }
        throw UsageError.noCodexData
    }

    public func parseRateLimits(from data: Data) throws -> [String: Any]? {
        let text = String(decoding: data, as: UTF8.self)
        for line in text.split(separator: "\n").reversed() {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let payload = json["payload"] as? [String: Any],
                  let limits = payload["rate_limits"] as? [String: Any]
            else { continue }

            if let identifier = limits["limit_id"] as? String, identifier != "codex" {
                continue
            }
            return limits
        }
        return nil
    }

    private func jsonlFiles(in directory: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            result.append(url)
        }
        return result
    }

    private func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func latestRateLimits(in url: URL) throws -> [String: Any]? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let size = try handle.seekToEnd()
        let bytesToRead = min(size, 4 * 1_024 * 1_024)
        try handle.seek(toOffset: size - bytesToRead)
        return try parseRateLimits(from: handle.readDataToEndOfFile())
    }

    private func makeWindow(_ value: [String: Any], fallbackID: String) -> UsageWindow? {
        guard let used = number(value["used_percent"]) else { return nil }
        let minutes = number(value["window_minutes"]).map(Int.init) ?? 0
        let label: String
        switch minutes {
        case 300: label = "5 hr"
        case 10_080: label = "Weekly"
        case 43_200, 44_640: label = "Monthly"
        default: label = minutes > 0 ? durationLabel(minutes: minutes) : fallbackID.capitalized
        }

        let resetDate = number(value["resets_at"]).map { Date(timeIntervalSince1970: $0) }
        return UsageWindow(
            id: "codex-\(minutes == 0 ? fallbackID : String(minutes))",
            label: label,
            usedPercent: used,
            resetsAt: resetDate
        )
    }

    private func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private func durationLabel(minutes: Int) -> String {
        if minutes.isMultiple(of: 10_080) { return "\(minutes / 10_080) wk" }
        if minutes.isMultiple(of: 1_440) { return "\(minutes / 1_440) day" }
        if minutes.isMultiple(of: 60) { return "\(minutes / 60) hr" }
        return "\(minutes) min"
    }
}
