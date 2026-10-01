import Foundation

public struct CodexUsageService {
    private let appServer: CodexAppServerClient
    private let logs: CodexUsageReader

    public init(
        appServer: CodexAppServerClient = CodexAppServerClient(),
        logs: CodexUsageReader = CodexUsageReader()
    ) {
        self.appServer = appServer
        self.logs = logs
    }

    public func fetch() throws -> ProviderUsage {
        do {
            return try appServer.fetch()
        } catch {
            let liveError = error.localizedDescription
            do {
                let local = try logs.fetch()
                return ProviderUsage(
                    id: local.id,
                    name: local.name,
                    windows: local.windows,
                    source: local.source + " · fallback",
                    statusMessage: "Live account refresh unavailable: \(liveError)",
                    isStale: true
                )
            } catch {
                throw UsageError.codexUnavailable("\(liveError) No local usage snapshot was found.")
            }
        }
    }
}
