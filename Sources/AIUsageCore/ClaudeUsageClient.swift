import Foundation
import Security

public struct ClaudeUsageClient: Sendable {
    private let homeDirectory: URL
    private let session: URLSession
    private let credentialLoader: @Sendable () throws -> Data

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        session: URLSession = .shared,
        credentialLoader: (@Sendable () throws -> Data)? = nil
    ) {
        self.homeDirectory = homeDirectory
        self.session = session
        self.credentialLoader = credentialLoader ?? {
            try Self.loadCredentials(homeDirectory: homeDirectory)
        }
    }

    public func fetch() async throws -> ProviderUsage {
        let credentialData = try credentialLoader()
        guard let accessToken = Self.oauthToken(from: credentialData) else {
            throw UsageError.invalidClaudeCredentials
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.timeoutInterval = 20
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("AIUsageWidget/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UsageError.invalidResponse("Claude")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UsageError.http(http.statusCode)
        }
        return try parseUsage(data)
    }

    public func parseUsage(_ data: Data) throws -> ProviderUsage {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.invalidResponse("Claude")
        }

        let mappings: [(key: String, label: String)] = [
            ("five_hour", "5 hr"),
            ("seven_day", "Weekly"),
        ]
        let windows = mappings.compactMap { item -> UsageWindow? in
            guard let value = root[item.key] as? [String: Any],
                  let utilization = Self.number(value["utilization"] ?? value["used_percentage"])
            else { return nil }
            return UsageWindow(
                id: "claude-\(item.key)",
                label: item.label,
                usedPercent: utilization,
                resetsAt: Self.date(value["resets_at"])
            )
        }

        guard !windows.isEmpty else { throw UsageError.invalidResponse("Claude") }
        return ProviderUsage(
            id: "claude",
            name: "Claude",
            windows: windows,
            source: "Claude usage API"
        )
    }

    public static func oauthToken(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any]
        else { return nil }
        return oauth["accessToken"] as? String
    }

    private static func loadCredentials(homeDirectory: URL) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "Claude Code-credentials",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return data
        }

        let file = homeDirectory
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent(".credentials.json")
        if let data = try? Data(contentsOf: file) { return data }
        throw UsageError.noClaudeCredentials
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        if let unix = number(value) { return Date(timeIntervalSince1970: unix) }
        guard let string = value as? String else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}
