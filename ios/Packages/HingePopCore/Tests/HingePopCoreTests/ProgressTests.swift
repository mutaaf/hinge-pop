import XCTest
@testable import HingePopCore

final class ProgressTests: XCTestCase {
  /// Clears levels first...last with the same stars each.
  func cleared(_ range: ClosedRange<Int>, stars: Int, into p: inout GameProgress) {
    for l in range { p.record(level: l, stars: stars, score: 100) }
  }

  func testRealmGateNeedsStarsFromThePreviousRealm() {
    var p = GameProgress()
    cleared(1...80, stars: 1, into: &p)
    XCTAssertEqual(p.unlocked, 81)
    XCTAssertEqual(p.realmStars(1), 80)
    XCTAssertFalse(p.realmOpen(2))
    XCTAssertEqual(p.starsShort(2), Gates.starsPerRealm - 80)
    XCTAssertFalse(p.isOpen(81))
    XCTAssertTrue(p.isGated(81))
    XCTAssertTrue(p.isOpen(80))
    // Earning the missing stars back in realm one opens the gate.
    cleared(1...20, stars: 2, into: &p)
    XCTAssertEqual(p.starsShort(2), 0)
    XCTAssertTrue(p.isOpen(81))
    XCTAssertFalse(p.isOpen(82), "levels still open one at a time")
  }

  func testTheGateIsGenerous() {
    // Clearing everything with an average of 1.25 stars is enough; the first realm is free.
    XCTAssertEqual(Gates.stars(toOpen: 1), 0)
    XCTAssertLessThanOrEqual(Gates.starsPerRealm, 80 * 3 / 2)
    var p = GameProgress()
    for l in 1...80 { p.record(level: l, stars: l % 4 == 0 ? 2 : 1, score: 1) }
    XCTAssertEqual(p.starsShort(2), 0)
  }

  func testNextUpPointsAtStarsToWinWhenGated() {
    var p = GameProgress()
    cleared(1...80, stars: 3, into: &p)
    XCTAssertEqual(p.nextUp, 81)
    var q = GameProgress()
    cleared(1...5, stars: 3, into: &q)
    cleared(6...80, stars: 1, into: &q)
    XCTAssertEqual(q.nextUp, 6, "first level in the previous realm with stars left")
  }

  func testOldSavesKeepEveryLevelTheyReached() throws {
    // A save from before gates: no gateFloor key, 120 levels reached with one star each.
    var old = GameProgress()
    cleared(1...119, stars: 1, into: &old)
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
    json.removeValue(forKey: "gateFloor")
    json.removeValue(forKey: "cheered")
    var loaded = try JSONDecoder().decode(GameProgress.self, from: JSONSerialization.data(withJSONObject: json))
    XCTAssertTrue(loaded.isOpen(120), "before adopting, an old save counts as all reached")
    loaded.adoptGates()
    XCTAssertFalse(loaded.realmOpen(2))
    XCTAssertTrue(loaded.isOpen(81))
    XCTAssertTrue(loaded.isOpen(120))
    XCTAssertNil(loaded.pendingCheer, "finished worlds don't party on the first launch after the update")
    // Beyond what it had reached, the gate applies as normal.
    loaded.record(level: 120, stars: 1, score: 1)
    XCTAssertTrue(loaded.isGated(121))
    // Adopting is once only.
    loaded.adoptGates()
    XCTAssertTrue(loaded.isGated(121))
    // And a round trip keeps the floor.
    let again = try JSONDecoder().decode(GameProgress.self, from: JSONEncoder().encode(loaded))
    XCTAssertTrue(again.isOpen(100))
    XCTAssertTrue(again.isGated(121))
  }

  func testFreshPlayersStartGated() {
    var p = GameProgress()
    p.adoptGates()
    XCTAssertTrue(p.isOpen(1))
    XCTAssertFalse(p.isOpen(2))
    p.unlocked = 81
    XCTAssertTrue(p.isGated(81), "a fresh save has no floor past level 1")
  }

  func testCheersComeOnceWorldThenRealm() {
    var p = GameProgress()
    XCTAssertNil(p.pendingCheer)
    cleared(1...9, stars: 3, into: &p)
    XCTAssertNil(p.pendingCheer)
    p.record(level: 10, stars: 1, score: 1)
    XCTAssertEqual(p.pendingCheer, .world(1))
    p.markCheered(.world(1))
    XCTAssertNil(p.pendingCheer)
    cleared(11...80, stars: 2, into: &p)
    XCTAssertEqual(p.pendingCheer, .realm(1), "the realm's moment covers its last world")
    p.markCheered(.realm(1))
    XCTAssertNil(p.pendingCheer)
    XCTAssertEqual(p.worldStars(1), 28)
  }

  func testInfinityOpensAfterLevel800() {
    var p = GameProgress()
    p.unlocked = Campaign.finalAuthored
    XCTAssertEqual(Campaign.finalAuthored, 800)
    XCTAssertFalse(p.infinityOpen)
    p.unlocked = 801
    XCTAssertTrue(p.infinityOpen)
    for l in 1...800 { p.stars[l] = 3 }
    XCTAssertTrue(p.isOpen(801))
  }

  func testEveryBiomeUnlocksSomewhere() {
    var p = GameProgress()
    for a in Arena.allCases { XCTAssertNotNil(p.firstWorld(using: a), "\(a) has no world") }
    XCTAssertTrue(p.arenaOpen(.classic))
    XCTAssertFalse(p.arenaOpen(.candy))
    for l in 1...80 { p.record(level: l, stars: 2, score: 1) }
    XCTAssertTrue(p.arenaOpen(.candy))
    XCTAssertTrue(p.arenaOpen(.magma))
    XCTAssertFalse(p.arenaOpen(.clockwork))
  }
}

final class MasteryProgressTests: XCTestCase {
  func testChallengesAndGradesPersistAndOnlyImprove() throws {
    var p = GameProgress()
    var news = p.record(level: 3, stars: 2, score: 1000, grade: .b, earned: [true, false, false])
    XCTAssertEqual(news.newChallenges, [true, false, false])
    XCTAssertFalse(news.bestGrade, "a first grade isn't a new best")
    XCTAssertTrue(news.bestScore)
    news = p.record(level: 3, stars: 1, score: 500, grade: .c, earned: [true, false, true])
    XCTAssertEqual(news.newChallenges, [false, false, true], "only the new one is news")
    XCTAssertFalse(news.bestGrade)
    XCTAssertFalse(news.bestScore)
    XCTAssertEqual(p.grade(3), .b, "a worse grade doesn't replace a better one")
    XCTAssertEqual(p.challengesDone(3), [true, false, true], "earned challenges stay earned")
    news = p.record(level: 3, stars: 3, score: 2000, grade: .s, earned: [false, false, false])
    XCTAssertTrue(news.bestGrade)
    XCTAssertEqual(p.grade(3), .s)
    XCTAssertEqual(p.stars[3], 3)
    XCTAssertEqual(p.mastery, 2)
    XCTAssertEqual(p.sGrades, 1)
    let back = try JSONDecoder().decode(GameProgress.self, from: JSONEncoder().encode(p))
    XCTAssertEqual(back, p)
    XCTAssertEqual(back.challengesDone(3), [true, false, true])
  }

  func testOldSavesLoadWithoutMastery() throws {
    // A save from before challenges: none of the mastery keys.
    var old = GameProgress()
    for l in 1...30 { old.record(level: l, stars: 2, score: 100) }
    old.trail = "candy"
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
    for k in ["challengeLog", "gradeLog", "trail"] { json.removeValue(forKey: k) }
    XCTAssertNil(json["challengeLog"])
    let loaded = try JSONDecoder().decode(GameProgress.self, from: JSONSerialization.data(withJSONObject: json))
    XCTAssertEqual(loaded.unlocked, 31)
    XCTAssertEqual(loaded.totalStars, 60)
    XCTAssertEqual(loaded.mastery, 0)
    XCTAssertNil(loaded.grade(1))
    XCTAssertNil(loaded.trail)
    XCTAssertTrue(loaded.medals.isEmpty)
  }

  func testAMedalForEveryChallengeInAWorldWinsATrail() {
    var p = GameProgress()
    for l in 81...89 { p.record(level: l, stars: 3, score: 1, grade: .a, earned: [true, true, true]) }
    XCTAssertEqual(p.worldChallenges(9), 27)
    XCTAssertFalse(p.hasMedal(9))
    let news = p.record(level: 90, stars: 3, score: 1, grade: .a, earned: [true, true, true])
    XCTAssertEqual(news.medal, 9)
    XCTAssertEqual(p.medals, [9])
    XCTAssertEqual(p.realmChallenges(2), 30)
    XCTAssertEqual(Trails.won(p), [Worlds.world(9)!.biome])
    XCTAssertNil(Trails.current(p))
    p.trail = Worlds.world(9)!.biome.rawValue
    XCTAssertEqual(Trails.current(p), Worlds.world(9)!.biome)
    p.trail = Arena.magma.rawValue
    XCTAssertNil(Trails.current(p), "a trail not won yet doesn't draw")
    XCTAssertNil(p.record(level: 90, stars: 3, score: 1, grade: .s, earned: [true, true, true]).medal, "a medal is news once")
  }

  func testStarGatesIgnoreChallenges() {
    var p = GameProgress()
    for l in 1...80 { p.record(level: l, stars: 1, score: 1, grade: .s, earned: [true, true, true]) }
    XCTAssertFalse(p.realmOpen(2), "gates stay star-based")
    XCTAssertEqual(p.mastery, 240)
  }
}

final class ArcadeProgressTests: XCTestCase {
  func testCheckpointsEveryFiveWaves() {
    XCTAssertEqual(Arcade.checkpoint(reaching: 0), 1)
    XCTAssertEqual(Arcade.checkpoint(reaching: 4), 1)
    XCTAssertEqual(Arcade.checkpoint(reaching: 5), 5)
    XCTAssertEqual(Arcade.checkpoint(reaching: 14), 10)
    XCTAssertEqual(Arcade.stage(1).name, "Insert Coin")
    XCTAssertEqual(Arcade.stage(10).name, "Boss Rush")
    XCTAssertTrue(Arcade.stage(200).name.hasPrefix("Loop"))
    XCTAssertEqual(Arcade.ladder(best: 12).map(\.wave), [1, 5, 10, 15, 20])
  }

  func testRecordingAnArcadeRun() {
    var p = GameProgress()
    XCTAssertTrue(p.recordArcade(score: 500, wave: 7))
    XCTAssertFalse(p.recordArcade(score: 300, wave: 3))
    XCTAssertEqual(p.arcadeBest, 500)
    XCTAssertEqual(p.arcade.bestWave, 7)
    XCTAssertEqual(p.arcade.runs, 2)
    XCTAssertEqual(p.arcade.lastWave, 3)
    XCTAssertEqual(p.arcade.checkpoint, 5)
  }

  func testOlderSavesLoadWithAnEmptyArcadeLog() throws {
    var old = GameProgress()
    old.arcadeBest = 900
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
    json["arcadeLog"] = nil
    let loaded = try JSONDecoder().decode(GameProgress.self, from: JSONSerialization.data(withJSONObject: json))
    XCTAssertEqual(loaded.arcadeBest, 900)
    XCTAssertEqual(loaded.arcade, ArcadeLog())
  }

  func testContinuingFromACheckpointStartsAtThatWave() {
    let g = Game(mode: .arcade(seed: 3), width: 390, height: 760, top: 70, seed: 3)
    g.continueArcade(from: 10)
    XCTAssertEqual(g.startWave, 10)
    var t = 0.0
    while g.waves < 10 && t < 20 { g.step(1.0 / 60); t += 1.0 / 60 }
    XCTAssertEqual(g.waves, 10, "the first new wave is the checkpoint's")
    let c = Game(mode: .campaign(3), width: 390, height: 760, top: 70, seed: 3)
    c.continueArcade(from: 10)
    XCTAssertEqual(c.startWave, 1, "only arcade continues")
  }
}
