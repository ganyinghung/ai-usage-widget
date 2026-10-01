import XCTest
@testable import AIUsageCore

final class AIUsageCoreTests: XCTestCase {
    func testCodexParserFindsLatestRateLimits() throws {
        let input = """
        {"type":"event_msg","payload":{"rate_limits":{"limit_id":"codex","primary":{"used_percent":12,"window_minutes":300,"resets_at":1800000000},"secondary":{"used_percent":34,"window_minutes":10080,"resets_at":1800100000},"plan_type":"plus"}}}
        {"type":"event_msg","payload":{"message":"later unrelated line"}}
        """
        let limits = try CodexUsageReader().parseRateLimits(from: Data(input.utf8))
        let primary = limits?["primary"] as? [String: Any]
        XCTAssertEqual((primary?["used_percent"] as? NSNumber)?.doubleValue, 12)
    }

    func testCodexAppServerParserMapsLiveWindows() throws {
        let input = """
        {
          "id": 2,
          "result": {
            "rateLimits": {
              "limitId": "codex",
              "primary": {"usedPercent": 21, "windowDurationMins": 300, "resetsAt": 1800000000},
              "secondary": {"usedPercent": 44, "windowDurationMins": 10080, "resetsAt": 1800100000},
              "planType": "plus"
            }
          }
        }
        """
        let usage = try CodexAppServerClient().parseRateLimitsResponse(Data(input.utf8))
        XCTAssertEqual(usage.source, "Codex live · Plus")
        XCTAssertEqual(usage.windows.map(\.label), ["5 hr", "Weekly"])
        XCTAssertEqual(usage.windows.map(\.usedPercent), [21, 44])
        XCTAssertFalse(usage.isStale)
    }

    func testCodexAppServerParserPrefersCodexBucket() throws {
        let input = """
        {
          "id": 2,
          "result": {
            "rateLimits": {
              "limitId": "legacy",
              "primary": {"usedPercent": 99, "windowDurationMins": 60}
            },
            "rateLimitsByLimitId": {
              "codex_other": {
                "limitId": "codex_other",
                "primary": {"usedPercent": 88, "windowDurationMins": 60}
              },
              "codex": {
                "limitId": "codex",
                "primary": {"usedPercent": 7, "windowDurationMins": 300}
              }
            }
          }
        }
        """
        let usage = try CodexAppServerClient().parseRateLimitsResponse(Data(input.utf8))
        XCTAssertEqual(usage.windows.first?.usedPercent, 7)
    }

    func testClaudeParserMapsWindows() throws {
        let input = """
        {
          "five_hour": {"utilization": 8.5, "resets_at": "2026-10-01T15:00:00Z"},
          "seven_day": {"utilization": 42, "resets_at": "2026-10-05T10:00:00Z"}
        }
        """
        let usage = try ClaudeUsageClient(credentialLoader: { Data() }).parseUsage(Data(input.utf8))
        XCTAssertEqual(usage.windows.map(\.label), ["5 hr", "Weekly"])
        XCTAssertEqual(usage.windows.map(\.usedPercent), [8.5, 42])
        XCTAssertNotNil(usage.windows[0].resetsAt)
    }

    func testOAuthTokenExtraction() {
        let data = Data(#"{"claudeAiOauth":{"accessToken":"secret-token"}}"#.utf8)
        XCTAssertEqual(ClaudeUsageClient.oauthToken(from: data), "secret-token")
    }

    func testSnapshotRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SnapshotStore(fileURL: directory.appendingPathComponent("usage.json"))
        let expected = UsageSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            providers: [
                ProviderUsage(
                    id: "codex",
                    name: "Codex",
                    windows: [UsageWindow(id: "5h", label: "5 hr", usedPercent: 17, resetsAt: nil)],
                    source: "test"
                )
            ]
        )
        try store.save(expected)
        XCTAssertEqual(store.load(), expected)
    }
}
