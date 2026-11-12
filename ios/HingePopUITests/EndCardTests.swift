import XCTest

/// The end card, played to by itself with -endCard: a clear stamps a grade and lists its challenges, a loss says
/// what went wrong, and Retry is one tap from either.
final class EndCardTests: XCTestCase {
  private var app: XCUIApplication!
  override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

  /// END_CARD_SHOTS=<dir> saves what the card looked like.
  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["END_CARD_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
  }

  func testAClearShowsItsGradeAndChallenges() {
    app.launchArguments = ["-fresh", "-toured", "-endCard", "win", "-level", "12"]
    app.launch()
    XCTAssertTrue(app.otherElements["grade"].waitForExistence(timeout: 25) || app.descendants(matching: .any)["grade"].waitForExistence(timeout: 5), "no grade stamp")
    XCTAssertTrue(app.staticTexts["Cleared!"].exists)
    // Level 12 asks to keep every shield, beat a clock and snap two at once.
    XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Keep every shield")).firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Level 13"].exists)
    Thread.sleep(forTimeInterval: 2.5)
    shot("win")
    let retry = app.buttons["retry"]
    XCTAssertTrue(retry.exists, "a clear that missed a challenge offers a quick retry")
    retry.tap()
    XCTAssertTrue(app.descendants(matching: .any)["grade"].waitForNonExistence(timeout: 5), "retry didn't start the level again")
  }

  func testALossSaysWhyAndRetriesInOneTap() {
    app.launchArguments = ["-fresh", "-toured", "-endCard", "lose", "-level", "12"]
    app.launch()
    let reason = app.staticTexts["lossReason"]
    XCTAssertTrue(reason.waitForExistence(timeout: 25), "no loss reason")
    XCTAssertEqual(reason.label, "A big one got through")
    shot("lose")
    let retry = app.buttons["retry"]
    XCTAssertTrue(retry.isHittable)
    retry.tap()
    XCTAssertTrue(reason.waitForNonExistence(timeout: 5), "retry didn't start the level again")
  }
}
