import XCTest

/// Two players, face to face: each has a scoreboard at their own edge, one pause both can reach, and a result
/// card each at the end with one Rematch on the hinge.
final class VersusTests: XCTestCase {
  private var app: XCUIApplication!
  override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

  private func labelled(_ prefix: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
  }

  func testBothPlayersGetAScoreboardAndShareOnePause() {
    app.launchArguments = ["-fresh", "-toured", "-versus"]
    app.launch()
    XCTAssertTrue(labelled("Player 1 shields").waitForExistence(timeout: 25), "no scoreboard for Player 1")
    XCTAssertTrue(labelled("Player 2 shields").exists, "no scoreboard for Player 2")
    XCTAssertTrue(labelled("Player 1 score").exists)
    XCTAssertTrue(labelled("Player 2 score").exists)
    XCTAssertFalse(labelled("Left").exists, "nothing says left or right any more")
    let window = app.windows.firstMatch.frame
    let p1 = labelled("Player 1 shields").frame, p2 = labelled("Player 2 shields").frame
    if window.height > window.width {
      // Portrait: Player 1 at the bottom, Player 2 across the table at the top.
      XCTAssertGreaterThan(p1.midY, window.height * 0.75)
      XCTAssertLessThan(p2.midY, window.height * 0.25)
    } else {
      XCTAssertNotEqual(p1.midX > window.width / 2, p2.midX > window.width / 2, "the seats sit at opposite ends")
    }
    let pause = app.buttons["versusPause"]
    XCTAssertTrue(pause.isHittable)
    XCTAssertGreaterThanOrEqual(pause.frame.width, 44)
    pause.tap()
    // Each player gets their own pause card, and either can resume.
    XCTAssertTrue(app.staticTexts["Paused"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts.matching(identifier: "Paused").count, 2)
    app.buttons["Resume"].firstMatch.tap()
    XCTAssertTrue(app.staticTexts["Paused"].waitForNonExistence(timeout: 5))
  }

  func testTheEndCardSplitsAndRematchStartsAgain() {
    app.launchArguments = ["-fresh", "-toured", "-versus", "-win"]
    app.launch()
    let mine = app.staticTexts["verdict1"], theirs = app.staticTexts["verdict2"]
    XCTAssertTrue(mine.waitForExistence(timeout: 25), "no result for Player 1")
    XCTAssertEqual(mine.label, "You win!")
    XCTAssertEqual(theirs.label, "You lose")
    let rematch = app.buttons["rematch"]
    XCTAssertTrue(rematch.isHittable)
    rematch.tap()
    XCTAssertTrue(mine.waitForNonExistence(timeout: 5), "rematch didn't start a new match")
  }
}
