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

  func testGuideCalloutOpensItsSection() {
    openCard()
    let clap = callout("Clap the crease")
    XCTAssertTrue(clap.waitForExistence(timeout: 5))
    shot("card")
    clap.tap()
    XCTAssertTrue(app.staticTexts["How to play"].waitForExistence(timeout: 5), "didn't land on How to play")
    XCTAssertFalse(app.buttons["Let's pop!"].exists, "the card stayed open")
    XCTAssertTrue(app.staticTexts["Touch both pages by the fold at once to clap it."].waitForExistence(timeout: 5),
                  "the On iPhone Duo section isn't open")
    shot("guide-duo")
  }

  func testMapCalloutOpensTheMap() {
    openCard()
    let map = callout("bossier")
    if !map.isHittable { app.swipeUp() }
    map.tap()
    XCTAssertTrue(app.staticTexts["Level map"].waitForExistence(timeout: 5), "didn't land on the level map")
    shot("map")
  }
}
