import XCTest
@testable import HingePopCore

final class UpdateNotesTests: XCTestCase {
  func testShowsOncePerVersionAndNeverOnAFreshInstall() {
    XCTAssertFalse(UpdateNotes.shouldShow(seen: nil, current: "0.1.2", playedBefore: false), "fresh install")
    XCTAssertTrue(UpdateNotes.shouldShow(seen: nil, current: "0.1.2", playedBefore: true), "upgrade from before the card existed")
    XCTAssertTrue(UpdateNotes.shouldShow(seen: "0.1.1", current: "0.1.2", playedBefore: true))
    XCTAssertFalse(UpdateNotes.shouldShow(seen: "0.1.2", current: "0.1.2", playedBefore: true), "already seen")
  }

  func testOldSavesLoadWithNothingSeen() throws {
    let old = #"{"unlocked":3,"stars":{},"bestScores":{},"arcadeBest":0,"dailyBest":{},"seenTour":true,"seenVersusTour":false,"taught":[],"flick":true,"hingeGrace":true,"haptics":true}"#
    let p = try JSONDecoder().decode(GameProgress.self, from: Data(old.utf8))
    XCTAssertNil(p.seenNotes)
    XCTAssertTrue(p.playedBefore)
    XCTAssertFalse(GameProgress().playedBefore)
  }

  func testParsesHeadlineCalloutsAndMore() throws {
    let md = """
    # Hinge Pop 9.9: Big Night

    ## Bubble news
    - [star.fill] One
    - [bolt] Two

    ## More
    - Extra

    Here's what to test:
    - Not shown in the app
    """
    let n = try XCTUnwrap(UpdateNotes.parse(md, version: "9.9"))
    XCTAssertEqual(n.headline, "Big Night")
    XCTAssertEqual(n.callouts, [.init(symbol: "star.fill", text: "One"), .init(symbol: "bolt", text: "Two")])
    XCTAssertEqual(n.more, ["Extra"])
    XCTAssertNil(UpdateNotes.parse("# Title only", version: "1"))
  }

  /// Every shipping version needs notes the card can show. The file is the same one TestFlight reads.
  func testTheCurrentVersionHasNotes() throws {
    let ios = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../..").standardized
    let yml = try String(contentsOf: ios.appendingPathComponent("project.yml"), encoding: .utf8)
    let line = try XCTUnwrap(yml.components(separatedBy: .newlines).first { $0.contains("MARKETING_VERSION:") })
    let version = line.components(separatedBy: "\"")[1]
    let text = try String(contentsOf: ios.appendingPathComponent("release-notes/\(version).md"), encoding: .utf8)
    let n = try XCTUnwrap(UpdateNotes.parse(text, version: String(version)))
    XCTAssertTrue((1...4).contains(n.callouts.count))
    XCTAssertTrue(n.callouts.allSatisfy { $0.text.count <= 90 })
  }
}
