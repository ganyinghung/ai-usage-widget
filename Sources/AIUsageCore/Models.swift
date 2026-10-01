import Foundation

public struct UsageWindow: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let usedPercent: Double
    public let resetsAt: Date?

    public init(id: String, label: String, usedPercent: Double, resetsAt: Date?) {
        self.id = id
        self.label = label
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Double { max(0, 100 - usedPercent) }
}

public struct ProviderUsage: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let windows: [UsageWindow]
    public let source: String
    public let statusMessage: String?
    public let isStale: Bool

    public init(
        id: String,
        name: String,
        windows: [UsageWindow],
        source: String,
        statusMessage: String? = nil,
        isStale: Bool = false
    ) {
        self.id = id
        self.name = name
        self.windows = windows
        self.source = source
        self.statusMessage = statusMessage
        self.isStale = isStale
    }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let providers: [ProviderUsage]

    public init(generatedAt: Date = Date(), providers: [ProviderUsage]) {
        self.generatedAt = generatedAt
        self.providers = providers
    }

    public static let empty = UsageSnapshot(providers: [])
}

public enum UsageError: LocalizedError, Equatable {
    case noCodexData
    case codexNotInstalled
    case codexAppServerTimeout
    case codexAppServer(String)
    case codexUnavailable(String)
    case noClaudeCredentials
    case invalidClaudeCredentials
    case invalidResponse(String)
    case http(Int)

    public var errorDescription: String? {
        switch self {
        case .noCodexData:
            return "No Codex rate-limit data yet. Run a recent Codex session once."
        case .codexNotInstalled:
            return "Codex App Server is not available on this Mac."
        case .codexAppServerTimeout:
            return "Codex App Server did not respond in time."
        case .codexAppServer(let message):
            return "Codex App Server: \(message)"
        case .codexUnavailable(let message):
            return "Codex usage is unavailable. \(message)"
        case .noClaudeCredentials:
            return "Claude Code is not signed in on this Mac."
        case .invalidClaudeCredentials:
            return "Claude Code credentials did not contain an OAuth token."
        case .invalidResponse(let provider):
            return "Could not understand the \(provider) usage response."
        case .http(let code):
            return "Claude usage request failed (HTTP \(code))."
        }
    }
}
