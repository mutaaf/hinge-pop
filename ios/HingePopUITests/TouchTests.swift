import XCTest

/// Real touches, through the same path a person's finger takes. Bubbles are held still and the app reports its
/// state through a hidden probe, so these check that a touch lands where the game thinks it did on each device,
/// including ones with a side safe area.
final class TouchTests: XCTestCase {
  private var app: XCUIApplication!
  override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

  private func launch(_ extra: String...) {
    app.launchArguments = ["-fresh", "-toured", "-still", "-probe"] + extra
    app.launch()
    XCTAssertTrue(app.staticTexts["probe"].waitForExistence(timeout: 20) || app.descendants(matching: .any)["probe"].waitForExistence(timeout: 5))
    Thread.sleep(forTimeInterval: 2)
  }
  private var state: [String: String] {
    let label = app.descendants(matching: .any)["probe"].label
    return Dictionary(uniqueKeysWithValues: label.split(separator: ";").compactMap { pair in
      let kv = pair.split(separator: "="); return kv.count == 2 ? (String(kv[0]), String(kv[1])) : nil
    })
  }
  private func num(_ key: String) -> Double { Double(state[key] ?? "") ?? -1 }
  /// Game coordinates are measured from the safe area's corner, and the app reports where that is.
  private func point(_ x: Double, _ y: Double) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x + num("left"), dy: y + num("top")))
  }
  private func waitFor(_ key: String, atLeast value: Double, _ message: String) {
    let end = Date().addingTimeInterval(4)
    while Date() < end { if num(key) >= value { return }; Thread.sleep(forTimeInterval: 0.1) }
    XCTFail("\(message). Probe: \(app.descendants(matching: .any)["probe"].label)")
  }

  func testTapHitsTheBubbleUnderTheFinger() {
    launch("-level", "1")
    point(num("bx"), num("by")).tap()
    waitFor("taps", atLeast: 1, "A tap on the bubble didn't register")
  }

  func testSwipeSlicesThroughABubble() {
    launch("-level", "1")
    let x = num("bx"), y = num("by")
    point(x - 70, y).press(forDuration: 0.05, thenDragTo: point(x + 70, y))
    waitFor("flicks", atLeast: 1, "A swipe across the bubble didn't slice it")
  }

  func testGuestCanBeCaught() {
    launch("-level", "2", "-cameo", "sirGlowstick")
    let end = Date().addingTimeInterval(8)
    while num("vx") < 0 && Date() < end { Thread.sleep(forTimeInterval: 0.1) }
    point(num("vx"), num("vy")).tap()
    waitFor("cameos", atLeast: 1, "A tap on the guest didn't catch it")
  }

  func testDraggingOffTheLineSnapsIt() {
    launch("-level", "1")
    let vertical = state["vertical"] == "true", hinge = num("hinge")
    // Well away from the bubble, which starts on the near side.
    let from = vertical ? point(hinge, num("h") * 0.9) : point(num("w") * 0.9, hinge)
    let to = vertical ? point(hinge + 90, num("h") * 0.9) : point(num("w") * 0.9, hinge + 90)
    from.press(forDuration: 0.05, thenDragTo: to)
    waitFor("snaps", atLeast: 1, "Dragging off the line didn't snap it")
  }

  func testTappingAWorldsHiddenSpotFindsItsSecret() {
    launch("-level", "1")
    // The Classic world hides its secret in the low bright star, measured on the whole screen like the backdrop.
    let size = app.windows.firstMatch.frame.size
    let w = Double(size.width), h = Double(size.height), u = min(w, h)
    let spot = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: w * 0.14, dy: min(h * 0.92, h - u * 0.1)))
    for _ in 0..<3 { spot.tap(); Thread.sleep(forTimeInterval: 0.25) }
    waitFor("secrets", atLeast: 1, "Three taps on the hidden spot didn't find its secret")
  }
}
