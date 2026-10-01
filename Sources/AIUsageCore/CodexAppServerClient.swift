import Foundation

public struct CodexAppServerClient {
    private let executableURL: URL?
    private let timeout: TimeInterval
    private let homeDirectory: URL

    public init(
        executableURL: URL? = nil,
        timeout: TimeInterval = 12,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.executableURL = executableURL
        self.timeout = timeout
        self.homeDirectory = homeDirectory
    }

    public func fetch() throws -> ProviderUsage {
        guard let executable = executableURL ?? Self.findExecutable(homeDirectory: homeDirectory) else {
            throw UsageError.codexNotInstalled
        }

        let process = Process()
        let standardInput = Pipe()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let inbox = JSONLineInbox()
        let errors = TextCapture()

        process.executableURL = executable
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError

        var environment = ProcessInfo.processInfo.environment
        let executableDirectory = executable.deletingLastPathComponent().path
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = executableDirectory + ":" + existingPath
        process.environment = environment

        standardOutput.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { inbox.finish() } else { inbox.append(data) }
        }
        standardError.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { errors.append(data) }
        }

        defer {
            standardOutput.fileHandleForReading.readabilityHandler = nil
            standardError.fileHandleForReading.readabilityHandler = nil
            try? standardInput.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
        }

        do {
            try process.run()
        } catch {
            throw UsageError.codexAppServer("could not start: \(error.localizedDescription)")
        }

        let deadline = Date().addingTimeInterval(timeout)
        try send(
            [
                "method": "initialize",
                "id": 1,
                "params": [
                    "clientInfo": [
                        "name": "ai_usage_widget",
                        "title": "AI Usage Widget",
                        "version": "1.1.0",
                    ],
                ],
            ],
            to: standardInput.fileHandleForWriting
        )

        guard let initialize = inbox.wait(forID: 1, until: deadline) else {
            throw responseFailure(process: process, errors: errors)
        }
        try validate(initialize)

        try send(
            ["method": "initialized", "params": [:]],
            to: standardInput.fileHandleForWriting
        )
        try send(
            ["method": "account/rateLimits/read", "id": 2],
            to: standardInput.fileHandleForWriting
        )

        guard let response = inbox.wait(forID: 2, until: deadline) else {
            throw responseFailure(process: process, errors: errors)
        }
        try validate(response)
        return try parseRateLimitsResponse(response)
    }

    public func parseRateLimitsResponse(_ data: Data) throws -> ProviderUsage {
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.invalidResponse("Codex App Server")
        }
        return try parseRateLimitsResponse(response)
    }

    public static func findExecutable(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL? {
        var candidates: [URL] = []

        if let configured = environment["CODEX_PATH"], !configured.isEmpty {
            candidates.append(URL(fileURLWithPath: configured))
        }

        let pluginAppServer = homeDirectory
            .appendingPathComponent(".codex/plugins/.plugin-appserver", isDirectory: true)

        candidates.append(contentsOf: [
            URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"),
            URL(fileURLWithPath: "/Applications/Codex.app/Contents/Resources/codex"),
            pluginAppServer.appendingPathComponent("codex-cli/bin/codex"),
            pluginAppServer.appendingPathComponent("codex-cli/CodexCLI.app/Contents/MacOS/codex"),
            pluginAppServer.appendingPathComponent("codex"),
        ])

        let pathDirectories = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0), isDirectory: true) }
        candidates.append(contentsOf: pathDirectories.map { $0.appendingPathComponent("codex") })

        candidates.append(contentsOf: [
            homeDirectory.appendingPathComponent(".local/bin/codex"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex"),
        ])

        let nodeVersions = homeDirectory.appendingPathComponent(".nvm/versions/node", isDirectory: true)
        if let versions = try? fileManager.contentsOfDirectory(
            at: nodeVersions,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            candidates.append(contentsOf: versions
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
                .map { $0.appendingPathComponent("bin/codex") })
        }

        var seen = Set<String>()
        return candidates.first { candidate in
            seen.insert(candidate.standardizedFileURL.path).inserted
                && fileManager.isExecutableFile(atPath: candidate.path)
        }
    }

    private func parseRateLimitsResponse(_ response: [String: Any]) throws -> ProviderUsage {
        guard let result = response["result"] as? [String: Any] else {
            throw UsageError.invalidResponse("Codex App Server")
        }

        let rateLimits: [String: Any]?
        if let byID = result["rateLimitsByLimitId"] as? [String: Any],
           let codex = byID["codex"] as? [String: Any] {
            rateLimits = codex
        } else {
            rateLimits = result["rateLimits"] as? [String: Any]
        }
        guard let rateLimits else {
            throw UsageError.codexAppServer("no ChatGPT rate limits were returned")
        }

        var windows: [UsageWindow] = []
        if let primary = rateLimits["primary"] as? [String: Any],
           let window = makeWindow(primary, fallbackID: "primary") {
            windows.append(window)
        }
        if let secondary = rateLimits["secondary"] as? [String: Any],
           let window = makeWindow(secondary, fallbackID: "secondary") {
            windows.append(window)
        }
        guard !windows.isEmpty else {
            throw UsageError.codexAppServer("the account returned no active usage windows")
        }

        let plan = (rateLimits["planType"] ?? result["planType"]) as? String
        let source = plan.map { "Codex live · \($0.capitalized)" } ?? "Codex live"
        return ProviderUsage(
            id: "codex",
            name: "Codex",
            windows: windows,
            source: source
        )
    }

    private func makeWindow(_ value: [String: Any], fallbackID: String) -> UsageWindow? {
        guard let used = number(value["usedPercent"]) else { return nil }
        let minutes = number(value["windowDurationMins"]).map(Int.init) ?? 0
        let resetDate = number(value["resetsAt"]).map { Date(timeIntervalSince1970: $0) }
        return UsageWindow(
            id: "codex-\(minutes == 0 ? fallbackID : String(minutes))",
            label: Self.durationLabel(minutes: minutes, fallback: fallbackID),
            usedPercent: used,
            resetsAt: resetDate
        )
    }

    private func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func durationLabel(minutes: Int, fallback: String) -> String {
        switch minutes {
        case 300: return "5 hr"
        case 10_080: return "Weekly"
        case 43_200, 44_640: return "Monthly"
        default:
            if minutes.isMultiple(of: 10_080), minutes > 0 { return "\(minutes / 10_080) wk" }
            if minutes.isMultiple(of: 1_440), minutes > 0 { return "\(minutes / 1_440) day" }
            if minutes.isMultiple(of: 60), minutes > 0 { return "\(minutes / 60) hr" }
            return minutes > 0 ? "\(minutes) min" : fallback.capitalized
        }
    }

    private func send(_ object: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        do {
            try handle.write(contentsOf: data)
        } catch {
            throw UsageError.codexAppServer("connection closed while sending a request")
        }
    }

    private func validate(_ response: [String: Any]) throws {
        guard let error = response["error"] as? [String: Any] else { return }
        let message = error["message"] as? String ?? "unknown protocol error"
        throw UsageError.codexAppServer(message)
    }

    private func responseFailure(process: Process, errors: TextCapture) -> UsageError {
        let detail = errors.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !process.isRunning {
            return .codexAppServer(detail.isEmpty ? "the process exited before replying" : detail)
        }
        return .codexAppServerTimeout
    }
}

private final class JSONLineInbox: @unchecked Sendable {
    private let condition = NSCondition()
    private var buffer = Data()
    private var messages: [[String: Any]] = []
    private var ended = false

    func append(_ data: Data) {
        condition.lock()
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            if !line.isEmpty,
               let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] {
                messages.append(object)
            }
        }
        condition.broadcast()
        condition.unlock()
    }

    func finish() {
        condition.lock()
        ended = true
        condition.broadcast()
        condition.unlock()
    }

    func wait(forID id: Int, until deadline: Date) -> [String: Any]? {
        condition.lock()
        defer { condition.unlock() }

        while true {
            if let index = messages.firstIndex(where: { ($0["id"] as? NSNumber)?.intValue == id }) {
                return messages.remove(at: index)
            }
            if ended || deadline.timeIntervalSinceNow <= 0 { return nil }
            condition.wait(until: deadline)
        }
    }
}

private final class TextCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        if data.count > 16_384 { data.removeFirst(data.count - 16_384) }
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}
