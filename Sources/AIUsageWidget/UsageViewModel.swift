import AIUsageCore
import Foundation

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot
    @Published private(set) var isRefreshing = false

    private let snapshotStore = SnapshotStore()
    private var timer: Timer?

    init() {
        snapshot = snapshotStore.load() ?? .empty
    }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let previous = snapshot

        Task {
            async let codexResult = Self.fetchCodex()
            async let claudeResult = Self.fetchClaude()
            let results = await [codexResult, claudeResult]

            let providers = results.enumerated().map { index, result -> ProviderUsage in
                switch result {
                case .success(let usage):
                    return usage
                case .failure(let error):
                    let id = index == 0 ? "codex" : "claude"
                    let name = index == 0 ? "Codex" : "Claude"
                    if let cached = previous.providers.first(where: { $0.id == id }), !cached.windows.isEmpty {
                        return ProviderUsage(
                            id: cached.id,
                            name: cached.name,
                            windows: cached.windows,
                            source: cached.source,
                            statusMessage: error.localizedDescription,
                            isStale: true
                        )
                    }
                    return ProviderUsage(
                        id: id,
                        name: name,
                        windows: [],
                        source: "Unavailable",
                        statusMessage: error.localizedDescription
                    )
                }
            }

            snapshot = UsageSnapshot(providers: providers)
            try? snapshotStore.save(snapshot)
            isRefreshing = false
            NotificationCenter.default.post(name: .usageDidRefresh, object: snapshot)
        }
    }

    private static func fetchCodex() async -> Result<ProviderUsage, Error> {
        await Task.detached(priority: .utility) {
            Result { try CodexUsageService().fetch() }
        }.value
    }

    private static func fetchClaude() async -> Result<ProviderUsage, Error> {
        do { return .success(try await ClaudeUsageClient().fetch()) }
        catch { return .failure(error) }
    }
}

extension Notification.Name {
    static let usageDidRefresh = Notification.Name("AIUsageWidget.usageDidRefresh")
}
