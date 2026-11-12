import XCTest

/// The update card, forced with -whatsNew: a callout that goes somewhere closes the card and lands on its feature.
final class WhatsNewTests: XCTestCase {
  private var app: XCUIApplication!
  override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

  private func openCard() {
    app.launchArguments = ["-toured", "-whatsNew"]
    app.launch()
    XCTAssertTrue(app.buttons["Let's pop!"].waitForExistence(timeout: 20), "-whatsNew didn't force the card")
  }
  /// TEST_RUNNER_WHATSNEW_SHOTS=<dir> saves what each step looked like, for a PR or a quick look.
  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["WHATSNEW_SHOTS"] else { return }
    Thread.sleep(forTimeInterval: 0.6)
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
  }
  private func callout(_ text: String) -> XCUIElement {
    app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
  }

  func testVersusCalloutStartsAFaceOff() {
    openCard()
    let faceOff = callout("Two players, face to face")
    XCTAssertTrue(faceOff.waitForExistence(timeout: 5))
    shot("card")
    faceOff.tap()
    XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Player 1 shields")).firstMatch.waitForExistence(timeout: 10)
      || app.staticTexts["Step 1 of 4"].firstMatch.waitForExistence(timeout: 5), "didn't land in two-player")
    XCTAssertFalse(app.buttons["Let's pop!"].exists, "the card stayed open")
    shot("versus")
  }

  func testGuideCalloutOpensTwoPlayers() {
    openCard()
    let guide = callout("spin round")
    if !guide.isHittable { app.swipeUp() }
    guide.tap()
    XCTAssertTrue(app.staticTexts["Lay it flat, face to face. The half nearest you is yours."].waitForExistence(timeout: 5), "didn't open the two-player section")
    shot("guide")
  }
}
