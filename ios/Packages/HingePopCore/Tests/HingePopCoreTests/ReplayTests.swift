// Replaying earlier levels: every level a player has reached in an open realm stays playable, through the gates,
// Overdrive and every way a save can load.
import XCTest
@testable import HingePopCore

final class ReplayTests: XCTestCase {
  func cleared(_ range: ClosedRange<Int>, stars: (Int) -> Int, into p: inout GameProgress) {
    for l in range { p.record(level: l, stars: stars(l), score: 100 * l) }
  }
  /// Every level up to `last` opens, and none of them reads as gated.
  func assertReplayable(_ p: GameProgress, through last: Int, _ what: String, line: UInt = #line) {
    for l in 1...last {
      XCTAssertTrue(p.isOpen(l), "\(what): level \(l) should replay", line: line)
      XCTAssertFalse(p.isGated(l), "\(what): level \(l) isn't gated", line: line)
    }
  }
  func roundTrip(_ p: GameProgress) throws -> GameProgress {
    let m = MemorySaveMedium()
    XCTAssertTrue(SaveVault(medium: m).save(p))
    var loaded = SaveVault(medium: m).load().progress
    loaded.adoptGates()
    return loaded
  }

  func testAFreshSaveOpensOnlyLevelOne() {
    var p = GameProgress()
    p.adoptGates()
    XCTAssertTrue(p.isOpen(1))
    XCTAssertFalse(p.isOpen(2))
    XCTAssertFalse(p.isGated(2), "not reached is not gated")
    XCTAssertEqual(p.nextUp, 1)
  }

  func testMidRealmEveryEarlierLevelReplays() throws {
    var p = GameProgress()
    cleared(1...29, stars: { [1, 2, 3][$0 % 3] }, into: &p)
    XCTAssertEqual(p.nextUp, 30)
    assertReplayable(p, through: 30, "mid realm 1")
    assertReplayable(try roundTrip(p), through: 30, "mid realm 1, saved and loaded")
  }

  func testRealmOneClearedShortOfTheGateStillReplaysAllOfIt() throws {
    // Cleared every level of realm 1 with about 90 stars: realm 2's gate (100) isn't met.
    var p = GameProgress()
    cleared(1...80, stars: { $0 % 8 == 0 ? 2 : 1 }, into: &p)
    XCTAssertEqual(p.realmStars(1), 90)
    XCTAssertEqual(p.unlocked, 81)
    XCTAssertTrue(p.isGated(81))
    assertReplayable(p, through: 80, "realm 1 cleared, realm 2 gated")
    XCTAssertTrue((1...80).contains(p.nextUp), "Play sends you back into realm 1 for stars")
    XCTAssertTrue(p.isOpen(p.nextUp))
    let loaded = try roundTrip(p)
    assertReplayable(loaded, through: 80, "gated save, loaded")
    XCTAssertTrue(loaded.isGated(81))
    // Replaying an earlier level for more stars is what opens the gate.
    for l in 1...10 { p.record(level: l, stars: 3, score: 1) }
    XCTAssertTrue(p.isOpen(81))
  }

  func testOverdriveClearsKeepEarlierLevelsOpen() {
    var p = GameProgress()
    p.difficulty = .overdrive
    for l in 1...12 { p.record(level: l, stars: 1, score: 1, grade: .c, earned: [true, false, false], difficulty: .overdrive) }
    assertReplayable(p, through: 13, "Overdrive")
    p.difficulty = .normal
    assertReplayable(p, through: 13, "back on Normal")
  }

  func testAnOldSaveWithoutAGateFloorReplaysEverythingItReached() throws {
    var old = GameProgress()
    cleared(1...130, stars: { _ in 1 }, into: &old)
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
    json["gateFloor"] = nil
    json["saveSchema"] = nil
    let m = MemorySaveMedium()
    m.slots["hinge-pop-progress"] = try JSONSerialization.data(withJSONObject: json)
    var p = SaveVault(medium: m).load().progress
    p.adoptGates()
    assertReplayable(p, through: 131, "pre-gate save")
    // The floor sticks after a save and reload.
    assertReplayable(try roundTrip(p), through: 131, "pre-gate save, saved again")
  }

  func testASalvagedSaveKeepsWhatItReached() throws {
    // A field this build can't read (a newer build's backdrop): the save is salvaged with unlocked, stars and
    // its gate floor intact.
    var json: [String: Any]
    do {
      var old = GameProgress()
      cleared(1...100, stars: { _ in 1 }, into: &old)
      var j = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
      j["gateFloor"] = nil
      var p = try JSONDecoder().decode(GameProgress.self, from: JSONSerialization.data(withJSONObject: j))
      p.adoptGates()
      json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as? [String: Any])
    }
    XCTAssertEqual(json["gateFloor"] as? Int, 101)
    json["arena"] = "nebula"
    let m = MemorySaveMedium()
    m.slots["hinge-pop-progress"] = try JSONSerialization.data(withJSONObject: json)
    let loaded = SaveVault(medium: m).load()
    XCTAssertEqual(loaded.source, .salvaged)
    var p = loaded.progress
    p.adoptGates()
    XCTAssertEqual(p.unlocked, 101)
    XCTAssertEqual(p.totalStars, 100)
    assertReplayable(p, through: 101, "salvaged save")
  }
}
