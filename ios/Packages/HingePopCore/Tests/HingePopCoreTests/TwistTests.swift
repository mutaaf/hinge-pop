import XCTest
@testable import HingePopCore

/// Every world twist and boss style, on the real campaign levels that use them.
final class TwistTests: XCTestCase {
  /// The third level of the first world whose only twist is `t`: the twist at full strength, no boss.
  func level(_ t: Twist, step: Int = 3) -> Int {
    let w = Worlds.all.first { $0.number > 8 && $0.twists == [t] }!
    return w.levels.lowerBound + step - 1
  }
  func game(_ n: Int, seed: UInt64 = 1) -> Game {
    let g = Game(mode: .campaign(n), width: 390, height: 760, top: 70, seed: seed)
    g.ready = 0
    return g
  }
  /// An empty arena from a twist level, to place bubbles by hand.
  func empty(_ t: Twist) -> Game {
    let g = game(level(t))
    g.clearScene()
    return g
  }
  func run(_ g: Game, _ seconds: Double, hold: [Bubble] = []) {
    for _ in 0..<Int(seconds * 60) {
      g.step(1.0 / 60)
      for b in hold { b.vx = 0; b.vy = 0 }
    }
  }
  /// A bubble at rest on the near side, `gap` points from the hinge (the hinge is horizontal on a phone).
  @discardableResult
  func still(_ g: Game, size: Int = 1, gap: Double = 120, x: Double? = nil, kind: ActorKind = .basic) -> Bubble {
    let b = g.add(kind, size: size, x: x ?? g.w / 2, y: g.hinge - gap, angle: 0)
    b.vx = 0; b.vy = 0
    return b
  }

  // MARK: Twists

  func testEveryTwistHasAWorldThatTeachesItAlone() {
    for t in Twist.allCases { XCTAssertNotNil(Worlds.all.first { $0.number > 8 && $0.twists == [t] }, t.rawValue) }
  }

  func testCurrentWorldsCarryACurrentOthersDont() {
    for w in Worlds.all.dropFirst(8) {
      for n in w.levels { XCTAssertEqual(Campaign.level(n).current > 0, w.twists.contains(.current), "level \(n)") }
    }
  }

  func testWindGustsWarnThenShoveBubblesAcrossLightOnesHardest() {
    let g = empty(.wind)
    XCTAssertEqual(g.wind, 0)
    let light = still(g, size: 2, gap: 200, x: 90), heavy = still(g, size: 0, gap: 200, x: 300)
    let y0 = (light.y, heavy.y)
    g.step(1.0 / 60)
    XCTAssertGreaterThan(g.gustIn, 0, "a calm spell warns before the gust")
    var gusts = 0
    for _ in 0..<(60 * 6) {
      g.step(1.0 / 60)
      for b in [light, heavy] { b.vx = 0; b.vy = 0 }
      gusts += g.events.filter { if case .gust = $0 { return true }; return false }.count
      g.events.removeAll()
      if abs(light.y - y0.0) > 20 { break }
    }
    XCTAssertEqual(gusts, 1)
    XCTAssertNotEqual(g.wind, 0)
    XCTAssertEqual(g.wind > 0, g.windDir > 0, "it blows the way it said")
    XCTAssertGreaterThan(abs(light.y - y0.0), abs(heavy.y - y0.1) * 1.5, "light pieces fly further")
    XCTAssertEqual(abs(light.x - 90), 0, accuracy: 0.001, "wind only blows across the line")
  }

  func testTheTideMovesTheLineAndCanCatchABubbleThatHoldsStill() {
    let g = empty(.tide)
    let base = g.baseHinge
    run(g, g.tuning.tidePeriod / 4)
    XCTAssertGreaterThan(abs(g.tideOffset), 10)
    XCTAssertEqual(g.hinge, base + g.tideOffset, accuracy: 0.001)
    XCTAssertEqual(g.baseHinge, base)
    // A bubble the rising line is moving toward gets crossed without moving at all.
    let g2 = empty(.tide)
    let b = g2.add(.basic, size: 2, x: 200, y: g2.baseHinge + 12, angle: 0)
    b.vx = 0; b.vy = 0
    var crossed = false
    for _ in 0..<(60 * Int(g2.tuning.tidePeriod)) where !crossed {
      g2.step(1.0 / 60); b.vx = 0; b.vy = 0
      crossed = g2.events.contains { if case .crossed = $0 { return true }; return false }
    }
    XCTAssertTrue(crossed)
    XCTAssertEqual(g2.players[0].meter, 1, "a small one still costs its weight")
  }

  func testFogHidesFarBubblesAndHiddenOnesCantBeTouched() {
    let g = empty(.fog)
    let far = still(g, gap: (g.hinge - g.top) * 0.92), near = still(g, gap: 60, x: 100)
    XCTAssertLessThan(g.visibility(far), 0.4)
    XCTAssertEqual(g.visibility(near), 1, accuracy: 0.001)
    XCTAssertFalse(g.tap(far))
    XCTAssertTrue(g.events.contains { if case .untouchable = $0 { return true }; return false })
    XCTAssertEqual(g.players[0].taps, 0, "a touch on nothing isn't a tap")
    XCTAssertTrue(g.tap(near))
    var skip = Set<Int>()
    XCTAssertEqual(g.slice(fromX: far.x - 60, fromY: far.y, toX: far.x + 60, toY: far.y, skip: &skip), 0)
    // Without fog everything is visible.
    XCTAssertEqual(game(5).bubbles.map { game(5).visibility($0) }.min() ?? 1, 1)
  }

  func testGhostsPhaseOutAndBackAndCantBeTouchedOrCrossMeanwhile() {
    let g = empty(.ghost)
    let b = still(g, gap: 150)
    var sawPhase = false, sawBack = false
    for _ in 0..<(60 * 20) {
      g.step(1.0 / 60); b.vx = 0; b.vy = 0
      if b.presence < 0.5 { sawPhase = true; XCTAssertFalse(g.canTouch(b)) }
      if sawPhase && b.presence >= 1 { sawBack = true; break }
    }
    XCTAssertTrue(sawPhase && sawBack)
    // While phased it glances off the line, at no cost.
    for _ in 0..<(60 * 20) where !b.phasing { g.step(1.0 / 60); b.vx = 0; b.vy = 0 }
    for _ in 0..<30 where b.presence >= 0.5 { g.step(1.0 / 60); b.vx = 0; b.vy = 0 }
    XCTAssertLessThan(b.presence, 0.5)
    XCTAssertFalse(g.tap(b))
    b.y = g.hinge - 2; b.vy = 600; b.grace = 0
    g.step(1.0 / 60)
    XCTAssertTrue(g.bubbles.contains { $0 === b })
    XCTAssertEqual(g.players[0].crossings, 0)
    XCTAssertEqual(g.players[0].meter, 0)
    XCTAssertLessThan(b.y, g.hinge)
  }

  func testWellsPullBubblesIntoOrbit() {
    let g = empty(.wells)
    XCTAssertEqual(g.wells.count, g.spec.wells)
    XCTAssertEqual(Campaign.level(level(.wells, step: 1)).wells, 1, "a world's first level has one well")
    let well = g.wells[0]
    XCTAssertLessThan(well.y, g.hinge, "the first well sits on the near side")
    let b = g.add(.basic, size: 2, x: well.x + well.reach * 0.6, y: well.y, angle: 0)
    b.vx = 0; b.vy = 0
    g.step(1.0 / 60)
    XCTAssertLessThan(b.vx, 0, "pulled in")
    XCTAssertNotEqual(b.vy, 0, "and swung round")
    let out = g.add(.basic, size: 2, x: 10, y: g.top + 15, angle: 0)
    out.vx = 0; out.vy = 0
    if hypot(out.x - well.x, out.y - well.y) > well.reach { g.step(1.0 / 60); XCTAssertEqual(hypot(out.vx, out.vy), 0, accuracy: 30) }
  }

  func testPortalsSendABubbleOutOfTheOtherWallFaster() {
    let g = empty(.portals)
    let b = g.add(.basic, size: 1, x: 3, y: g.hinge - 150, angle: .pi)
    let side = b.side, speed = hypot(b.vx, b.vy)
    for _ in 0..<10 where b.x < g.w / 2 { g.step(1.0 / 60) }
    XCTAssertGreaterThan(b.x, g.w / 2, "came out of the far wall")
    XCTAssertEqual(b.side, side, "on the same side of the line")
    XCTAssertGreaterThan(hypot(b.vx, b.vy), speed * 1.1)
    XCTAssertTrue(g.events.contains { if case .portal = $0 { return true }; return false })
    // Walls across the line still bounce.
    let c = g.add(.basic, size: 1, x: 200, y: g.top + 40, angle: -.pi / 2)
    for _ in 0..<20 { g.step(1.0 / 60) }
    XCTAssertGreaterThan(c.y, g.top)
  }

  func testSpringyWallsSpeedBubblesUpToACapThenEaseOff() {
    let g = empty(.bounce)
    let b = g.add(.basic, size: 1, x: 40, y: g.hinge - 150, angle: .pi)
    for _ in 0..<12 { g.step(1.0 / 60) }
    XCTAssertGreaterThan(b.spring, 1)
    XCTAssertTrue(g.events.contains { if case .spring = $0 { return true }; return false })
    for _ in 0..<40 { b.x = 2; b.vx = -200; g.step(1.0 / 60) }
    XCTAssertLessThanOrEqual(b.spring, 1 + (g.tuning.springMax - 1) * min(1.2, g.spec.intensity) + 1e-9)
    let top = b.spring
    b.x = g.w / 2; b.vx = 0; b.vy = 1
    for _ in 0..<60 { g.step(1.0 / 60); b.x = g.w / 2; b.y = g.hinge - 150 }
    XCTAssertLessThan(b.spring, top)
    let calm = game(55)
    XCTAssertTrue(calm.bubbles.allSatisfy { $0.spring == 1 })
  }

  func testUntouchedPiecesGrowBackButNeverToTheBiggest() {
    let g = empty(.regrow)
    let tiny = still(g, size: 3, gap: 200), medium = still(g, size: 1, gap: 200, x: 80)
    let every = g.tuning.regrowTime / g.spec.intensity
    run(g, every * 0.9, hold: [tiny, medium])
    XCTAssertEqual(tiny.size, 3)
    XCTAssertGreaterThan(tiny.regrow, 0.8)
    run(g, every * 0.15, hold: [tiny, medium])
    XCTAssertEqual(tiny.size, 2)
    XCTAssertEqual(tiny.r, g.radius(of: .basic, size: 2), accuracy: 0.001)
    run(g, every * 4, hold: [tiny, medium])
    XCTAssertEqual(tiny.size, 1)
    XCTAssertEqual(medium.size, 1, "medium never grows back to big")
  }

  func testTripleSplitsMakeThreeLighterPieces() {
    let g = empty(.triple)
    let b = still(g, size: 0, gap: 200)
    g.tap(b)
    XCTAssertEqual(g.bubbles.count, 3)
    XCTAssertTrue(g.bubbles.allSatisfy { $0.light && $0.size == 1 })
    XCTAssertEqual(g.crossingCost(size: 1, light: true), g.crossingCost(size: 1) - 1)
    XCTAssertEqual(g.crossingCost(size: 2, light: true), 1, "never below one")
    XCTAssertEqual(g.crossingCost(size: 0, light: true), g.meterMax)
    let piece = g.bubbles[0]
    for o in g.bubbles where o !== piece { o.vx = 0; o.vy = 0; o.y = g.top + 60 }
    piece.grace = 0; piece.x = 200; piece.y = g.hinge - 1; piece.vx = 0; piece.vy = 600
    g.step(1.0 / 60)
    XCTAssertEqual(g.players[0].meter, g.crossingCost(size: 1) - 1)
    // Elsewhere a split still makes two.
    let plain = game(5)
    plain.tap(plain.bubbles[0])
    XCTAssertFalse(plain.bubbles.contains { $0.light })
  }

  func testPulseBeatsAndAPopOnTheBeatScoresDoubleWithAnExtraComboStep() {
    let g = empty(.pulse)
    var beats = 0
    for _ in 0..<Int(60 * g.tuning.beatPeriod * 3.2) {
      g.step(1.0 / 60)
      beats += g.events.filter { if case .beat = $0 { return true }; return false }.count
      g.events.removeAll()
    }
    XCTAssertEqual(beats, 3)
    // Off the beat.
    while g.onBeat { g.step(1.0 / 60) }
    let a = still(g, size: 3, gap: 200, x: 60)
    still(g, size: 0, gap: 200, x: 300)   // keeps the level going, so no clear bonus
    g.tap(a)
    let off = g.players[0].score, offCombo = g.players[0].combo
    XCTAssertEqual(off, g.tuning.points[3])
    // On the beat, with a fresh combo.
    let h = empty(.pulse)
    while !h.onBeat { h.step(1.0 / 60) }
    let b = still(h, size: 3, gap: 200, x: 60)
    still(h, size: 0, gap: 200, x: 300)
    h.tap(b)
    XCTAssertEqual(h.players[0].score, off * 2)
    XCTAssertEqual(h.players[0].combo, offCombo + h.tuning.comboStep)
    XCTAssertTrue(h.events.contains { if case .beatPop = $0 { return true }; return false })
  }

  func testInTheDarkOnlyLitBubblesCanBeTouchedAndATouchLeavesLight() {
    let g = empty(.blackout)
    let far = still(g, gap: (g.hinge - g.top) * 0.8), near = still(g, gap: 40, x: 90)
    g.step(1.0 / 60)
    XCTAssertTrue(g.isLit(near))
    XCTAssertFalse(g.isLit(far))
    XCTAssertFalse(g.tap(far))
    g.illuminate(x: far.x, y: far.y)
    XCTAssertNotNil(g.lantern)
    XCTAssertTrue(g.isLit(far))
    XCTAssertTrue(g.tap(far))
    // The light fades, and what was lit goes dark again a moment later.
    let other = still(g, size: 1, gap: (g.hinge - g.top) * 0.8, x: 330)
    g.illuminate(x: other.x, y: other.y)
    run(g, g.tuning.lanternTime + g.tuning.litTime + 0.2, hold: [other])
    XCTAssertNil(g.lantern)
    XCTAssertFalse(g.isLit(other))
    // Bosses always glow.
    let boss = g.add(.boss, size: 0, x: 200, y: g.top + 100, angle: 0)
    XCTAssertTrue(g.isLit(boss))
  }

  func testTwistsLeaveTheFirstEightWorldsAlone() {
    for n in [5, 25, 45, 75] {
      let g = game(n)
      run(g, 3)
      XCTAssertEqual(g.hinge, g.baseHinge)
      XCTAssertTrue(g.wells.isEmpty)
      XCTAssertEqual(g.wind, 0)
      XCTAssertNil(g.lantern)
      XCTAssertTrue(g.bubbles.allSatisfy { $0.presence == 1 && g.canTouch($0) })
    }
  }

  // MARK: Boss styles

  func bossLevel(_ style: BossStyle) -> Int { Worlds.all.first { $0.number > 8 && $0.boss == style }!.levels.upperBound }
  func bosses(_ g: Game) -> [Bubble] { g.bubbles.filter { $0.kind == .boss } }

  func testEveryBossStyleLeadsAWorld() {
    for s in BossStyle.allCases { XCTAssertEqual(Campaign.level(bossLevel(s)).boss, s) }
  }

  func testTwinsShareOneHealthBarAndFallTogether() {
    let g = game(bossLevel(.twins))
    let pair = bosses(g)
    XCTAssertEqual(pair.count, 2)
    XCTAssertNotEqual(pair[0].side, pair[1].side, "one on each side")
    XCTAssertLessThan(pair[0].r, g.radius(of: .boss, size: 0))
    g.tap(pair[0])
    XCTAssertEqual(pair[1].bossHits, 1)
    XCTAssertGreaterThan(pair[0].bossGuard, 0)
    XCTAssertTrue(g.tap(pair[1]), "the other one isn't guarding")
    XCTAssertEqual(pair[0].bossHits, 2)
    var guardTurns = 0
    while !bosses(g).isEmpty && guardTurns < 2000 {
      for b in bosses(g) { b.bossGuard = 0; b.bossWindup = 0 }
      g.tap(bosses(g)[guardTurns % bosses(g).count])
      guardTurns += 1
    }
    XCTAssertTrue(bosses(g).isEmpty, "both go down together")
    XCTAssertEqual(guardTurns, g.bossHitsPerPhase * g.spec.bossPhases - 2)
  }

  func testAShieldTurnsAsideHitsFromItsSideOnly() {
    let g = game(bossLevel(.shielded))
    let boss = bosses(g)[0]
    let a = boss.shieldAngle
    XCTAssertTrue(g.tap(boss, atX: boss.x + cos(a) * boss.r * 0.8, atY: boss.y + sin(a) * boss.r * 0.8))
    XCTAssertEqual(boss.bossHits, 0)
    XCTAssertTrue(g.events.contains { if case .bossShielded = $0 { return true }; return false })
    XCTAssertTrue(g.tap(boss, atX: boss.x - cos(a) * boss.r * 0.8, atY: boss.y - sin(a) * boss.r * 0.8))
    XCTAssertEqual(boss.bossHits, 1)
    g.step(0.5)
    XCTAssertNotEqual(boss.shieldAngle, a, "it turns")
    XCTAssertFalse(game(bossLevel(.crown)).shieldCovers(bosses(game(bossLevel(.crown)))[0], x: 0, y: 0))
  }

  func phaseOnce(_ g: Game, _ boss: Bubble) {
    for _ in 0..<g.bossHitsPerPhase { boss.bossGuard = 0; boss.bossWindup = 0; g.tap(boss) }
  }

  func testASplitterShedsAFastPieceAndShrinks() {
    let g = game(bossLevel(.splitter))
    let boss = bosses(g)[0], r = boss.r
    let before = g.bubbles.filter { $0.kind == .fast && $0.size == 1 }.count
    phaseOnce(g, boss)
    XCTAssertEqual(boss.bossPhase, 1)
    XCTAssertLessThan(boss.r, r)
    XCTAssertEqual(g.bubbles.filter { $0.kind == .fast && $0.size == 1 }.count, before + 1)
    XCTAssertTrue(g.events.contains { if case .bossSplit = $0 { return true }; return false })
  }

  func testASummonerCallsAWaveOfBasicsFromItsWall() {
    let g = game(bossLevel(.summoner))
    let boss = bosses(g)[0]
    let before = g.bubbles.filter { $0.kind == .basic }.count
    phaseOnce(g, boss)
    let called = g.bubbles.filter { $0.kind == .basic }.count - before
    XCTAssertEqual(called, 3)
    XCTAssertTrue(g.events.contains { if case .bossSummon(_, _, _, 3) = $0 { return true }; return false })
  }

  func testABlinkerTeleportsThenDashesAfterAnEcho() {
    let g = game(bossLevel(.blinker))
    g.clearScene()
    let boss = g.add(.boss, size: 0, x: 200, y: g.top + 90, angle: 0.3)
    var blinked = false
    for _ in 0..<(60 * 8) where !blinked {
      g.step(1.0 / 60)
      blinked = g.events.contains { if case .bossBlink = $0 { return true }; return false }
      g.events.removeAll()
    }
    XCTAssertTrue(blinked)
    XCTAssertFalse(boss.bossDashing, "no dash yet")
    XCTAssertGreaterThan(boss.bossWindup, 0, "a short echo you can still stagger")
    XCTAssertLessThan(boss.y, g.hinge, "still on its own side")
    for _ in 0..<Int(60 * g.tuning.blinkEcho + 2) { g.step(1.0 / 60) }
    XCTAssertTrue(boss.bossDashing || g.players[0].meter > 0)
  }

  func testEveryBossStyleCanBeBeaten() {
    for style in BossStyle.allCases {
      let g = game(bossLevel(style))
      var turns = 0
      while g.status == .playing && turns < 20_000 {
        g.players[0].shields = 3
        for b in g.bubbles {
          b.bossGuard = 0
          if b.kind == .boss { g.tap(b, atX: b.x - cos(b.shieldAngle) * b.r * 0.5, atY: b.y - sin(b.shieldAngle) * b.r * 0.5) } else if g.canTouch(b) { g.tap(b) }
        }
        g.step(1.0 / 60)
        turns += 1
      }
      XCTAssertEqual(g.status, .won, style.rawValue)
    }
  }

  // MARK: The whole campaign

  func testEveryWorldLevelHasABigBubbleOrABossSoWatchingNeverWins() {
    // The hand-built first realm is swept by `hp-balance`; its fast worlds carry no big ones.
    for n in 81...800 {
      let s = Campaign.level(n)
      XCTAssertTrue(s.spawns.contains { $0.size == 0 }, "level \(n)")
      XCTAssertLessThanOrEqual(Campaign.work(of: s.spawns), 95, "level \(n)")
    }
  }

  func testNoTwistLevelCanBeWonWithoutTouching() {
    for w in Worlds.all.dropFirst(8) {
      for k in [1, 5, 9] {
        let n = w.levels.lowerBound + k - 1
        let g = Game(mode: .campaign(n), width: 390, height: 760, top: 70, seed: 2)
        while g.status == .playing && g.time < 90 { g.step(1.0 / 30); g.events.removeAll() }
        XCTAssertNotEqual(g.status, .won, "level \(n) cleared itself")
      }
    }
  }

  func testEachWorldOpensGentlerThanItsNinthLevel() {
    for w in Worlds.all.dropFirst(8) {
      let first = Campaign.level(w.levels.lowerBound), second = Campaign.level(w.levels.lowerBound + 1), ninth = Campaign.level(w.levels.lowerBound + 8)
      XCTAssertLessThan(Campaign.work(of: first.spawns), Campaign.work(of: ninth.spawns), w.name)
      XCTAssertLessThan(Campaign.work(of: second.spawns), Campaign.work(of: ninth.spawns), w.name)
      XCTAssertLessThan(first.intensity, ninth.intensity, w.name)
      XCTAssertLessThanOrEqual(first.speed, ninth.speed, w.name)
      XCTAssertTrue(first.spawns.allSatisfy { $0.kind == .basic }, "\(w.name) teaches its twist with plain bubbles")
      let fifth = Campaign.level(w.levels.lowerBound + 4), sixth = Campaign.level(w.levels.lowerBound + 5)
      XCTAssertGreaterThan(Campaign.work(of: fifth.spawns) + Int(fifth.intensity * 10), Campaign.work(of: sixth.spawns) + Int(sixth.intensity * 10) - 1, "\(w.name) spikes mid-world")
    }
  }

  func testRealmsClimb() {
    func pace(_ realm: Int) -> Double { Campaign.level((realm - 1) * 80 + 23).speed }
    for r in 3...10 { XCTAssertGreaterThanOrEqual(pace(r), pace(r - 1), "realm \(r)") }
    XCTAssertGreaterThan(pace(10), pace(2))
  }

  func testEveryTwistLevelPlaysTheSameTwice() {
    for w in Worlds.all.dropFirst(8) {
      let n = w.levels.lowerBound + 4
      let a = game(n, seed: 3), b = game(n, seed: 3)
      for i in 0..<240 {
        a.step(1.0 / 60); b.step(1.0 / 60)
        if i % 30 == 0, let x = a.bubbles.first, let y = b.bubbles.first { a.tap(x); b.tap(y); a.illuminate(x: 100, y: 300); b.illuminate(x: 100, y: 300) }
      }
      XCTAssertEqual(a.bubbles.map(\.x), b.bubbles.map(\.x), w.name)
      XCTAssertEqual(a.bubbles.map(\.presence), b.bubbles.map(\.presence), w.name)
      XCTAssertEqual(a.players[0].score, b.players[0].score, w.name)
      XCTAssertEqual(a.hinge, b.hinge, w.name)
    }
    XCTAssertEqual(Campaign.level(456), Campaign.level(456))
  }

  func testTurningKeepsWellsAndTheTideInTheArena() {
    let g = game(level(.wells))
    g.resize(width: 760, height: 390, top: 60)
    for well in g.wells {
      XCTAssertTrue((0...760).contains(well.x) && (60...390).contains(well.y))
    }
    let t = game(level(.tide))
    run(t, 2)
    t.resize(width: 760, height: 390, top: 60)
    XCTAssertEqual(t.hinge, t.baseHinge + t.tideOffset, accuracy: 0.001)
    XCTAssertEqual(t.baseHinge, 380)
  }
}
