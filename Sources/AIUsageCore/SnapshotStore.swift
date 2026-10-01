import Foundation

public struct SnapshotStore: Sendable {
    public static var appGroupIdentifier: String? {
        guard let identifier = Bundle.main.object(
            forInfoDictionaryKey: "AIUsageAppGroupIdentifier"
        ) as? String else {
            return nil
        }
        let value = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("."), !value.contains("$(") else {
            return nil
        }
        return value
    }

    public let fileURL: URL

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileURL = homeDirectory
            .appendingPathComponent("Library/Application Support/AIUsageWidget", isDirectory: true)
            .appendingPathComponent("usage.json")
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func appGroup(
        fileManager: FileManager = .default
    ) -> SnapshotStore? {
        guard let appGroupIdentifier else { return nil }
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }
        return SnapshotStore(fileURL: container.appendingPathComponent("usage.json"))
    }

    public static func preferred() -> SnapshotStore {
        appGroup() ?? SnapshotStore()
    }

    public func load() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? Self.decoder.decode(UsageSnapshot.self, from: data)
    }

    public func save(_ snapshot: UsageSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
