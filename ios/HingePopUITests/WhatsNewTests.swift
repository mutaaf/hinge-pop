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

  func testVillainCalloutOpensTheVillainGuide() {
    openCard()
    let villains = callout("Villain bubbles are here")
    XCTAssertTrue(villains.waitForExistence(timeout: 5))
    shot("card")
    villains.tap()
    XCTAssertTrue(app.staticTexts["Spiked rims mean hands off. The colour says how bad a touch is."].waitForExistence(timeout: 10), "didn't open the Villains section")
    XCTAssertFalse(app.buttons["Let's pop!"].exists, "the card stayed open")
    shot("guide")
  }

  func testArcadeCalloutOpensTheArcadePage() {
    openCard()
    let arcade = callout("Arcade has its own page")
    if !arcade.isHittable { app.swipeUp() }
    arcade.tap()
    XCTAssertTrue(app.staticTexts["HIGH SCORE"].waitForExistence(timeout: 10), "didn't land on the Arcade page")
    XCTAssertFalse(app.buttons["Let's pop!"].exists, "the card stayed open")
    shot("arcade")
  }
}
