import XCTest
@testable import HingePopCore

final class ChallengeTests: XCTestCase {
  func testEveryLevelGetsThreeValidChallenges() {
    for n in 1...Campaign.finalAuthored {
      let spec = Campaign.level(n)
      let list = Challenges.for(spec)
      XCTAssertEqual(list.count, Challenges.perLevel, "level \(n)")
      XCTAssertEqual(Set(list).count, list.count, "level \(n) repeats a challenge")
      XCTAssertEqual(list, Challenges.for(level: n), "level \(n) isn't deterministic")
      for c in list {
        XCTAssertFalse(c.title.isEmpty)
        XCTAssertLessThanOrEqual(c.title.count, 28, "\"\(c.title)\" is too long for a card")
        XCTAssertFalse(c.symbol.isEmpty)
        if let t = c.twist { XCTAssertTrue(spec.has(t), "level \(n): \(c.title) needs \(t)") }
        XCTAssertEqual(c.bossOnly, c.bossOnly && spec.isBoss, "level \(n): boss challenge on a normal level")
        switch c.goal {
        case .combo(let x): XCTAssertTrue((2...10).contains(x), "level \(n) combo \(x) out of reach")
        case .under(let s): XCTAssertGreaterThanOrEqual(s, 5)
        case .staggers(let k): XCTAssertGreaterThanOrEqual(k, 2)
        default: break
        }
      }
      if spec.isBoss { XCTAssertTrue(list.contains { $0.bossOnly }, "boss level \(n) has no boss challenge") }
    }
  }

  func testTwistChallengesShowUpInTheirWorlds() {
    // Each twist that has its own challenge uses it somewhere in its worlds, and nowhere else.
    var seen: Set<Twist> = []
    for n in 1...Campaign.finalAuthored {
      for c in Challenges.for(level: n) { if let t = c.twist { seen.insert(t) } }
    }
    XCTAssertEqual(seen, [.pulse, .fog, .ghost, .blackout, .regrow, .wind, .portals, .bounce])
    // Worlds without a twist never get one.
    for n in 1...80 where Campaign.level(n).twists.isEmpty {
      XCTAssertTrue(Challenges.for(level: n).allSatisfy { $0.twist == nil }, "level \(n)")
    }
  }

  func testEvaluatorNeedsAClearAndReadsTheRun() {
    var run = RunLog()
    run.won = true
    run.time = 12
    run.bestCombo = 6
    run.bestSnap = 2
    run.bestChain = 3
    let list = [Challenge(goal: .keepShields), Challenge(goal: .combo(6)), Challenge(goal: .under(seconds: 12)),
                Challenge(goal: .snap(3)), Challenge(goal: .chain(3)), Challenge(goal: .nothingCrosses)]
    XCTAssertEqual(Challenges.evaluate(list, run), [true, true, true, false, true, true])
    run.crossings = 1
    run.shieldsLost = 1
    run.time = 12.5
    XCTAssertEqual(Challenges.evaluate(list, run), [false, true, false, false, true, false])
    run.won = false
    XCTAssertEqual(Challenges.evaluate(list, run), Array(repeating: false, count: list.count), "a loss earns nothing")
  }

  func testRunLogReadsEvents() {
    var run = RunLog(gustTime: 3)
    run.note([.crossed(x: 0, y: 0, r: 1, size: 1, player: 0), .gust(dir: 1)], at: 1)
    run.note([.crossed(x: 0, y: 0, r: 1, size: 0, player: 0), .shieldLost(player: 0)], at: 3.5)
    run.note([.crossed(x: 0, y: 0, r: 1, size: 2, player: 0)], at: 4.5)
    run.note([.hingeSnap(along: 0, player: 0, flung: 3), .hingeSnap(along: 0, player: 0, flung: 1)], at: 5)
    run.note([.chainPop(x: 0, y: 0, r: 1, points: 1, count: 1), .chainPop(x: 0, y: 0, r: 1, points: 1, count: 2)], at: 5)
    run.note([.beatPop(x: 0, y: 0, points: 1), .untouchable(x: 0, y: 0, r: 1), .regrow(x: 0, y: 0, r: 1, size: 2)], at: 6)
    run.note([.portal(fromX: 0, fromY: 0, x: 1, y: 1, r: 1), .spring(x: 0, y: 0, r: 1), .spring(x: 0, y: 0, r: 1)], at: 6)
    run.note([.bossStagger(x: 0, y: 0, r: 1, points: 1), .bossBlocked(x: 0, y: 0, r: 1), .bossShielded(x: 0, y: 0, r: 1)], at: 7)
    run.note([.bossSlam(x: 0, y: 0, r: 1, player: 0), .shieldLost(player: 0), .bossSlam(x: 0, y: 0, r: 1, player: 0), .shieldLost(player: 0)], at: 8)
    XCTAssertEqual(run.gustCrossings, 1, "only the crossing inside the gust counts")
    XCTAssertEqual(run.bestSnap, 3)
    XCTAssertEqual(run.bestChain, 2)
    XCTAssertEqual([run.beatPops, run.blindTouches, run.regrows, run.warps, run.springs], [1, 1, 1, 1, 2])
    XCTAssertEqual(run.staggers, 1)
    XCTAssertEqual(run.wastedBossHits, 2)
    XCTAssertEqual(run.causes, [.big, .boss, .boss])
    XCTAssertEqual(run.lossCause, .boss)
    XCTAssertEqual(ShieldCause.big.headline, "A big one got through")
  }

  func testRunLogFromARealGame() {
    let g = Game(mode: .campaign(1), width: 390, height: 760, top: 70, score: 5000)
    var run = RunLog()
    var guardCount = 0
    while g.status == .playing && guardCount < 20_000 {
      g.step(1.0 / 60)
      if g.ready <= 0, let b = g.bubbles.first { g.tap(b) }
      run.note(g.events, at: g.time)
      g.events.removeAll()
      guardCount += 1
    }
    run.close(g, startScore: 5000)
    XCTAssertTrue(run.won)
    XCTAssertEqual(run.score, g.players[0].score - 5000, "the carried score doesn't count")
    XCTAssertGreaterThan(run.bestCombo, 1)
    XCTAssertGreaterThan(run.time, 0)
  }

  func testGradesFollowPar() {
    let spec = Campaign.level(12)
    let par = Par.score(spec)
    XCTAssertGreaterThan(par, 0)
    XCTAssertEqual(par % 100, 0, "par is a round number")
    XCTAssertEqual(Par.grade(score: par, par: par), .s)
    XCTAssertEqual(Par.grade(score: par * 9 / 10, par: par), .a)
    XCTAssertEqual(Par.grade(score: par * 7 / 10, par: par), .b)
    XCTAssertEqual(Par.grade(score: par / 2, par: par), .c)
    XCTAssertEqual(Par.grade(score: 0, par: par), .d)
    XCTAssertTrue(Grade.s > .a && Grade.d < .c)
    XCTAssertEqual(Grade.allCases.map(\.letter), ["D", "C", "B", "A", "S"])
  }

  func testParIsDeterministicAndAboveAPerfectNoComboRun() {
    for n in [1, 9, 10, 45, 81, 125, 400, 799, 800] {
      let spec = Campaign.level(n)
      XCTAssertEqual(Par.score(spec), Par.score(Campaign.level(n)))
      // Tapping every piece at ×1 is nowhere near an S.
      XCTAssertLessThan(Par.grade(score: Int(Par.base(spec)), spec: spec), .b, "level \(n)")
    }
  }

  func testParBossHitsMatchTheGame() {
    for n in stride(from: 10, through: 800, by: 10) {
      let g = Game(mode: .campaign(n), width: 390, height: 760, top: 70)
      XCTAssertEqual(Par.bossHits(g.spec, tuning: g.tuning), g.bossHitsPerPhase, "level \(n)")
    }
  }

  func testNoFranchiseNamesInChallengeCopy() {
    let banned = ["mario", "sonic", "zelda", "pokemon", "pac", "tetris", "marvel", "jedi", "potter", "batman"]
    for n in 1...Campaign.finalAuthored {
      for c in Challenges.for(level: n) {
        for b in banned { XCTAssertFalse(c.title.lowercased().contains(b), c.title) }
      }
    }
    for c in [ShieldCause.big, .medium, .small, .boss] { XCTAssertFalse(c.headline.isEmpty || c.hint.isEmpty) }
  }
}
