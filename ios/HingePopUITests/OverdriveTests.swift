import XCTest

/// Overdrive: flip the switch on the home screen, start a level, and the HUD says it's running hot.
final class OverdriveTests: XCTestCase {
  private var app: XCUIApplication!
  override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

  /// OVERDRIVE_SHOTS=<dir> saves the switch and the HUD.
  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["OVERDRIVE_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
  }

  private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

  func testFlippingToOverdriveStartsAHotLevel() {
    app.launchArguments = ["-fresh", "-toured"]
    app.launch()
    let overdrive = app.buttons["difficulty-overdrive"]
    XCTAssertTrue(overdrive.waitForExistence(timeout: 20), "no difficulty switch on the home screen")
    XCTAssertTrue(app.buttons["difficulty-normal"].isSelected, "a fresh game starts on Normal")
    overdrive.tap()
    XCTAssertTrue(overdrive.isSelected)
    XCTAssertTrue(element("difficultyBlurb").label.contains("For experts"))
    Thread.sleep(forTimeInterval: 1)
    shot("switch")
    app.buttons["play"].tap()
    XCTAssertTrue(element("overdriveTag").waitForExistence(timeout: 20), "the HUD doesn't show Overdrive")
    Thread.sleep(forTimeInterval: 2)
    shot("hud")
  }

  func testNormalPlaysWithoutTheFlame() {
    app.launchArguments = ["-fresh", "-toured", "-overdrive"]
    app.launch()
    let normal = app.buttons["difficulty-normal"]
    XCTAssertTrue(normal.waitForExistence(timeout: 20))
    normal.tap()
    app.buttons["play"].tap()
    XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 20))
    XCTAssertFalse(element("overdriveTag").exists, "Normal shows no Overdrive tag")
  }
}
