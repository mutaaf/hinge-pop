import XCTest
@testable import HingePopCore

final class GameTests: XCTestCase {
  func solo(_ level: Int = 1) -> Game { let g = Game(mode: .campaign(level), width: 390, height: 760, top: 70); g.ready = 0; return g }
  func duel() -> Game { let g = Game(mode: .versus, width: 844, height: 390, top: 65); g.ready = 0; return g }
  func sandbox() -> Game { let g = Game(mode: .sandbox, width: 390, height: 760, top: 70); g.ready = 0; return g }

  func send(_ g: Game, _ b: Bubble) {
    b.grace = 0
    for o in g.bubbles where o !== b { o.vx = 0; o.vy = 0 }
    b.vx = 0; b.vy = 0
    if g.vertical { b.x = g.hinge - Double(b.side); b.vx = -Double(b.side) * 600 }
    else { b.y = g.hinge - Double(b.side); b.vy = -Double(b.side) * 600 }
    g.step(1.0 / 60)
  }

  // MARK: Levels

  func testLevelsRampTheWayTheUserAsked() {
    // Just a big one, then one big and one small: the tutorial. From the third there's more to watch, and a surge.
    XCTAssertEqual(Campaign.level(1).spawns.map(\.size), [0])
    XCTAssertEqual(Campaign.level(2).spawns.map(\.size), [0, 2])
    XCTAssertEqual(Campaign.level(3).spawns.map(\.size), [0, 1, 2])
    XCTAssertEqual(Campaign.level(1).surge + Campaign.level(2).surge, 0, "the tutorial has no surge")
    for n in 3...9 { XCTAssertGreaterThan(Campaign.level(n).surge, 0, "level \(n) bites") }
    XCTAssertLessThan(Campaign.level(2).speed, Campaign.level(3).speed)
    XCTAssertEqual(Campaign.level(1).spawns.first?.kind, .basic)
    XCTAssertEqual(Game(mode: .campaign(1), width: 390, height: 760, top: 70).bubbles.count, 1)
    XCTAssertLessThan(Campaign.level(1).speed, Campaign.level(9).speed)
  }

  func testNoLevelAsksForMoreTappingThanAHumanCanDo() {
    var last = 0
    for n in 1...9 {
      let w = Campaign.work(of: Campaign.level(n).spawns)
      XCTAssertGreaterThan(w, last, "level \(n) should ask for a little more")
      last = w
    }
    for n in 1...200 { XCTAssertLessThanOrEqual(Campaign.work(of: Campaign.level(n).spawns), 95, "level \(n)") }
    XCTAssertLessThan(Campaign.work(of: Campaign.level(11).spawns), Campaign.work(of: Campaign.level(9).spawns) + 1, "a new chapter eases back")
  }

  func testSliceHitsEverythingItCrossesOnce() {
    let g = sandbox()
    let a = g.add(.basic, size: 1, x: 80, y: 200, angle: 0, speed: 0), b = g.add(.basic, size: 1, x: 200, y: 200, angle: 0, speed: 0), far = g.add(.basic, size: 1, x: 200, y: 340, angle: 0, speed: 0)
    var skip = Set<Int>()
    XCTAssertEqual(g.slice(fromX: 20, fromY: 200, toX: 300, toY: 200, skip: &skip), 2)
    XCTAssertFalse(g.bubbles.contains { $0 === a || $0 === b })
    XCTAssertTrue(g.bubbles.contains { $0 === far })
    XCTAssertEqual(g.players[0].taps, 2)
    XCTAssertEqual(g.players[0].slices, 1)
    // The pieces are fresh, so the same stroke carrying on doesn't shred them.
    XCTAssertEqual(g.slice(fromX: 20, fromY: 200, toX: 300, toY: 200, skip: &skip), 0)
  }

  func testSliceStaysOnItsOwnSideInVersus() {
    let g = duel()
    g.clearScene()
    let r = g.add(.basic, size: 1, x: g.hinge + 60, y: 200, angle: 0, speed: 0)
    var skip = Set<Int>()
    XCTAssertEqual(g.slice(fromX: g.hinge - 100, fromY: 200, toX: g.hinge + 100, toY: 200, skip: &skip), 0)
    XCTAssertTrue(g.bubbles.contains { $0 === r })
  }

  func testPoppingATinyBubbleSetsOffItsNeighbours() {
    let g = sandbox()
    let a = g.add(.basic, size: 3, x: 100, y: 200, angle: 0, speed: 0)
    g.add(.basic, size: 3, x: 140, y: 200, angle: 0, speed: 0)
    g.add(.basic, size: 3, x: 180, y: 200, angle: 0, speed: 0)
    let big = g.add(.basic, size: 0, x: 200, y: 330, angle: 0, speed: 0), far = g.add(.basic, size: 3, x: 320, y: 320, angle: 0, speed: 0)
    g.tap(a)
    XCTAssertEqual(g.players[0].taps, 1)
    XCTAssertEqual(g.players[0].chained, 2)
    XCTAssertEqual(g.bubbles.count, 2)
    XCTAssertTrue(g.bubbles.contains { $0 === big } && g.bubbles.contains { $0 === far })
  }

  func testEveryChapterMatchesTheSheet() {
    XCTAssertEqual(Campaign.chapters.prefix(8).map(\.title), ["First Contact", "Electric Playground", "Magnetic Storm", "Overload Protocol", "Bosses & Beyond", "Frost Fair", "Coral Drift", "Magma Run"])
    XCTAssertTrue(Campaign.level(12).spawns.contains { $0.kind == .armored })
    XCTAssertTrue(Campaign.level(21).spawns.contains { $0.kind == .magnetic })
    XCTAssertTrue(Campaign.level(23).spawns.contains { $0.kind == .repel })
    XCTAssertGreaterThan(Campaign.level(33).gates, 0)
    for n in [10, 20, 30, 40, 50, 60, 70, 75, 80] { XCTAssertTrue(Campaign.level(n).isBoss, "level \(n)") }
    XCTAssertEqual(Campaign.chapter(of: 80).title, "Magma Run")
    XCTAssertEqual(Campaign.chapter(of: 81).title, "Gumdrop Gulch")
    XCTAssertEqual(Campaign.chapter(of: 800).title, "The Last Second")
    XCTAssertEqual(Campaign.chapter(of: 801).title, "Infinity")
  }

  func testEveryActorKindAppearsInTheCampaign() {
    var seen = Set<ActorKind>()
    for n in 1...50 { Campaign.level(n).spawns.forEach { seen.insert($0.kind) } }
    XCTAssertEqual(seen, Set(ActorKind.allCases))
  }

  func testGeneratedAndDailyLevelsRepeatExactly() {
    XCTAssertEqual(Campaign.level(77), Campaign.level(77))
    XCTAssertEqual(Campaign.daily(year: 2026, month: 11, day: 5), Campaign.daily(year: 2026, month: 11, day: 5))
    let week = (1...7).map { Campaign.daily(year: 2026, month: 11, day: $0).spawns.map(\.kind) }
    XCTAssertGreaterThan(Set(week).count, 1)
  }

  // MARK: Rules carried over from the web game

  func testOneLargeBubbleTakes15TapsAndCleanClearEarnsBonus() {
    var t = Tuning(); t.chainPopRadius = 0
    let g = Game(mode: .campaign(1), width: 390, height: 760, top: 70, tuning: t)
    g.ready = 0
    var taps = 0
    while let b = g.bubbles.first { g.tap(b); taps += 1 }
    XCTAssertEqual(taps, 15)
    XCTAssertEqual(g.status, .won)
    XCTAssertTrue(g.cleanBonus)
    XCTAssertEqual(g.stars, 3)
  }

  func testLargerBubbleOnHingeCostsMeterStreakAndCombo() {
    let g = solo(2)
    g.players[0].streak = 5; g.players[0].combo = 3; g.players[0].comboT = 1
    let before = g.bubbles.count
    send(g, g.bubbles[0])
    XCTAssertEqual(g.players[0].shieldsLost, 1, "a big bubble fills the meter by itself")
    XCTAssertEqual(g.players[0].meter, 0)
    XCTAssertEqual(g.players[0].crossings, 1)
    XCTAssertEqual(g.players[0].streak, 0)
    XCTAssertEqual(g.players[0].combo, 1)
    XCTAssertEqual(g.bubbles.count, before + 1)
  }

  func testSmallestBubbleOnHingeOnlyHelps() {
    let g = sandbox()
    g.players[0].streak = 5; g.players[0].combo = 3; g.players[0].comboT = 1; g.players[0].meter = 2
    let b = g.add(.basic, size: 3, x: 100, y: 200, angle: 0)
    g.add(.basic, size: 0, x: 300, y: 150, angle: 0, speed: 0)
    send(g, b)
    XCTAssertEqual(g.players[0].meter, 2)
    XCTAssertEqual(g.players[0].crossings, 0)
    XCTAssertEqual(g.players[0].zaps, 1)
    XCTAssertEqual(g.players[0].streak, 5)
    XCTAssertEqual(g.players[0].combo, 3)
    XCTAssertEqual(g.players[0].score, 500)
  }

  func testFullStreakRestoresShieldThenClearsMeter() {
    let g = solo(9)
    g.players[0].shields = 2
    for b in g.bubbles { b.vx = 0; b.vy = 0 }
    var taps = 0
    while taps < g.tuning.rechargeStreak, let b = g.bubbles.first(where: { $0.armor == 0 }) { g.tap(b); taps += 1 }
    XCTAssertEqual(g.players[0].shields, 3)
    XCTAssertEqual(g.players[0].recharges, 1)
    g.players[0].meter = 2
    taps = 0
    while taps < g.tuning.rechargeStreak, let b = g.bubbles.first(where: { $0.armor == 0 }) { g.tap(b); taps += 1 }
    XCTAssertEqual(g.players[0].shields, 3)
    XCTAssertEqual(g.players[0].meter, 0)
  }

  func testLastShieldEndsTheLevel() {
    let g = solo(9)
    g.players[0].shields = 1; g.players[0].meter = g.meterMax - 1
    send(g, g.bubbles[0])
    XCTAssertEqual(g.status, .lost)
    XCTAssertEqual(g.stars, 0)
  }

  func testNoLevelStalls() {
    for level in [1, 2, 3] {
      let g = Game(mode: .campaign(level), width: 390, height: 760, top: 70)
      while g.status == .playing && g.time < 200 { g.step(1.0 / 60); g.events.removeAll() }
      XCTAssertNotEqual(g.status, .playing, "level \(level) stalled")
    }
  }

  func testTurningKeepsEveryBubbleOnItsSide() {
    let g = solo(6)
    g.tap(g.bubbles[0])
    let sides = g.bubbles.map(\.side)
    XCTAssertTrue(g.resize(width: 760, height: 390, top: 70))
    XCTAssertTrue(g.vertical)
    XCTAssertEqual(g.bubbles.map(\.side), sides)
    g.step(1.0 / 120)
    XCTAssertEqual(g.players[0].crossings, 0)
  }

  // MARK: Matter

  func testCollisionConservesMomentumAndLighterTakesTheHit() {
    var t = Tuning(); t.recover = [0, 0, 0, 0]
    let g = Game(mode: .sandbox, width: 390, height: 760, top: 70, tuning: t)
    g.ready = 0
    let a = g.add(.basic, size: 0, x: 100, y: 200, angle: 0), b = g.add(.basic, size: 3, x: 100 + g.radius(of: .basic, size: 0) + g.radius(of: .basic, size: 3) + 0.2, y: 200, angle: 0, speed: 0)
    a.vx = 100; a.vy = 0
    let before = t.mass[0] * a.vx + t.mass[3] * b.vx
    g.step(1.0 / 120)
    XCTAssertEqual(t.mass[0] * a.vx + t.mass[3] * b.vx, before, accuracy: 1e-6)
    XCTAssertGreaterThan(b.vx, 150)
    XCTAssertLessThan(100 - a.vx, 30)
  }

  func testStoppedBubblesStayStoppedAndOthersReturnToCruise() {
    let g = sandbox()
    let slow = g.add(.basic, size: 3, x: 100, y: 120, angle: 0), still = g.add(.basic, size: 0, x: 200, y: 640, angle: 0, speed: 0)
    slow.vx = 10; slow.vy = 0
    for _ in 0..<180 { g.step(1.0 / 120) }
    XCTAssertEqual(still.vx, 0)
    XCTAssertGreaterThan(hypot(slow.vx, slow.vy), 60)
  }

  func testHarderFlickLaunchesFaster() {
    func launched(_ len: Double) -> Double {
      let g = sandbox()
      let b = g.add(.basic, size: 0, x: 200, y: 200, angle: 0, speed: 0)
      b.vx = 1
      g.tap(b, dirX: len, dirY: 0)
      return hypot(g.bubbles.last!.vx, g.bubbles.last!.vy)
    }
    XCTAssertGreaterThan(launched(120), launched(20) * 1.4)
  }

  // MARK: Actors

  func testFastAndFrozenHaveTheirOwnSpeed() {
    let g = sandbox()
    let basic = g.add(.basic, size: 0, x: 50, y: 150, angle: 0), fast = g.add(.fast, size: 0, x: 50, y: 250, angle: 0), frozen = g.add(.frozen, size: 0, x: 50, y: 350, angle: 0)
    XCTAssertGreaterThan(fast.vx, basic.vx)
    XCTAssertLessThan(frozen.vx, basic.vx)
  }

  func testFastPiecesStayFastAndOthersTurnBasic() {
    let g = sandbox()
    g.tap(g.add(.fast, size: 0, x: 100, y: 200, angle: 0, speed: 0))
    XCTAssertTrue(g.bubbles.allSatisfy { $0.kind == .fast })
    let h = sandbox()
    h.tap(h.add(.golden, size: 0, x: 100, y: 200, angle: 0))
    XCTAssertTrue(h.bubbles.allSatisfy { $0.kind == .basic })
  }

  func testArmoredTakesTwoHits() {
    let g = sandbox()
    let b = g.add(.armored, size: 0, x: 100, y: 200, angle: 0)
    g.tap(b)
    XCTAssertEqual(g.bubbles.count, 1)
    XCTAssertEqual(b.armor, 0)
    g.tap(b)
    XCTAssertEqual(g.bubbles.count, 2)
    XCTAssertTrue(g.bubbles.allSatisfy { $0.kind == .basic })
  }

  func testGoldenPaysFiveTimes() {
    let g = sandbox()
    g.tap(g.add(.golden, size: 1, x: 100, y: 200, angle: 0))
    XCTAssertEqual(g.players[0].score, g.tuning.points[1] * 5)
  }

  func testMagneticPullsAndRepelPushes() {
    func gap(_ kind: ActorKind) -> Double {
      let g = sandbox()
      let source = g.add(kind, size: 0, x: 195, y: 150, angle: 0, speed: 0)
      let other = g.add(.basic, size: 2, x: 195 + 110, y: 150, angle: 0, speed: 0)
      for _ in 0..<30 { g.step(1.0 / 60) }
      return hypot(source.x - other.x, source.y - other.y)
    }
    XCTAssertLessThan(gap(.magnetic), 110)
    XCTAssertGreaterThan(gap(.repel), 110)
  }

  func testBossCannotCrossChargesTheMeterAndFallsInPhases() {
    let g = Game(mode: .campaign(10), width: 390, height: 760, top: 70)
    g.ready = 0
    guard let boss = g.bubbles.first(where: { $0.kind == .boss }) else { return XCTFail("no boss") }
    let side = boss.side
    send(g, boss)
    XCTAssertEqual(boss.side, side)
    XCTAssertTrue(g.bubbles.contains { $0 === boss })
    XCTAssertEqual(g.players[0].meter, 1)
    let wait = g.tuning.bossGuard + 0.01
    for _ in 0..<g.bossHitsPerPhase { g.step(wait); g.tap(boss) }
    XCTAssertEqual(boss.bossPhase, 1)
    XCTAssertTrue(g.bubbles.contains { $0.kind == .fast })
    for _ in 0..<(g.bossHitsPerPhase * (g.spec.bossPhases - 1)) { g.step(wait); g.tap(boss) }
    XCTAssertFalse(g.bubbles.contains { $0 === boss })
    while let b = g.bubbles.first { g.tap(b) }
    XCTAssertEqual(g.status, .won)
  }

  func testGateLetsLargerBubblesThroughFree() {
    let g = sandbox()
    let b = g.add(.basic, size: 0, x: 195, y: 300, angle: 0)
    g.addGate(at: 195)
    let side = b.side
    send(g, b)
    XCTAssertEqual(g.players[0].crossings, 0)
    XCTAssertEqual(g.players[0].meter, 0)
    XCTAssertEqual(b.side, -side)
    XCTAssertEqual(g.bubbles.count, 1)
  }

  // MARK: Power-ups

  func testOverchargeDoublesScoreAndRisk() {
    let g = sandbox()
    g.addPickup(.overcharge, x: 50, y: 150)
    g.collect(g.pickups[0])
    let b = g.add(.basic, size: 3, x: 100, y: 200, angle: 0)
    g.tap(b)
    XCTAssertEqual(g.players[0].score, 1000)
    let c = g.add(.basic, size: 2, x: 100, y: 200, angle: 0)
    send(g, c)
    XCTAssertEqual(g.players[0].meter, 2)
  }

  func testFreezeSlowsTime() {
    func travel(_ frozen: Bool) -> Double {
      let g = sandbox()
      let b = g.add(.basic, size: 0, x: 60, y: 120, angle: 0)
      if frozen { g.addPickup(.freeze, x: 300, y: 650); g.collect(g.pickups[0]) }
      let start = b.x
      for _ in 0..<30 { g.step(1.0 / 60) }
      return b.x - start
    }
    XCTAssertLessThan(travel(true), travel(false) * 0.5)
  }

  func testFocusPopsSmallBubblesAndShieldCapsAtThree() {
    let g = sandbox()
    g.add(.basic, size: 3, x: 100, y: 150, angle: 0, speed: 0)
    g.add(.basic, size: 3, x: 200, y: 150, angle: 0, speed: 0)
    g.addPickup(.focus, x: 300, y: 650); g.collect(g.pickups[0])
    for _ in 0..<60 { g.step(1.0 / 60) }
    XCTAssertTrue(g.bubbles.isEmpty)
    g.players[0].shields = 3
    g.addPickup(.shield, x: 300, y: 650); g.collect(g.pickups[0])
    XCTAssertEqual(g.players[0].shields, 3)
    g.players[0].shields = 1
    g.addPickup(.shield, x: 300, y: 650); g.collect(g.pickups[0])
    XCTAssertEqual(g.players[0].shields, 2)
  }

  func testChainBurstHitsOnlyWhatIsNearby() {
    let g = sandbox()
    g.add(.basic, size: 3, x: 100, y: 150, angle: 0, speed: 0)
    let far = g.add(.basic, size: 3, x: 320, y: 650, angle: 0, speed: 0)
    g.addPickup(.chainBurst, x: 110, y: 150); g.collect(g.pickups[0])
    XCTAssertEqual(g.bubbles.count, 1)
    XCTAssertTrue(g.bubbles.first === far)
  }

  // MARK: Two players

  func testVersusIsMirroredAndAlwaysVertical() {
    for (w, h) in [(844.0, 390.0), (390.0, 844.0)] {
      let g = Game(mode: .versus, width: w, height: h, top: 65)
      XCTAssertTrue(g.vertical)
      let l = g.bubbles.filter { $0.side < 0 }, r = g.bubbles.filter { $0.side > 0 }
      XCTAssertEqual(l.count, r.count)
      for (a, b) in zip(l, r) {
        XCTAssertEqual(a.x, w - b.x, accuracy: 1e-6)
        XCTAssertEqual(a.y, b.y, accuracy: 1e-6)
        XCTAssertEqual(a.vx, -b.vx, accuracy: 1e-6)
      }
    }
  }

  func testVersusCreditsSidesAndCrossingLandsOnRival() {
    let g = duel()
    g.tap(g.bubbles.first { $0.side > 0 }!)
    XCTAssertEqual(g.players.map(\.taps), [0, 1])
    let right = g.bubbles.filter { $0.side > 0 }.count
    send(g, g.bubbles.first { $0.side < 0 }!)
    XCTAssertEqual(g.players.map(\.shieldsLost), [1, 0])
    XCTAssertEqual(g.bubbles.filter { $0.side > 0 }.count, right + 2)
  }

  func testVersusTouchCannotReachAcross() {
    let g = duel()
    let b = g.bubbles.first { $0.side > 0 }!
    b.x = g.hinge + 4
    XCTAssertFalse(g.hit(x: g.hinge - 4, y: b.y) === b)
    XCTAssertTrue(g.hit(x: g.hinge + 8, y: b.y) === b)
  }

  func testVersusWinners() {
    let g = duel()
    g.players[1].shields = 1; g.players[1].meter = g.meterMax - 1
    send(g, g.bubbles.first { $0.side > 0 }!)
    XCTAssertEqual(g.status, .ended)
    XCTAssertEqual(g.winner, 0)
    let c = duel()
    c.players[1].score = 1_000_000
    while let b = c.bubbles.first { c.tap(b) }
    XCTAssertEqual(c.winner, 1)
  }

  // MARK: Modes

  func testArcadeKeepsSendingWavesUntilShieldsAreGone() {
    let g = Game(mode: .arcade(seed: 3), width: 390, height: 760, top: 70)
    g.ready = 0
    while let b = g.bubbles.first, g.waves == 0 { g.tap(b) }
    XCTAssertEqual(g.status, .playing)
    XCTAssertGreaterThan(g.waves, 0)
    XCTAssertFalse(g.bubbles.isEmpty)
    while g.status == .playing && g.time < 600 { g.step(1.0 / 30); g.events.removeAll() }
    XCTAssertEqual(g.status, .lost)
  }

  func testSameSeedPlaysExactlyTheSame() {
    func run() -> [Double] {
      let g = Game(mode: .daily(year: 2026, month: 11, day: 5), width: 390, height: 760, top: 70)
      for i in 0..<1800 {
        g.step(1.0 / 60)
        if i % 40 == 0, let b = g.bubbles.first { g.tap(b) }
      }
      return g.bubbles.flatMap { [$0.x, $0.y] } + [Double(g.players[0].score)]
    }
    XCTAssertEqual(run(), run())
  }

  // MARK: Progress and the fold

  func testProgressKeepsBestAndUnlocks() throws {
    var p = GameProgress()
    XCTAssertTrue(p.isOpen(1)); XCTAssertFalse(p.isOpen(2))
    p.record(level: 1, stars: 2, score: 500)
    p.record(level: 1, stars: 1, score: 900)
    XCTAssertEqual(p.stars[1], 2); XCTAssertEqual(p.bestScores[1], 900); XCTAssertTrue(p.isOpen(2))
    let back = try JSONDecoder().decode(GameProgress.self, from: JSONEncoder().encode(p))
    XCTAssertEqual(back, p)
    XCTAssertFalse(p.arenaOpen(.forest))
    p.unlocked = 21
    XCTAssertTrue(p.arenaOpen(.forest))
  }

  func testFoldSetsTheHingeWhereTheRealFoldIs() {
    // The Duo as a book: 951 x 669, fold band 455.5 to 495.5, so not the middle of the window.
    let book = FoldLayout.resolve(width: 951, height: 669, top: 60, fold: (455.5, 0, 40, 669), versus: false)
    XCTAssertEqual(book, FoldLayout(vertical: true, hinge: 475.5))
    let g = Game(mode: .campaign(3), width: 951, height: 669, top: 60, vertical: true, hinge: 475.5)
    XCTAssertEqual(g.hinge, 475.5)
    XCTAssertTrue(g.bubbles.contains { $0.side < 0 } && g.bubbles.contains { $0.side > 0 })
    let table = FoldLayout.resolve(width: 669, height: 951, top: 60, fold: (0, 455.5, 669, 40), versus: false)
    XCTAssertEqual(table, FoldLayout(vertical: false, hinge: 475.5))
    XCTAssertNil(FoldLayout.resolve(width: 669, height: 951, top: 60, fold: (0, 455.5, 669, 40), versus: true), "two players stay left and right")
    XCTAssertNil(FoldLayout.resolve(width: 390, height: 844, top: 60, fold: nil, versus: false))
  }

  // MARK: Nobody wins by watching

  func testNoLevelCanBeWonWithoutTouchingTheScreen() {
    // Every level is swept in release by `hp-balance`. This keeps a fast sample in the test suite.
    for n in Array(1...10) + [19, 29, 35, 47, 50, 75] {
      for seed in 1...2 {
        let g = Game(mode: .campaign(n), width: 390, height: 760, top: 70, seed: UInt64(seed))
        while g.status == .playing && g.time < 120 { g.step(1.0 / 30); g.events.removeAll() }
        XCTAssertNotEqual(g.status, .won, "level \(n) seed \(seed) cleared itself")
      }
    }
  }

  func testHeavierBubblesCostMoreToLetThrough() {
    let g = Game(mode: .campaign(1), width: 390, height: 760, top: 70)
    XCTAssertEqual(g.crossingCost(size: 0), g.meterMax)
    XCTAssertEqual(g.crossingCost(size: 1), 2)
    XCTAssertEqual(g.crossingCost(size: 2), 1)
  }

  func testBusyLevelsArriveInStagesAndCantWinEarly() {
    let g = Game(mode: .campaign(47), width: 390, height: 760, top: 70)
    XCTAssertGreaterThan(g.bubblesToCome, 0)
    XCTAssertLessThan(g.bubbles.count, g.spec.spawns.count)
    g.ready = 0
    let waiting = g.bubblesToCome
    for b in g.bubbles { g.tap(b) }
    for _ in 0..<(60 * 12) where g.bubblesToCome == waiting { g.step(1.0 / 60) }
    XCTAssertLessThan(g.bubblesToCome, waiting)
    XCTAssertEqual(g.status, .playing)
  }

  // MARK: Bosses

  private func bossGame(_ n: Int = 10) -> (Game, Bubble) {
    let g = Game(mode: .campaign(n), width: 390, height: 760, top: 70)
    g.ready = 0
    return (g, g.bubbles.first { $0.kind == .boss }!)
  }

  func testBossGuardsAfterAHitSoHammeringDoesNothing() {
    let (g, boss) = bossGame()
    g.tap(boss)
    let hits = boss.bossHits
    for _ in 0..<20 { g.tap(boss) }
    XCTAssertEqual(boss.bossHits, hits)
    XCTAssertTrue(g.events.contains { if case .bossBlocked = $0 { true } else { false } })
  }

  func testBossHitsDoNotFeedTheStreak() {
    let (g, boss) = bossGame()
    g.tap(boss)
    XCTAssertEqual(g.players[0].streak, 0)
    XCTAssertEqual(boss.bossHits, 1)
  }

  func testWindupThenDashCostsAWholeMeterUnlessStaggered() {
    let (g, boss) = bossGame()
    while boss.bossWindup <= 0 && g.time < 30 { g.step(1.0 / 120) }
    XCTAssertGreaterThan(boss.bossWindup, 0)
    let before = g.players[0].shields
    while boss.bossWindup > 0 { g.step(1.0 / 120) }
    XCTAssertTrue(boss.bossDashing)
    while boss.bossDashing && g.time < 60 { g.step(1.0 / 120) }
    XCTAssertLessThan(g.players[0].shields, before)

    let (g2, boss2) = bossGame()
    while boss2.bossWindup <= 0 && g2.time < 30 { g2.step(1.0 / 120) }
    g2.tap(boss2)
    XCTAssertEqual(boss2.bossHits, 2)
    XCTAssertEqual(boss2.bossWindup, 0)
    XCTAssertFalse(boss2.bossDashing)
  }

  func testLaterBossesTakeMoreHits() {
    XCTAssertLessThan(bossGame(10).0.bossHitsPerPhase, bossGame(30).0.bossHitsPerPhase)
  }

  // MARK: Cameos

  private func waitForVisitor(_ g: Game) -> Visitor? {
    g.ready = 0
    while g.visitors.isEmpty && g.time < 40 && g.status == .playing {
      g.step(1.0 / 60)
      for i in g.players.indices { g.players[i].meter = 0; g.players[i].shields = 3 }
    }
    return g.visitors.first
  }

  func testEveryCameoComesAroundAndLevelOneStaysSimple() {
    var seen = Set<Cameo>()
    for n in 2...9 {
      if let v = waitForVisitor(Game(mode: .campaign(n), width: 390, height: 760, top: 70)) { seen.insert(v.cameo) }
    }
    XCTAssertEqual(seen.count, Cameo.allCases.count)
    XCTAssertNil(waitForVisitor(Game(mode: .campaign(1), width: 390, height: 760, top: 70)))
  }

  func testVersusHasNoCameosSoNeitherPlayerGetsLucky() {
    let g = Game(mode: .versus, width: 800, height: 600, top: 70)
    XCTAssertNil(waitForVisitor(g))
  }

  func testCatchingAGuestScoresAndGivesItsGift() {
    let g = Game(mode: .campaign(2), width: 390, height: 760, top: 70)
    let v = waitForVisitor(g)!
    let before = g.players[0].score
    if v.dodgesLeftForTest > 0 { g.catchVisitor(v.id) }
    XCTAssertTrue(g.catchVisitor(v.id))
    XCTAssertTrue(g.visitors.isEmpty)
    XCTAssertGreaterThan(g.players[0].score, before)
    XCTAssertEqual(g.players[0].cameos, 1)
  }

  func testTheChosenFizzDodgesTheFirstTouch() {
    var found: (Game, Visitor)?
    for n in 2...9 {
      let g = Game(mode: .campaign(n), width: 390, height: 760, top: 70)
      if let v = waitForVisitor(g), v.cameo == .chosenFizz { found = (g, v); break }
    }
    let (g, v) = found!
    g.catchVisitor(v.id)
    XCTAssertEqual(g.visitors.count, 1)
    XCTAssertEqual(g.players[0].cameos, 0)
    g.catchVisitor(v.id)
    XCTAssertEqual(g.players[0].cameos, 1)
  }

  func testGuestsNeverBlockAClearOrChargeTheMeter() {
    let g = Game(mode: .campaign(2), width: 390, height: 760, top: 70)
    _ = waitForVisitor(g)
    XCTAssertFalse(g.visitors.isEmpty)
    var guardCount = 0
    while let b = g.bubbles.first, g.status == .playing, guardCount < 500 { g.tap(b); guardCount += 1 }
    XCTAssertEqual(g.status, .won)
  }

  func testGuestsLeaveByThemselves() {
    let g = Game(mode: .campaign(2), width: 390, height: 760, top: 70)
    _ = waitForVisitor(g)
    for _ in 0..<(60 * 9) { g.step(1.0 / 60); g.players[0].meter = 0; g.players[0].shields = 3 }
    XCTAssertTrue(g.visitors.isEmpty)
  }

  func testSoundStartsOffEvenForOldSavesThatStoredItOn() throws {
    XCTAssertFalse(GameProgress().sound)
    let old = try JSONDecoder().decode(GameProgress.self, from: Data(#"{"unlocked":3,"stars":{},"bestScores":{},"arcadeBest":0,"dailyBest":{},"seenTour":true,"seenVersusTour":true,"taught":[],"flick":true,"hingeGrace":true,"sound":true,"haptics":true}"#.utf8))
    XCTAssertFalse(old.sound)
    XCTAssertEqual(old.unlocked, 3)
    var chosen = old
    chosen.sound = true
    let again = try JSONDecoder().decode(GameProgress.self, from: JSONEncoder().encode(chosen))
    XCTAssertTrue(again.sound)
  }

  // MARK: Snap the Hinge

  private func nearLine(_ g: Game, size: Int = 0) -> Bubble {
    let b = g.add(.basic, size: size, x: g.vertical ? g.hinge - 40 : 100, y: g.vertical ? 300 : g.hinge - 40, angle: 0, speed: 0)
    return b
  }

  func testSnapFlingsNearbyBubblesAwayFromTheLine() {
    let g = sandbox()
    let b = nearLine(g)
    XCTAssertTrue(g.snap(along: 100))
    XCTAssertLessThan(g.vertical ? b.vx : b.vy, -100)
    XCTAssertEqual(g.players[0].snaps, 1)
    XCTAssertEqual(g.players[0].meter, 0)
  }

  func testSnapHasACooldownThenTellsYouItsBack() {
    let g = sandbox()
    XCTAssertTrue(g.snap(along: 100))
    XCTAssertFalse(g.snap(along: 100))
    XCTAssertEqual(g.players[0].snaps, 1)
    for _ in 0..<(60 * 8) { g.step(1.0 / 60) }
    XCTAssertTrue(g.events.contains { if case .snapReady = $0 { true } else { false } })
    XCTAssertTrue(g.snap(along: 100))
  }

  func testLighterBubblesFlyHarderAndTinyOnesAreLeftForTheLine() {
    let g = sandbox()
    let big = nearLine(g, size: 0), mid = nearLine(g, size: 2), tiny = nearLine(g, size: 3)
    g.snap(along: 100)
    let v = { (b: Bubble) in abs(g.vertical ? b.vx : b.vy) }
    XCTAssertGreaterThan(v(mid), v(big))
    XCTAssertEqual(v(tiny), 0)
  }

  func testBossesShrugOffASnap() {
    let g = Game(mode: .campaign(10), width: 390, height: 760, top: 70)
    g.ready = 0
    let boss = g.bubbles.first { $0.kind == .boss }!
    let before = (boss.vx, boss.vy)
    g.snap(along: 100)
    XCTAssertEqual(boss.vx, before.0); XCTAssertEqual(boss.vy, before.1)
  }

  func testVersusSnapOnlyMovesYourOwnSide() {
    let g = duel()
    for b in g.bubbles { b.vx = 0; b.vy = 0; b.x = g.hinge + Double(b.side) * 30 }
    g.snap(along: 200, owner: 0)
    XCTAssertTrue(g.bubbles.filter { $0.side < 0 }.allSatisfy { $0.vx < -100 })
    XCTAssertTrue(g.bubbles.filter { $0.side > 0 }.allSatisfy { $0.vx == 0 })
    XCTAssertEqual(g.players[1].snapLeft, 0)
  }

  func testATouchOnTheLineCountsOnlyNearIt() {
    let g = sandbox()
    let on = g.vertical ? (g.hinge + 5, 300.0) : (100.0, g.hinge + 5)
    let off = g.vertical ? (g.hinge + 120, 300.0) : (100.0, g.hinge + 120)
    XCTAssertTrue(g.onHinge(x: on.0, y: on.1))
    XCTAssertFalse(g.onHinge(x: off.0, y: off.1))
  }

  func testSnappingDoesNotLetALevelWinItself() {
    let g = Game(mode: .campaign(1), width: 390, height: 760, top: 70)
    g.ready = 0
    while g.status == .playing && g.time < 120 { g.snap(along: 100); g.step(1.0 / 30); g.events.removeAll() }
    XCTAssertNotEqual(g.status, .won)
  }

  // MARK: iPhone Duo page play

  /// A Duo held like a book: the hinge on the fold, nothing on screen yet.
  private func book(_ tuning: Tuning = Tuning(), level: Int = 5, fold: Bool = true) -> Game {
    let g = Game(mode: .campaign(level), width: 844, height: 390, top: 60, vertical: true, hinge: 422, tuning: tuning)
    g.clearScene()
    g.foldPlay = fold
    return g
  }
  private func still(_ g: Game, page: Int, gap: Double = 160, y: Double = 220, size: Int = 0) -> Bubble {
    g.add(.basic, size: size, x: g.hinge + Double(page) * gap, y: y, angle: 0, speed: 0)
  }
  private func rushed(_ g: Game) -> Int? {
    g.events.lazy.compactMap { if case .rushStart(let side) = $0 { side } else { nil } }.first
  }

  func testTheBusierPageRushesAndScoresDouble() {
    var t = Tuning(); t.rushFirst = 0.05
    let g = book(t)
    let near = still(g, page: -1), far = still(g, page: 1, y: 160)
    _ = still(g, page: 1, y: 300)
    g.step(0.1)
    XCTAssertEqual(rushed(g), 1)
    XCTAssertTrue(g.onRush(far)); XCTAssertFalse(g.onRush(near))
    g.tap(far)
    XCTAssertEqual(g.players[0].score, 200)
  }

  func testRushingBubblesHurry() {
    var t = Tuning(); t.rushFirst = 0.05; t.rushTime = 30
    let g = book(t)
    let near = g.add(.basic, size: 0, x: 120, y: 200, angle: .pi / 2)
    let far = g.add(.basic, size: 0, x: 720, y: 200, angle: .pi / 2)
    let far2 = g.add(.basic, size: 0, x: 720, y: 300, angle: .pi / 2)
    _ = far2
    // Big bubbles swim up to a new speed over a few seconds.
    for _ in 0..<180 { g.step(1.0 / 60) }
    XCTAssertEqual(g.rushSide, 1)
    XCTAssertGreaterThan(hypot(far.vx, far.vy), hypot(near.vx, near.vy) * 1.12)
  }

  func testPagePlayNeedsAFoldAndASoloGame() {
    var t = Tuning(); t.rushFirst = 0.05
    let flat = book(t, fold: false)
    _ = still(flat, page: 1)
    for _ in 0..<30 { flat.step(1.0 / 30) }
    XCTAssertNil(rushed(flat))
    XCTAssertFalse(flat.clap())
    let first = book(t, level: 1)
    _ = still(first, page: 1)
    for _ in 0..<30 { first.step(1.0 / 30) }
    XCTAssertNil(rushed(first), "level 1 stays plain")
    let g = Game(mode: .versus, width: 844, height: 390, top: 60, vertical: true, hinge: 422, tuning: t)
    g.foldPlay = true; g.ready = 0
    for _ in 0..<30 { g.step(1.0 / 30) }
    XCTAssertNil(rushed(g))
    XCTAssertNil(g.besideCrease(x: g.hinge + 20, y: 200))
  }

  func testPoppingAcrossTheCreaseBuildsACrossfold() {
    let g = book()
    let a = still(g, page: -1), b = still(g, page: -1, y: 300), c = still(g, page: 1)
    g.tap(a)
    XCTAssertEqual(g.players[0].combo, 1.5)
    g.tap(b)
    XCTAssertEqual(g.players[0].crossfolds, 0, "same page twice is just a combo")
    g.tap(c)
    XCTAssertEqual(g.players[0].crossfolds, 1)
    XCTAssertEqual(g.players[0].combo, 3.0)
    XCTAssertTrue(g.events.contains { if case .crossfold = $0 { true } else { false } })
  }

  func testACrossfoldNeedsTheComboStillGoing() {
    let g = book()
    let a = still(g, page: -1), c = still(g, page: 1)
    g.tap(a)
    g.step(g.tuning.comboWindow + 0.1)
    g.tap(c)
    XCTAssertEqual(g.players[0].crossfolds, 0)
  }

  func testClappingTheCreaseSweepsFurtherThanASnapAndSharesItsRecharge() {
    let g = book()
    let reachOfSnap = g.tuning.snapReach * g.scale
    let left = still(g, page: -1, gap: reachOfSnap + 30), right = still(g, page: 1, gap: reachOfSnap + 30, y: 300)
    XCTAssertEqual(g.besideCrease(x: g.hinge - 40, y: 200), -1)
    XCTAssertEqual(g.besideCrease(x: g.hinge + 40, y: 200), 1)
    XCTAssertNil(g.besideCrease(x: 20, y: 200))
    XCTAssertTrue(g.clap())
    XCTAssertLessThan(left.vx, -100); XCTAssertGreaterThan(right.vx, 100)
    XCTAssertEqual(g.players[0].claps, 1)
    XCTAssertFalse(g.snap(along: 200), "a clap uses the snap's charge")
    XCTAssertFalse(g.clap())
  }

  func testTheFoldsAngleNeverEntersTheRules() {
    // Page play reads only where the fold is. Two games on the same fold play out identically.
    var t = Tuning(); t.rushFirst = 0.5
    let a = book(t), b = book(t)
    for g in [a, b] { _ = g.add(.basic, size: 0, x: 200, y: 200, angle: 0.7); _ = g.add(.fast, size: 1, x: 600, y: 150, angle: 2.2) }
    for _ in 0..<300 { a.step(1.0 / 60); b.step(1.0 / 60) }
    XCTAssertEqual(a.bubbles.map(\.x), b.bubbles.map(\.x))
    XCTAssertEqual(a.rushSide, b.rushSide)
  }

  // MARK: New worlds

  func testTheNewWorldsEachHaveTheirOwnChapterAndBackdrop() {
    let chapters = Campaign.chapters
    XCTAssertEqual(chapters.map(\.levels.lowerBound), stride(from: 1, through: 791, by: 10).map { $0 })
    XCTAssertEqual(Set(chapters.map(\.arena)), Set(Arena.allCases), "every world gets a chapter")
    for n in 51...60 { XCTAssertEqual(Campaign.level(n).arena, .frost) }
    XCTAssertTrue(Campaign.level(52).spawns.filter { $0.kind == .frozen }.count >= 2)
    XCTAssertEqual(Campaign.level(59).meterMax, 3)
    XCTAssertEqual(Campaign.level(80).bossPhases, 4, "the last world's boss goes one phase longer")
    // Generated levels visit every biome.
    XCTAssertEqual(Set((801...1000).map { Campaign.level($0).arena }), Set(Arena.allCases))
  }

  func testOnlyCoralDriftHasACurrent() {
    for n in 1...80 where !(61...70).contains(n) { XCTAssertEqual(Campaign.level(n).current, 0, "level \(n)") }
    for n in 61...70 { XCTAssertGreaterThan(Campaign.level(n).current, 0, "level \(n)") }
    XCTAssertLessThan(Campaign.level(61).current, Campaign.level(69).current)
  }

  func testTheCurrentCarriesBubblesAlongTheHinge() {
    let g = Game(mode: .campaign(65), width: 390, height: 760, top: 70)
    g.ready = 0
    let b = g.bubbles[0]
    b.vx = 0; b.vy = 0
    let start = g.vertical ? b.y : b.x
    for _ in 0..<60 { g.step(1.0 / 60); b.vx = 0; b.vy = 0 }
    XCTAssertNotEqual(g.vertical ? b.y : b.x, start, accuracy: 5)
    let calm = Game(mode: .campaign(55), width: 390, height: 760, top: 70)
    calm.ready = 0
    let c = calm.bubbles[0]
    c.vx = 0; c.vy = 0
    let from = (c.x, c.y)
    for _ in 0..<60 { calm.step(1.0 / 60); c.vx = 0; c.vy = 0 }
    XCTAssertEqual(c.x, from.0, accuracy: 0.001); XCTAssertEqual(c.y, from.1, accuracy: 0.001)
  }
}

final class WorldsTests: XCTestCase {
  func testEightyWorldsInTenRealmsMakeEightHundredLevels() {
    XCTAssertEqual(Worlds.count, 80)
    XCTAssertEqual(Worlds.realms.count, 10)
    XCTAssertEqual(Campaign.finalAuthored, 800)
    XCTAssertEqual(Set(Worlds.all.map(\.name)).count, 80, "every world has its own name")
    for r in Worlds.realms { XCTAssertEqual(Worlds.all.filter { $0.realm == r.number }.count, 8, r.name) }
  }

  func testEveryWorldAfterTheFirstRealmHasATwistAndEveryTwistAndBossIsUsed() {
    for w in Worlds.all where w.realm > 1 { XCTAssertFalse(w.twists.isEmpty, w.name) }
    XCTAssertEqual(Set(Worlds.all.flatMap(\.twists)), Set(Twist.allCases))
    XCTAssertEqual(Set(Worlds.all.map(\.boss)), Set(BossStyle.allCases))
    XCTAssertEqual(Set(Worlds.all.map(\.biome)), Set(Arena.allCases))
  }

  func testWorldLevelsCarryTheirWorldsRecipe() {
    for w in Worlds.all.dropFirst(8) {
      for n in w.levels {
        let l = Campaign.level(n)
        XCTAssertEqual(l.arena, w.biome); XCTAssertEqual(l.twists, w.twists); XCTAssertEqual(l.variant, w.variant)
        XCTAssertEqual(l.isBoss, n == w.levels.upperBound, "level \(n)")
        if l.isBoss { XCTAssertEqual(l.boss, w.boss) }
      }
    }
    XCTAssertEqual(Campaign.level(456), Campaign.level(456), "the same number always gives the same level")
  }
}
