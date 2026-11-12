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
    let clap = callout("catch a fever")
    XCTAssertTrue(clap.waitForExistence(timeout: 5))
    shot("card")
    clap.tap()
    XCTAssertTrue(app.staticTexts["How to play"].waitForExistence(timeout: 5), "didn't land on How to play")
    XCTAssertFalse(app.buttons["Let's pop!"].exists, "the card stayed open")
    shot("guide-score")
  }

  func testMapCalloutOpensTheMap() {
    openCard()
    let map = callout("3 challenges and an S")
    if !map.isHittable { app.swipeUp() }
    map.tap()
    XCTAssertTrue(app.staticTexts["Journey"].waitForExistence(timeout: 5), "didn't land on the journey")
    shot("map")
  }
}
