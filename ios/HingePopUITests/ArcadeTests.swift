import XCTest

/// Arcade has its own page: Home sends you there, and it puts the furthest checkpoint one tap away.
final class ArcadeTests: XCTestCase {
  private var app: XCUIApplication!
  override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["ARCADE_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
  }

  func testAFreshArcadePageStartsARun() {
    app.launchArguments = ["-fresh", "-toured"]
    app.launch()
    let arcade = app.buttons["arcade"]
    XCTAssertTrue(arcade.waitForExistence(timeout: 25), "no Arcade button on Home")
    arcade.tap()
    XCTAssertTrue(app.staticTexts["HIGH SCORE"].waitForExistence(timeout: 10), "the Arcade page didn't open")
    let start = app.buttons["arcade-start"]
    XCTAssertTrue(start.exists)
    XCTAssertFalse(app.buttons["arcade-continue"].exists, "nothing to continue on a fresh save")
    shot("fresh")
    start.tap()
    XCTAssertTrue(app.staticTexts["HIGH SCORE"].waitForNonExistence(timeout: 10), "Start didn't begin a run")
  }

  func testAReachedCheckpointIsOneTapAway() {
    app.launchArguments = ["-fresh", "-toured", "-arcadeBest", "12"]
    app.launch()
    let arcade = app.buttons["arcade"]
    XCTAssertTrue(arcade.waitForExistence(timeout: 25))
    XCTAssertTrue(arcade.label.contains("wave 10"), "Home should show the checkpoint, got \(arcade.label)")
    arcade.tap()
    let go = app.buttons["arcade-continue"]
    XCTAssertTrue(go.waitForExistence(timeout: 10), "no Continue on the Arcade page")
    XCTAssertTrue(go.label.contains("wave 10"))
    XCTAssertTrue(app.buttons["Start from wave 5, Level Up"].exists, "earlier checkpoints are open too")
    XCTAssertFalse(app.buttons["Wave 15, Bonus Stage, locked"].isEnabled, "a checkpoint not yet reached stays locked")
    shot("checkpoints")
    go.tap()
    XCTAssertTrue(go.waitForNonExistence(timeout: 10), "Continue didn't begin a run")
  }
}
