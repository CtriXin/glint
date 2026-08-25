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

/// Pins the `claude /usage` stdout shape (Claude Code 2.1.x) that
/// `ClaudeUsageCLIReader` parses — the keychain-free quota path.
final class ClaudeUsageCLIReaderTests: XCTestCase {

    /// Mirrors the live 2026-08-25 output on this Mac, trailing analytics
    /// section included (it must be ignored).
    private static let sample = """
    You are currently using your subscription to power your Claude Code usage

    Current session: 24% used · resets Aug 25 at 3pm (Asia/Singapore)
    Current week (all models): 22% used · resets Aug 27 at 11am (Asia/Singapore)
    Current week (Fable): 43% used · resets Aug 27 at 11am (Asia/Singapore)

    What's contributing to your limits usage?
    Approximate, based on local sessions on this machine — does not include other devices or claude.ai.

    Last 24h · 320 requests · 1 session
      100% of your usage came from sessions active for 8+ hours
    """

    /// 2026-08-25 11:33 +08:00 — just before the captured output was taken.
    private static var now: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return cal.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 11, minute: 33))!
    }

    func testParseExtractsSessionWeeklyAndScopedBuckets() throws {
        let quota = try XCTUnwrap(ClaudeUsageCLIReader.parse(Self.sample, now: Self.now))
        XCTAssertEqual(quota.sessionPercent, 24)
        XCTAssertEqual(quota.weeklyPercent, 22)
        let scoped = try XCTUnwrap(quota.scopedWeekly)
        XCTAssertEqual(scoped.map(\.name), ["Fable"])
        XCTAssertEqual(scoped[0].percent, 43)
    }

    func testParseResolvesResetDatesInCaptionTimeZone() throws {
        let quota = try XCTUnwrap(ClaudeUsageCLIReader.parse(Self.sample, now: Self.now))
        let sessionReset = try XCTUnwrap(quota.sessionResetsAt)
        // "Aug 25 at 3pm (Asia/Singapore)" == 15:00 +08:00 == 07:00 UTC.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Singapore"))
        let comps = cal.dateComponents([.month, .day, .hour, .minute], from: sessionReset)
        XCTAssertEqual(comps.month, 8)
        XCTAssertEqual(comps.day, 25)
        XCTAssertEqual(comps.hour, 15)
        XCTAssertEqual(comps.minute, 0)
        // Weekly reset is after the session reset and within the 8d sanity bound.
        let weeklyReset = try XCTUnwrap(quota.weeklyResetsAt)
        XCTAssertGreaterThan(weeklyReset, sessionReset)
        XCTAssertLessThanOrEqual(weeklyReset.timeIntervalSince(Self.now), 8 * 24 * 3600)
        XCTAssertEqual(quota.scopedWeekly?.first?.resetsAt, weeklyReset)
    }

    /// A reset caption in the past relative to `now` rolls to next year's
    /// occurrence (Dec → Jan boundary), never renders a negative countdown.
    func testParseResetDateRollsPastOccurrenceToNextYear() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let dec31 = cal.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23))!
        let date = try XCTUnwrap(
            ClaudeUsageCLIReader.parseResetDate("Jan 1 at 12am (UTC)", now: dec31, maxAhead: 8 * 24 * 3600))
        XCTAssertEqual(cal.component(.year, from: date), 2027)
    }

    /// Implausibly distant resets (parse garbage, window drift) yield nil —
    /// the bar keeps its percent but drops the countdown rather than lying.
    func testParseResetDateRejectsBeyondWindow() {
        let date = ClaudeUsageCLIReader.parseResetDate(
            "Dec 31 at 11pm (UTC)", now: Self.now, maxAhead: 6 * 3600)
        XCTAssertNil(date)
    }

    /// Not-logged-in / older-CLI output has no session line → nil, so the
    /// caller degrades to last-known numbers.
    func testParseReturnsNilWithoutSessionLine() {
        XCTAssertNil(ClaudeUsageCLIReader.parse("Not logged in · Please run /login", now: Self.now))
        XCTAssertNil(ClaudeUsageCLIReader.parse("", now: Self.now))
    }

    /// Lines without a reset tail still parse (countdown simply absent).
    func testParseToleratesMissingResetCaption() throws {
        let quota = try XCTUnwrap(ClaudeUsageCLIReader.parse(
            "Current session: 61% used\nCurrent week (all models): 30% used", now: Self.now))
        XCTAssertEqual(quota.sessionPercent, 61)
        XCTAssertEqual(quota.weeklyPercent, 30)
        XCTAssertNil(quota.sessionResetsAt)
        XCTAssertNil(quota.weeklyResetsAt)
    }
}
