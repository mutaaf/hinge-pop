import XCTest
@testable import HingePopCore

final class VillainTests: XCTestCase {
  /// A campaign level with nothing on it but one still bubble far from everything, so it can't end by itself.
  private func field(_ level: Int = 50, tuning: Tuning = Tuning()) -> Game {
    let g = Game(mode: .campaign(level), width: 390, height: 760, top: 70, tuning: tuning)
    g.clearScene()
    g.add(.basic, size: 1, x: 40, y: 720, angle: 0, speed: 0)
    return g
  }
  private func has(_ g: Game, _ match: (GameEvent) -> Bool) -> Bool { g.events.contains(where: match) }

  // MARK: Gating and density

  func testVillainsDebutOnTheirLevelsAndOverdriveBringsThemSooner() {
    XCTAssertTrue(Villains.plan(level: 3).isEmpty, "the opening levels have none")
    XCTAssertEqual(Villains.plan(level: 4).pool, [.hex])
    XCTAssertEqual(Villains.plan(level: 4).debut, .hex)
    XCTAssertTrue(Villains.plan(level: 11).pool.contains(.kaiju), "brutes from world 2")
    XCTAssertFalse(Villains.plan(level: 29).pool.contains { $0.tier == .doom }, "no Doom before level 31")
    XCTAssertEqual(Villains.plan(level: 31).debut, .overlord)
    XCTAssertTrue(Villains.plan(level: 45).pool.contains(.void))
    for n in 1...800 {
      let p = Villains.plan(level: n), hot = Villains.plan(level: n, overdrive: true)
      for k in p.pool { XCTAssertLessThanOrEqual(k.debut, n) }
      XCTAssertTrue(Set(p.pool).isSubset(of: Set(hot.pool)) || n % 10 == 0, "Overdrive meets everything Normal does, at \(n)")
      if !p.isEmpty {
        XCTAssertLessThanOrEqual(hot.gap, p.gap, "Overdrive's come more often at \(n)")
        XCTAssertGreaterThan(hot.maxOn, p.maxOn - 1)
      }
      if n % 10 == 0 { XCTAssertFalse(p.pool.contains { $0.tier == .doom }, "a boss fight never rolls a Doom at \(n)") }
    }
    XCTAssertFalse(Villains.plan(level: 2, overdrive: true).isEmpty, "Overdrive's first villain comes sooner")
    XCTAssertLessThan(Villains.plan(level: 703).gap, Villains.plan(level: 43).gap, "they come faster deeper in")
    XCTAssertGreaterThan(Villains.plan(level: 703).maxOn, Villains.plan(level: 43).maxOn)
    XCTAssertNil(Villains.plan(level: 130).summons)
    XCTAssertNotNil(Villains.plan(level: 250).summons, "from realm 3 bosses call villains")
    XCTAssertEqual(Villains.plan(level: 750).summons?.tier, .doom, "the last realms' bosses call a Doom")
    XCTAssertEqual(Campaign.level(31).villains, Villains.plan(level: 31))
    XCTAssertEqual(Campaign.level(31, difficulty: .overdrive).villains, Villains.plan(level: 31, overdrive: true))
  }

  func testTheDebutingVillainComesFirstAndArrivesHarmless() {
    let g = Game(mode: .campaign(31), width: 390, height: 760, top: 70)
    var first: VillainKind?
    for _ in 0..<(60 * 10) where first == nil {
      g.step(1.0 / 60)
      for case .villainArrived(let k, _, _, _) in g.events { first = first ?? k }
      g.events.removeAll()
    }
    XCTAssertEqual(first, .overlord)
    let v = try! XCTUnwrap(g.villains.first)
    XCTAssertFalse(v.solid, "it glows its warning before it can bite")
    XCTAssertFalse(g.strike(v))
    XCTAssertEqual(g.status, .playing)
  }

  func testPracticeAndTheirOwnSwitchHaveNone() {
    var t = Tuning(); t.villains = false
    XCTAssertTrue(Game(mode: .campaign(400), width: 390, height: 760, tuning: t).villainPlan.isEmpty)
    XCTAssertTrue(Game(mode: .sandbox, width: 390, height: 760).villainPlan.isEmpty)
    XCTAssertFalse(Game(mode: .versus, width: 390, height: 760).villainPlan.isEmpty)
    XCTAssertFalse(Game(mode: .arcade(seed: 1), width: 390, height: 760).villainPlan.isEmpty)
  }

  // MARK: Tiers

  func testAMenaceTakesAShieldAndTheCombo() {
    let g = field()
    g.players[0].combo = 4; g.players[0].comboT = 1; g.players[0].streak = 5
    let v = g.summonVillain(.hex)
    XCTAssertTrue(g.strike(v))
    XCTAssertEqual(g.players[0].shields, 2)
    XCTAssertEqual(g.players[0].shieldsLost, 1)
    XCTAssertEqual(g.players[0].combo, 1)
    XCTAssertEqual(g.players[0].streak, 0)
    XCTAssertEqual(g.players[0].villainHits, 1)
    XCTAssertTrue(g.villains.isEmpty)
    XCTAssertTrue(has(g) { if case .villainStruck(.hex, _, _, _, 0, 1) = $0 { true } else { false } })
    XCTAssertEqual(g.status, .playing)
  }

  func testABruteTakesTwoShieldsAndCanFinishYou() {
    let g = field()
    XCTAssertTrue(g.strike(g.summonVillain(.kaiju)))
    XCTAssertEqual(g.players[0].shields, 1)
    XCTAssertEqual(g.status, .playing)
    XCTAssertTrue(g.strike(g.summonVillain(.mimic)))
    XCTAssertEqual(g.status, .lost)
    XCTAssertEqual(g.lostTo, .mimic, "the villain that took the last shield is named")
  }

  func testADoomEndsTheRunOnTheSpot() {
    let g = field()
    XCTAssertTrue(g.strike(g.summonVillain(.overlord)))
    XCTAssertEqual(g.status, .lost)
    XCTAssertEqual(g.lostTo, .overlord)
    XCTAssertEqual(g.players[0].shields, 0)
    XCTAssertTrue(has(g) { if case .villainDoom(.overlord, _, _, _, 0) = $0 { true } else { false } })
    XCTAssertTrue(has(g) { $0 == .finished })
    XCTAssertFalse(g.strike(g.summonVillain(.hex)), "nothing after the end")
    var log = RunLog(); log.note(g.events, at: 1); log.close(g)
    XCTAssertEqual(log.lossCause, .villain)
  }

  func testADoomInTwoPlayerHandsTheRoundToTheOtherPlayer() {
    let g = Game(mode: .versus, width: 390, height: 760, top: 0)
    g.ready = 0
    g.villainsHeld = true
    let far = g.summonVillain(.void, u: 0.5, v: 0.8)
    XCTAssertEqual(far.side, 1)
    XCTAssertTrue(g.strike(far))
    XCTAssertEqual(g.status, .ended)
    XCTAssertEqual(g.winner, 0)
  }

  // MARK: Touching

  func testASwipeThroughAVillainTouchesIt() {
    let g = field()
    g.villainsHeld = true
    let v = g.summonVillain(.hex, u: 0.5, v: 0.3)
    var skip = Set<Int>()
    g.slice(fromX: v.x - 80, fromY: v.y, toX: v.x + 80, toY: v.y, skip: &skip)
    XCTAssertEqual(g.players[0].villainHits, 1)
    XCTAssertEqual(g.players[0].shields, 2)
  }

  func testATouchSquarelyOnABubbleBesideAVillainIsSafe() {
    let g = field()
    g.villainsHeld = true
    let v = g.summonVillain(.hex, u: 0.5, v: 0.3)
    let b = g.add(.basic, size: 1, x: v.x + v.r + 20, y: v.y, angle: 0, speed: 0)
    XCTAssertNil(g.hitVillain(x: b.x, y: b.y), "dead centre on the bubble")
    XCTAssertTrue(g.hitVillain(x: v.x, y: v.y) === v)
    XCTAssertTrue(g.hitVillain(x: v.x - v.r * 0.9, y: v.y) === v, "on the far edge of the villain")
    XCTAssertNil(g.hitVillain(x: v.x + v.r + 30, y: v.y + 200))
  }

  func testAFadedPhantomCantBiteOrBeTouched() {
    let g = field()
    let v = g.summonVillain(.phantom)
    var faded = false
    for _ in 0..<(60 * 5) where !faded { g.step(1.0 / 60); faded = v.presence < 0.5 }
    XCTAssertTrue(faded, "a phantom fades between bites")
    XCTAssertFalse(v.solid)
    XCTAssertNil(g.hitVillain(x: v.x, y: v.y))
    XCTAssertFalse(g.strike(v))
    XCTAssertEqual(g.players[0].shields, 3)
  }

  // MARK: Counterplay

  func testLeftAloneAVillainLeavesWithABonus() {
    var t = Tuning(); t.villainLife = 0.5
    let g = field(tuning: t)
    g.summonVillain(.kaiju)
    let before = g.players[0].score
    for _ in 0..<(60 * 3) { g.step(1.0 / 60) }
    XCTAssertTrue(g.villains.isEmpty)
    XCTAssertEqual(g.players[0].score - before, t.villainDodgePoints[2])
    XCTAssertEqual(g.players[0].villainsDodged, 1)
    XCTAssertEqual(g.players[0].shields, 3)
  }

  func testCrossingTheLineCostsNothingSolo() {
    let g = field()
    let v = g.summonVillain(.hex, u: 0.5, v: 0.45, degrees: 90)
    for _ in 0..<(60 * 3) { g.step(1.0 / 60) }
    XCTAssertNotEqual(v.side, -1, "it drifted over the line")
    XCTAssertEqual(g.players[0].meter, 0)
    XCTAssertEqual(g.players[0].crossings, 0)
  }

  func testInTwoPlayerACrossingVillainBecomesTheOtherPlayersProblem() {
    let g = Game(mode: .versus, width: 390, height: 760, top: 0)
    g.ready = 0
    let v = g.summonVillain(.kaiju, u: 0.5, v: 0.45, degrees: 90)
    XCTAssertEqual(v.side, -1)
    var crossedTo: Int?
    for _ in 0..<(60 * 4) where crossedTo == nil {
      g.step(1.0 / 60)
      for case .villainCrossed(_, _, _, let p) in g.events { crossedTo = p }
      g.events.removeAll()
    }
    XCTAssertEqual(crossedTo, 1)
    // Now only the far player can touch it, and it costs them.
    let touch = (x: v.x, y: v.y)
    g.villainsHeld = true
    XCTAssertTrue(g.hitVillain(x: touch.x, y: touch.y) === v)
    XCTAssertTrue(g.strike(v))
    XCTAssertEqual(g.players[1].shields, 1)
    XCTAssertEqual(g.players[0].shields, 3)
  }

  func testAFreezeShattersVillainsForPoints() {
    let g = field()
    g.addPickup(.freeze, x: 100, y: 600)
    XCTAssertTrue(g.collect(g.pickups[0]))
    let v = g.summonVillain(.overlord)
    XCTAssertTrue(g.strike(v))
    XCTAssertEqual(g.status, .playing, "a frozen Doom shatters")
    XCTAssertEqual(g.players[0].shields, 3)
    XCTAssertEqual(g.players[0].villainsBusted, 1)
    XCTAssertTrue(has(g) { if case .villainBusted(.overlord, _, _, _, let pts, _, .freeze) = $0 { pts >= 1200 } else { false } })
  }

  func testAChainBurstBustsTheVillainsItReaches() {
    let g = field()
    g.villainsHeld = true
    let near = g.summonVillain(.kaiju, u: 0.3, v: 0.3)
    let far = g.summonVillain(.hex, u: 0.95, v: 0.9)
    g.addPickup(.chainBurst, x: near.x + 20, y: near.y)
    XCTAssertTrue(g.collect(g.pickups[0]))
    XCTAssertFalse(g.villains.contains { $0 === near })
    XCTAssertTrue(g.villains.contains { $0 === far })
    XCTAssertEqual(g.players[0].shields, 3)
  }

  func testSnapBustsMenacesAndBrutesAndThrowsADoomBack() {
    let g = field()
    g.villainsHeld = true
    let hex = g.summonVillain(.hex, u: 0.2, v: 0.47)
    let doom = g.summonVillain(.overlord, u: 0.8, v: 0.47)
    let gapBefore = abs((g.vertical ? doom.x : doom.y) - g.hinge)
    XCTAssertTrue(g.snap(along: 100))
    XCTAssertFalse(g.villains.contains { $0 === hex })
    XCTAssertTrue(g.villains.contains { $0 === doom }, "a Doom is too much for a snap")
    XCTAssertGreaterThan(abs((g.vertical ? doom.x : doom.y) - g.hinge), gapBefore)
    XCTAssertTrue(has(g) { if case .villainBusted(.hex, _, _, _, _, _, .snap) = $0 { true } else { false } })
    XCTAssertTrue(has(g) { if case .villainRepelled(.overlord, _, _) = $0 { true } else { false } })
    XCTAssertEqual(g.status, .playing)
  }

  func testACreaseClapBustsEvenADoom() {
    let g = Game(mode: .campaign(50), width: 844, height: 390, top: 60, vertical: true, hinge: 422)
    g.clearScene()
    g.foldPlay = true
    g.add(.basic, size: 1, x: 40, y: 300, angle: 0, speed: 0)
    g.villainsHeld = true
    let doom = g.summonVillain(.void, u: 0.5, v: 0.46)
    XCTAssertTrue(g.clap())
    XCTAssertFalse(g.villains.contains { $0 === doom })
    XCTAssertTrue(has(g) { if case .villainBusted(.void, _, _, _, _, _, .clap) = $0 { true } else { false } })
  }

  func testVillainsNeverBlockAClear() {
    let g = Game(mode: .campaign(60), width: 390, height: 760, top: 70)
    g.ready = 0
    g.summonVillain(.overlord)
    var guardCount = 0
    while let b = g.bubbles.first, g.status == .playing, guardCount < 2000 { g.tap(b); guardCount += 1; if g.bubbles.isEmpty { g.step(1.0 / 60) } }
    for _ in 0..<(60 * 4) where g.status == .playing { g.step(1.0 / 60); while let b = g.bubbles.first, g.status == .playing { g.tap(b) } }
    XCTAssertEqual(g.status, .won)
  }

  func testTheVoidDragsBubblesIn() {
    let g = field()
    g.villainsHeld = true
    let v = g.summonVillain(.void, u: 0.5, v: 0.3)
    g.villainsHeld = false
    let b = g.add(.basic, size: 2, x: v.x + 110, y: v.y, angle: .pi / 2, speed: 0.01)
    let before = hypot(b.x - v.x, b.y - v.y)
    for _ in 0..<20 { g.step(1.0 / 60) }
    XCTAssertLessThan(hypot(b.x - v.x, b.y - v.y), before)
  }

  func testBossesCallVillainsFromRealmThree() {
    let g = Game(mode: .campaign(250), width: 390, height: 760, top: 70)
    g.ready = 0
    let boss = try! XCTUnwrap(g.bubbles.first { $0.kind == .boss })
    var guardCount = 0
    while boss.bossPhase == 0, guardCount < 400 { boss.bossGuard = 0; g.tap(boss); guardCount += 1 }
    XCTAssertTrue(g.villains.contains { $0.kind == g.villainPlan.summons })
  }

  // MARK: Words

  func testVillainsAreOriginal() {
    let banned = ["vader", "sith", "voldemort", "sauron", "godzilla", "kong", "terminator", "skynet", "dalek", "joker", "thanos", "dracula", "maleficent", "ursula", "slimer", "cthulhu", "hal 9000", "marvel", "disney", "pokemon", "nintendo"]
    for k in VillainKind.allCases {
      for line in [k.title, k.tell, k.taunt, k.genre] {
        for word in banned { XCTAssertFalse(line.lowercased().contains(word), line) }
        XCTAssertFalse(line.isEmpty)
      }
      XCTAssertLessThanOrEqual(k.tell.count, 44, "a tell is a glance")
    }
    XCTAssertEqual(Set(VillainKind.allCases.map(\.tier)), Set(VillainTier.allCases))
  }
}
