import XCTest
@testable import Glint

/// Pins the wire shape of Claude's OAuth usage endpoint, especially the
/// `limits` array that carries model-scoped weekly buckets ("Fable").
final class ClaudeUsageReaderTests: XCTestCase {

    /// Mirrors the live 2026-08 response: flat five_hour/seven_day plus a
    /// structured `limits` array with a model-scoped weekly entry.
    func testDecodeParsesModelScopedWeeklyBucket() throws {
        let json = """
        {
          "five_hour": { "utilization": 53.0, "resets_at": "2026-08-19T07:00:00.325603+00:00" },
          "seven_day": { "utilization": 19.0, "resets_at": "2026-08-20T03:00:00.325629+00:00" },
          "limits": [
            { "kind": "session", "group": "session", "percent": 53,
              "resets_at": "2026-08-19T07:00:00.325603+00:00", "scope": null, "is_active": true },
            { "kind": "weekly_all", "group": "weekly", "percent": 19,
              "resets_at": "2026-08-20T03:00:00.325629+00:00", "scope": null, "is_active": false },
            { "kind": "weekly_scoped", "group": "weekly", "percent": 12,
              "resets_at": "2026-08-20T03:00:00.325868+00:00",
              "scope": { "model": { "id": null, "display_name": "Fable" }, "surface": null },
              "is_active": false }
          ]
        }
        """
        let quota = try XCTUnwrap(ClaudeUsageReader.decode(Data(json.utf8)))
        XCTAssertEqual(quota.sessionPercent, 53)
        XCTAssertEqual(quota.weeklyPercent, 19)
        let scoped = try XCTUnwrap(quota.scopedWeekly)
        XCTAssertEqual(scoped.count, 1)
        XCTAssertEqual(scoped[0].name, "Fable")
        XCTAssertEqual(scoped[0].percent, 12)
        XCTAssertNotNil(scoped[0].resetsAt)
    }

    /// Pre-`limits` payloads (flat five_hour/seven_day only) must keep
    /// decoding with no scoped buckets.
    func testDecodeWithoutLimitsArrayLeavesScopedWeeklyNil() throws {
        let json = """
        {
          "five_hour": { "utilization": 20.0, "resets_at": "2026-08-19T07:00:00.410483+00:00" },
          "seven_day": { "utilization": 16.0, "resets_at": "2026-08-20T03:00:00.410503+00:00" }
        }
        """
        let quota = try XCTUnwrap(ClaudeUsageReader.decode(Data(json.utf8)))
        XCTAssertEqual(quota.sessionPercent, 20)
        XCTAssertNil(quota.scopedWeekly)
    }

    /// A `limits` array with only account-level entries yields nil, not an
    /// empty list ("not reported" semantics drive the renderer's nil checks).
    func testDecodeIgnoresUnscopedWeeklyEntries() throws {
        let json = """
        {
          "five_hour": { "utilization": 10.0 },
          "limits": [
            { "kind": "session", "group": "session", "percent": 10, "scope": null },
            { "kind": "weekly_all", "group": "weekly", "percent": 5, "scope": null }
          ]
        }
        """
        let quota = try XCTUnwrap(ClaudeUsageReader.decode(Data(json.utf8)))
        XCTAssertNil(quota.scopedWeekly)
    }

    /// Scoped entries missing a usable percent or model name are dropped;
    /// non-finite percents never survive `sanitized()`.
    func testDecodeSkipsMalformedScopedEntries() throws {
        let json = """
        {
          "five_hour": { "utilization": 10.0 },
          "limits": [
            { "kind": "weekly_scoped", "group": "weekly", "scope": { "model": { "display_name": "Fable" } } },
            { "kind": "weekly_scoped", "group": "weekly", "percent": 33, "scope": { "model": { "display_name": "" } } },
            { "kind": "weekly_scoped", "group": "weekly", "percent": 33, "scope": { "model": { "display_name": "Fable" } } }
          ]
        }
        """
        let quota = try XCTUnwrap(ClaudeUsageReader.decode(Data(json.utf8)))
        let scoped = try XCTUnwrap(quota.scopedWeekly)
        XCTAssertEqual(scoped.map(\.name), ["Fable"])
        XCTAssertEqual(scoped[0].percent, 33)
    }

    /// Snapshots persisted by older builds (no scopedWeekly key) must still
    /// decode, with the field defaulting to nil.
    func testLegacySnapshotDecodesWithoutScopedWeekly() throws {
        let legacy = """
        { "sessionPercent": 42.0, "weeklyPercent": 10.0 }
        """
        let quota = try JSONDecoder().decode(AgentQuota.self, from: Data(legacy.utf8))
        XCTAssertEqual(quota.sessionPercent, 42)
        XCTAssertNil(quota.scopedWeekly)
    }
}
