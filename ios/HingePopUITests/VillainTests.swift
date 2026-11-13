import XCTest

/// Villains: the first level that brings them opens a card about them, and a Doom touched ends the run with the
/// villain named on the lose card.
final class VillainTests: XCTestCase {
  private var app: XCUIApplication!
  override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

  /// VILLAIN_SHOTS=<dir> saves what each step looked like.
  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["VILLAIN_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
  }
  private func text(_ s: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
  }

  func testTheFirstVillainLevelIntroducesItOnce() {
    app.launchArguments = ["-fresh", "-toured", "-unlock", "4", "-level", "4"]
    app.launch()
    let gotIt = app.buttons["villainGotIt"]
    XCTAssertTrue(gotIt.waitForExistence(timeout: 25), "no villain card on level 4")
    XCTAssertTrue(text("Hex").exists)
    XCTAssertTrue(text("costs a shield").exists, "the card says what a touch costs")
    shot("alert")
    gotIt.tap()
    XCTAssertTrue(gotIt.waitForNonExistence(timeout: 5), "the card stayed open")
  }

  func testADoomTouchedEndsTheRunAndNamesTheVillain() {
    app.launchArguments = ["-fresh", "-toured", "-level", "40", "-endCard", "lose", "-villain", "overlord"]
    app.launch()
    XCTAssertTrue(text("Overlord ended it").waitForExistence(timeout: 30), "the lose card doesn't name the villain")
    XCTAssertTrue(text("LEVEL 40 · DOOMED").exists || text("DOOMED").exists)
    shot("doomed")
    let retry = app.buttons["retry"]
    XCTAssertTrue(retry.isHittable)
  }
}
