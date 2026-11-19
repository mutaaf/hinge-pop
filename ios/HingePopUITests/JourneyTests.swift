import XCTest

/// Replaying earlier levels from the journey. Every stop on screen must take a tap (0.5.1 and before: each row's
/// tall backdrop lay over the rows above it, so only boss stops could be tapped), and a tap on an open stop plays
/// that level, not the one Play would start.
final class JourneyTests: XCTestCase {
  private var app: XCUIApplication!
  override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

  /// Opens the journey on a seeded save, landed on `level`'s stop (`-journeyAt`; a Mac can't drag-scroll the path).
  private func launch(_ extra: [String], at level: Int) {
    app.launchArguments = ["-fresh", "-screen", "map", "-journeyAt", "\(level)"] + extra
    app.launch()
    XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 20), "the journey didn't open")
  }

  // MARK: Hit test (no clicks needed, so these also run on a Mac Catalyst build)

  /// Which stops on screen the real hit test gives a tap to (`-hitCheck`), and which something else covers.
  private func hits(_ extra: [String], at level: Int) -> (ok: [Int], blocked: [Int]) {
    launch(["-toured", "-normal", "-hitCheck"] + extra, at: level)
    let report = app.descendants(matching: .any)["hitCheck"]
    XCTAssertTrue(report.waitForExistence(timeout: 20), "no hit check")
    var out: [String: [Int]] = [:]
    for part in report.label.split(separator: ";") {
      let kv = part.split(separator: "=", omittingEmptySubsequences: false)
      guard kv.count == 2 else { continue }
      out[String(kv[0])] = kv[1].split(separator: ",").compactMap { Int($0) }
    }
    return (out["ok"] ?? [], out["blocked"] ?? [])
  }

  private func assertAllTappable(_ extra: [String], at level: Int, line: UInt = #line) {
    let h = hits(extra, at: level)
    XCTAssertEqual(h.blocked, [], "stops covered by something else: \(h.blocked)", line: line)
    XCTAssertTrue(h.ok.contains(level), "level \(level) isn't on screen and tappable: \(h.ok)", line: line)
    XCTAssertGreaterThanOrEqual(h.ok.count, 4, "too few stops checked: \(h.ok)", line: line)
  }

  func testEveryStopOnScreenTakesATapMidRealm() {
    assertAllTappable(["-unlock", "30"], at: 5)
  }

  func testStopsAcrossAWorldBannerTakeATap() {
    assertAllTappable(["-unlock", "30"], at: 12)
  }

  func testStopsAboveAGatedRealmCardTakeATap() {
    // Realm 1 cleared on one star each: realm 2 waits on its gate, and its title card follows level 80.
    assertAllTappable(["-unlock", "81", "-starsEach", "1"], at: 77)
  }

  // MARK: Real taps (need a simulator or device: a Mac Catalyst UI test's clicks don't reach the app)

  /// The journey stop for a level (its label starts "Level n,").
  private func stop(_ level: Int) -> XCUIElement {
    let s = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Level \(level),")).firstMatch
    XCTAssertTrue(s.waitForExistence(timeout: 10), "level \(level)'s stop never came on screen")
    return s
  }

  private func assertPlaying(_ level: Int, file: StaticString = #filePath, line: UInt = #line) {
    let tag = app.descendants(matching: .any)["playLevel"]
    XCTAssertTrue(tag.waitForExistence(timeout: 15), "no level started", file: file, line: line)
    XCTAssertEqual(tag.label, "LEVEL \(level)", file: file, line: line)
  }

  func testTheLevelTagReadsTheLevelInPlay() {
    app.launchArguments = ["-fresh", "-toured", "-normal", "-unlock", "30", "-level", "5"]
    app.launch()
    assertPlaying(5)
  }

  func testTappingAnEarlierStopPlaysIt() {
    launch(["-toured", "-normal", "-unlock", "30"], at: 5)
    stop(5).tap()
    assertPlaying(5)
  }

  func testEarlierStopPlaysWhileTheNextRealmIsGated() {
    launch(["-toured", "-normal", "-unlock", "81", "-starsEach", "1"], at: 12)
    stop(12).tap()
    assertPlaying(12)
  }

  func testEarlierStopPlaysOnOverdrive() {
    launch(["-toured", "-overdrive", "-unlock", "30"], at: 2)
    stop(2).tap()
    assertPlaying(2)
  }

  func testEarlierStopAfterTheTourPlaysIt() {
    // A save that never saw the tour: picking a stop runs the tour first, then the stop it was picked for.
    launch(["-normal", "-unlock", "30"], at: 7)
    stop(7).tap()
    let skip = app.buttons["Skip tour"]
    if skip.waitForExistence(timeout: 10) { skip.tap() }
    assertPlaying(7)
  }
}
