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

  func testForcingTheCardNeverRecordsTheVersion() {
    XCTAssertEqual(UpdateNotes.seenAfterClosing(seen: "0.1.1", shown: "0.1.2", forced: false), "0.1.2")
    XCTAssertEqual(UpdateNotes.seenAfterClosing(seen: "0.1.1", shown: "0.1.2", forced: true), "0.1.1", "-whatsNew leaves the gate alone")
    XCTAssertNil(UpdateNotes.seenAfterClosing(seen: nil, shown: "0.1.2", forced: true))
    // So the real update still shows it after a forced look.
    let after = UpdateNotes.seenAfterClosing(seen: "0.1.1", shown: "0.1.2", forced: true)
    XCTAssertTrue(UpdateNotes.shouldShow(seen: after, current: "0.1.2", playedBefore: true))
  }

  func testCalloutsCarryWhereTheyGo() throws {
    let md = """
    # Hinge Pop 9.9: Big Night

    ## Bubble news
    - [book] Read up {guide/duo}
    - [map] See the map {map}
    - [gear] Plain one
    - [bolt] Nowhere real {moon}
    - [star] Fifth is cut {play}
    """
    let n = try XCTUnwrap(UpdateNotes.parse(md, version: "9.9"))
    XCTAssertEqual(n.callouts, [
      .init(symbol: "book", text: "Read up", destination: .guide(section: "duo")),
      .init(symbol: "map", text: "See the map", destination: .map),
      .init(symbol: "gear", text: "Plain one"),
      .init(symbol: "bolt", text: "Nowhere real"),
    ])
    XCTAssertEqual(UpdateNotes.Destination("guide"), .guide(section: nil))
    for (token, place) in [("settings", UpdateNotes.Destination.settings), ("play", .play), ("arcade", .arcade), ("daily", .daily), ("versus", .versus)] {
      XCTAssertEqual(UpdateNotes.Destination(token), place)
    }
    XCTAssertNil(UpdateNotes.Destination("map/extra"))
    XCTAssertNil(UpdateNotes.Destination(""))
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
    // A {destination} in the file that the parser drops is a typo: every tagged line must route somewhere real.
    let tagged = text.components(separatedBy: .newlines).filter { $0.hasPrefix("- [") && $0.hasSuffix("}") }.count
    XCTAssertEqual(n.callouts.filter { $0.destination != nil }.count, min(tagged, n.callouts.count))
    // And a How to play section it names must exist in the guide.
    let screens = try String(contentsOf: ios.appendingPathComponent("HingePop/Screens.swift"), encoding: .utf8)
    for case .guide(let section?)? in n.callouts.map(\.destination) {
      XCTAssertTrue(screens.contains("id: \"\(section)\""), "no How to play section \(section)")
    }
  }
}
