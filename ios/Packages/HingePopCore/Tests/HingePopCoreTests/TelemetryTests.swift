// The health events: the frame meter's numbers, MetricKit's histograms as a few numbers, and the rule that only
// numbers, flags, enums and version numbers leave (never a stack, a path or any text a diagnostic carries).
import XCTest
@testable import HingePopCore

final class TelemetryTests: XCTestCase {
  func testFrameStatsAt60And120Hz() {
    var f = Telemetry.FrameStats(targetFPS: 60)
    for _ in 0..<90 { f.add(1.0 / 60) }
    for _ in 0..<9 { f.add(2.0 / 60) }   // each misses one
    f.add(0.1)                            // misses five
    XCTAssertEqual(f.frames, 100)
    XCTAssertEqual(f.dropped, 9 + 5)
    XCTAssertEqual(f.percentile(0.5), 16.75, accuracy: 0.01, "the 0.25 ms bin's upper edge")
    XCTAssertEqual(f.percentile(0.95), 33.5, accuracy: 0.01)
    XCTAssertEqual(f.maxMs, 100, accuracy: 0.001)
    XCTAssertEqual(f.percentile(1), 100, accuracy: 0.001)
    XCTAssertEqual(f.droppedPercent, 14.0 / 114 * 100, accuracy: 0.001)
    // Pauses, junk and the background aren't frames.
    for dt in [0, -1, .nan, .infinity, 0.3, 40] { f.add(dt) }
    XCTAssertEqual(f.frames, 100)
    // At 120 Hz a 60 Hz frame is a drop; vsync jitter isn't.
    var p = Telemetry.FrameStats(targetFPS: 120)
    p.add(1.0 / 120 * 1.3); XCTAssertEqual(p.dropped, 0)
    p.add(1.0 / 60); XCTAssertEqual(p.dropped, 1)
    XCTAssertEqual(p.targetFPS, 120)
    // Slower than the histogram reaches: the max is still exact.
    var s = Telemetry.FrameStats()
    s.add(0.2)
    XCTAssertEqual(s.percentile(0.5), 200, accuracy: 0.001)
    // Reset clears it; a silly target is clamped.
    s.reset(targetFPS: .nan)
    XCTAssertEqual(s.frames, 0); XCTAssertEqual(s.percentile(0.5), 0); XCTAssertEqual(s.targetFPS, 60)
    s.reset(targetFPS: 0); XCTAssertEqual(s.targetFPS, 1)
    XCTAssertEqual(Telemetry.FrameStats().droppedPercent, 0)
  }

  func testHistogramSummaries() {
    let b = [Telemetry.Bucket(startMs: 0, endMs: 500, count: 3), .init(startMs: 500, endMs: 1500, count: 5),
             .init(startMs: 1500, endMs: 3000, count: 1), .init(startMs: 4000, endMs: 9000, count: 1),
             .init(startMs: 9000, endMs: 10000, count: 0), .init(startMs: .nan, endMs: 1, count: 4), .init(startMs: 5, endMs: 1, count: 4)]
    let s = Telemetry.summarize(b, bands: Telemetry.launchBands)
    XCTAssertEqual(s.count, 10)
    XCTAssertEqual(s.p50Ms, 1000)
    XCTAssertEqual(s.p90Ms, 2250)
    XCTAssertEqual(s.maxMs, 9000)
    XCTAssertEqual(s.banded, [3, 5, 1, 1])
    XCTAssertEqual(Telemetry.summarize([]).count, 0)
    XCTAssertEqual(Telemetry.summarize([], bands: [1]).banded, [0, 0])
  }

  func testSmallConversions() {
    XCTAssertEqual(Telemetry.osMajor("iPhone OS 17.1 (21B74)"), 17)
    XCTAssertEqual(Telemetry.osMajor("Version 18.0 (Build 22A3354)"), 18)
    XCTAssertEqual(Telemetry.osMajor("iOS 26"), 26)
    XCTAssertNil(Telemetry.osMajor("unknown"))
    XCTAssertEqual(Telemetry.round(12.3456, 1), 12.3)
    XCTAssertEqual(Telemetry.round(99.5), 100)
  }

  func testHealthEventsKeepOnlyNumbersFlagsEnumsAndVersions() {
    let perf = Insights.clean("perf_level", ["mode": .text("solo"), "level": .num(45), "outcome": .text("won"), "p50_ms": .num(8.5),
                                            "p95_ms": .num(16), "max_ms": .num(40), "dropped_pct": .num(2.5), "target_fps": .num(120),
                                            "thermal": .text("fair"), "low_power": .bool(false), "fx_level": .num(2),
                                            "frames": .num(4000), "scene": .text("GameScene"), "thermal2": .text("hot")])
    XCTAssertEqual(perf?.count, 12, "unknown props dropped")
    XCTAssertNil(perf?["scene"])
    XCTAssertEqual(Insights.clean("perf_level", ["thermal": .text("melting"), "dropped_pct": .num(140), "outcome": .text("quit")]), [:])
    // Versions are digits and dots, nothing else.
    for ok in ["0.5.0", "1", "17.1.2.3"] { XCTAssertEqual(Insights.clean("app_metrics", ["app_version": .text(ok)])?["app_version"], .text(ok)) }
    for bad in ["0.5.0 (beta)", "/var/mobile/x", "", "1.2.3.4.5", "v1", "12345.1"] {
      XCTAssertNil(Insights.clean("app_metrics", ["app_version": .text(bad)])?["app_version"], bad)
    }
    // A diagnostic's text never gets through, whatever prop it hides in; an address-sized code is dropped.
    let d = Insights.clean("app_diagnostic", ["kind": .text("crash"), "exception_type": .num(1), "exception_code": .num(0x1_0000_0000),
                                              "signal": .num(11), "app_version": .text("0.5.0"),
                                              "termination": .text("Namespace SIGNAL, Code 11"), "kind2": .text("x"),
                                              "os_major": .num(18), "hang_ms": .text("/private/var/containers/Bundle")])
    XCTAssertEqual(d, ["kind": .text("crash"), "exception_type": .num(1), "signal": .num(11), "app_version": .text("0.5.0"), "os_major": .num(18)])
    XCTAssertEqual(Insights.clean("save_recovered", ["source": .text("backup"), "future": .bool(true)]),
                   ["source": .text("backup"), "future": .bool(true)])
    XCTAssertEqual(Insights.clean("save_recovered", ["source": .text("primary")]), [:], "a clean load isn't news")
  }

  func testHealthEventsWaitOutPlayLikeTheRest() {
    var q = Insights.Queue()
    q.add("app_diagnostic", ["kind": .text("hang"), "hang_ms": .num(2500)], at: 1, moment: .play, on: true)
    XCTAssertTrue(q.next(moment: .play, on: true).isEmpty)
    q.release()
    XCTAssertEqual(q.next(moment: .menu, on: true).first?.name, "app_diagnostic")
    XCTAssertFalse(q.add("app_metrics", ["launches": .num(3)], at: 2, moment: .menu, on: false), "the same switch turns them off")
  }

  func testEveryEnumTheAppSendsIsInTheVocabulary() {
    XCTAssertEqual(Telemetry.THERMAL.count, 4)
    XCTAssertEqual(Set(Telemetry.SAVE_SOURCES), Set([SaveVault.Source.salvaged, .backup, .rescued, .fresh].map(\.rawValue)))
  }
}
