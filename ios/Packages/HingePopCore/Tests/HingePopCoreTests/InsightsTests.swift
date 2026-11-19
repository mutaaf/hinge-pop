// 0.4.1: the app's usage events. The vocabulary is the web's (index.html track()), props are numbers, flags and enums
// only, nothing is queued during play, off clears everything, and the queue survives a relaunch, caps itself and keeps
// what a failed send didn't deliver.
import XCTest
import Foundation
@testable import HingePopCore

final class InsightsTests: XCTestCase {
  func testVocabularyIsTheWebsAndPropsAreNumbersFlagsOrEnums() {
    XCTAssertEqual(Set(Insights.EVENTS.keys), ["session_start", "game_start", "game_over", "tour_end",
                                               "perf_level", "app_metrics", "app_diagnostic", "save_recovered"])
    // Nothing that could carry a person: no names, ids or free text among the props.
    for (_, props) in Insights.EVENTS {
      for (k, _) in props {
        XCTAssertFalse(["initials", "name", "id", "text", "url", "log", "seed"].contains(k), k)
        // Diagnostics carry no stacks, paths, reasons, messages or device names.
        for bad in ["stack", "path", "file", "reason", "message", "symbol", "binary", "device", "model", "thread", "region"] {
          XCTAssertFalse(k.contains(bad), k)
        }
      }
    }
    XCTAssertNil(Insights.clean("page_view", [:]))
    let c = Insights.clean("game_over", ["mode": .text("solo"), "level": .num(12), "score": .num(4210), "duration_s": .num(61.3),
                                          "won": .bool(true), "crossings": .num(2), "name": .text("Ann"), "level2": .num(1)])
    XCTAssertEqual(c, ["mode": .text("solo"), "level": .num(12), "score": .num(4210), "duration_s": .num(61.3),
                       "won": .bool(true), "crossings": .num(2)])
    // Out of range, the wrong type or not one of the values: dropped.
    XCTAssertEqual(Insights.clean("game_start", ["mode": .text("moon"), "level": .num(-1), "difficulty": .num(1)]), [:])
    XCTAssertEqual(Insights.clean("game_over", ["score": .num(.nan), "won": .num(1), "draw": .text("yes")]), [:])
    XCTAssertEqual(Insights.clean("tour_end", ["tour": .text("two"), "completed": .bool(false)]),
                   ["tour": .text("two"), "completed": .bool(false)])
  }

  /// Every web event and prop the app sends is one the web game names in index.html, so a dashboard reads both.
  func testParityWithTheWebGamesTrackCalls() throws {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("index.html")
    guard let html = try? String(contentsOf: url, encoding: .utf8) else { throw XCTSkip("index.html not beside ios/") }
    let call = try NSRegularExpression(pattern: #"track\('([a-z_]+)',\s*\{([^}]*)\}"#)
    var web: [String: Set<String>] = [:]
    for m in call.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
      let name = String(html[Range(m.range(at: 1), in: html)!])
      let body = String(html[Range(m.range(at: 2), in: html)!])
      let keys = body.split(separator: ",").compactMap { part -> String? in
        let k = part.split(separator: ":").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return k.isEmpty ? nil : k
      }
      web[name, default: []].formUnion(keys)
    }
    XCTAssertEqual(Set(web.keys), ["game_start", "game_over", "tour_end"], "the web's events changed: update Insights.EVENTS")
    XCTAssertTrue(Insights.NATIVE_ONLY.isSubset(of: Insights.EVENTS.keys), "a native-only event that isn't in the vocabulary")
    XCTAssertTrue(Insights.NATIVE_ONLY.isDisjoint(with: web.keys), "the web sends it now: hold it to the web's props")
    // Native-only: Insights.NATIVE_ONLY (session_start, the health events) and `difficulty` (the web has no Overdrive).
    for (name, spec) in Insights.EVENTS where !Insights.NATIVE_ONLY.contains(name) {
      let w = web[name] ?? []
      for p in spec.keys where p != "difficulty" { XCTAssertTrue(w.contains(p), "\(name).\(p) isn't a web prop") }
      for p in w { XCTAssertNotNil(spec[p], "\(name).\(p) is a web prop the app drops") }
    }
  }

  func testModesAsTheWebCountsThem() {
    XCTAssertEqual(Insights.describe(.campaign(42))?.mode, "solo")
    XCTAssertEqual(Insights.describe(.campaign(42))?.level, 42)
    XCTAssertEqual(Insights.describe(.versus)?.mode, "versus")
    XCTAssertEqual(Insights.describe(.arcade(seed: 9))?.level, 0)
    XCTAssertEqual(Insights.describe(.daily(year: 2026, month: 11, day: 16))?.mode, "daily")
    XCTAssertNil(Insights.describe(.sandbox), "the tour's sandbox is never a game")
    for m in [GameMode.campaign(1), .versus, .arcade(seed: 1), .daily(year: 1, month: 1, day: 1)] {
      XCTAssertTrue(Insights.MODES.contains(Insights.describe(m)!.mode))
    }
    XCTAssertEqual(Insights.seconds(61.34), 61.3)
    XCTAssertEqual(Insights.seconds(-2), 0)
  }

  func testNothingIsQueuedDuringPlay() {
    var q = Insights.Queue()
    XCTAssertTrue(q.add("game_start", ["mode": .text("solo"), "level": .num(3)], at: 1, moment: .play, on: true))
    XCTAssertTrue(q.events.isEmpty)
    XCTAssertTrue(q.next(moment: .play, on: true).isEmpty)
    XCTAssertEqual(q.held.count, 1)
    q.release()
    XCTAssertEqual(q.events.count, 1); XCTAssertTrue(q.held.isEmpty)
    XCTAssertEqual(q.next(moment: .result, on: true).count, 1)
    XCTAssertTrue(q.next(moment: .play, on: true).isEmpty)
  }

  func testOffSendsNothingAndClearsTheQueueAndTheId() {
    var q = Insights.Queue()
    XCTAssertFalse(q.add("session_start", [:], at: 1, moment: .menu, on: false))
    XCTAssertNil(q.installId)
    q.add("session_start", ["returning": .num(0)], at: 1, moment: .menu, on: true)
    q.add("game_start", ["level": .num(1)], at: 2, moment: .play, on: true)
    let id = q.installId
    XCTAssertNotNil(id); XCTAssertNotNil(UUID(uuidString: id ?? ""))
    XCTAssertTrue(q.next(moment: .menu, on: false).isEmpty)
    q.clear()
    XCTAssertTrue(q.events.isEmpty); XCTAssertTrue(q.held.isEmpty); XCTAssertNil(q.installId)
    q.add("session_start", [:], at: 3, moment: .menu, on: true)
    XCTAssertNotEqual(q.installId, id, "a new id once it's on again")
    // The switch lives in the save: on unless turned off, and older saves load with it on.
    XCTAssertTrue(GameProgress().usage)
    var p = GameProgress(); p.usage = false
    let back = try? JSONDecoder().decode(GameProgress.self, from: JSONEncoder().encode(p))
    XCTAssertEqual(back?.usage, false)
  }

  func testTheQueueSurvivesARelaunchCapsItselfAndKeepsAFailedSend() throws {
    var q = Insights.Queue()
    for i in 0..<(Insights.QUEUE_CAP + 20) { q.add("game_start", ["level": .num(Double(i))], at: Double(i), moment: .menu, on: true) }
    XCTAssertEqual(q.events.count, Insights.QUEUE_CAP)
    XCTAssertEqual(q.events.first?.props["level"], .num(20), "the oldest go first")
    q.add("game_start", [:], at: 9999, moment: .play, on: true)   // held: not saved, a level in play at a relaunch is lost
    let back = Insights.Queue.decode(q.encoded())
    XCTAssertEqual(back.events, q.events); XCTAssertEqual(back.installId, q.installId); XCTAssertTrue(back.held.isEmpty)
    XCTAssertEqual(Insights.Queue.decode(Data("junk".utf8)), Insights.Queue())
    // A batch that failed is still there; one that went is gone, and what arrived meanwhile stays.
    var r = back
    let batch = r.next(moment: .menu, on: true)
    XCTAssertEqual(batch.count, Insights.BATCH_MAX)
    XCTAssertEqual(r.next(moment: .menu, on: true), batch, "unsent: the same batch next time")
    r.add("session_start", [:], at: 10_000, moment: .menu, on: true)
    r.sent(batch)
    XCTAssertEqual(r.events.count, Insights.QUEUE_CAP - Insights.BATCH_MAX + 1)
    XCTAssertEqual(r.events.last?.name, "session_start")
    // Flags keep their type through the disk.
    var f = Insights.Queue()
    f.add("tour_end", ["tour": .text("solo"), "completed": .bool(true)], at: 1, moment: .menu, on: true)
    XCTAssertEqual(Insights.Queue.decode(f.encoded()).events.first?.props["completed"], .bool(true))
  }

  func testTheBatchIsPostHogsShapeWithTheAppsProps() throws {
    var q = Insights.Queue()
    q.add("game_over", ["mode": .text("solo"), "level": .num(7), "score": .num(1200), "duration_s": .num(48.2), "won": .bool(true),
                        "crossings": .num(1)], at: 1_763_000_000_000, moment: .result, on: true)
    let body = try XCTUnwrap(Insights.body(q.events, installId: "abc", release: "0.4.1"))
    let j = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(j["api_key"] as? String, Insights.token)
    let e = try XCTUnwrap((j["batch"] as? [[String: Any]])?.first)
    XCTAssertEqual(e["event"] as? String, "game_over")
    XCTAssertNotNil(e["timestamp"] as? String)
    let p = try XCTUnwrap(e["properties"] as? [String: Any])
    XCTAssertEqual(p["distinct_id"] as? String, "abc")
    XCTAssertEqual(p["platform"] as? String, "ios")
    XCTAssertEqual(p["surface"] as? String, "app")
    XCTAssertEqual(p["app"] as? String, "hinge-pop")
    XCTAssertEqual(p["audience"] as? String, "general")
    XCTAssertEqual(p["release"] as? String, "0.4.1")
    XCTAssertEqual(p["$geoip_disable"] as? Bool, true)
    XCTAssertEqual(p["score"] as? Double, 1200)
    XCTAssertEqual(p["won"] as? Bool, true)
    XCTAssertEqual(p["mode"] as? String, "solo")
    XCTAssertTrue(String(decoding: body, as: UTF8.self).contains(#""won":true"#), "a flag goes out as JSON true, as the web's")
    XCTAssertTrue(Insights.endpoint.hasPrefix("https://mutaafaziz.com/boxoffice/e/"))
    XCTAssertEqual(Insights.referer, "https://mutaafaziz.com/hingepop/")
  }

  func testTheVisitCounters() {
    var v = Insights.Visits()
    let day: Double = 86_400_000
    XCTAssertEqual(v.start(at: 100 * day), ["returning": .num(0), "days_since_last": .num(0)])
    XCTAssertEqual(v.start(at: 103 * day + 5), ["returning": .num(1), "days_since_last": .num(3)])
    XCTAssertEqual(Insights.Visits.decode(v.encoded()), v)
    XCTAssertEqual(Insights.Visits.decode(Data("junk".utf8)), Insights.Visits())
  }
}
