// The sim under random hands: taps, flicks, swipes, snaps, claps, pickups, guests and villain touches, on a sample of
// levels across 1–800 and Infinity, Arcade from several waves, the Daily, Versus, both difficulties, phone and wide
// shapes, and page play. Every frame it checks the invariants the renderer and the end card lean on: finite positions
// and velocities, bounded crowds, meters and shields in range, and that every run ends inside a time cap.
//
// `make core` runs a sample (a few seconds). `HP_FUZZ=heavy` (`make -C ios fuzz`) runs many more levels and seeds.
import XCTest
@testable import HingePopCore

final class FuzzTests: XCTestCase {
  static let heavy = ProcessInfo.processInfo.environment["HP_FUZZ"] == "heavy"
  /// Simulated seconds a run may last before the test calls it stuck. Overtime keeps speeding a campaign level up,
  /// so a player who never clears it still loses well inside this.
  static let cap = 900.0

  struct Shape { let w: Double, h: Double, top: Double }
  static let phone = Shape(w: 390, h: 760, top: 70)
  static let wide = Shape(w: 844, h: 390, top: 65)
  static let pad = Shape(w: 1024, h: 1366, top: 80)

  struct Report { var runs = 0, frames = 0, won = 0, lost = 0, ended = 0, maxBubbles = 0 }

  /// One run under a random hand. `rate` is actions per second; `pages` turns on page play at a fold.
  @discardableResult
  func fuzz(_ mode: GameMode, _ shape: Shape, seed: UInt64, rate: Double = 4, difficulty: Difficulty = .normal,
            pages: Bool = false, arcadeFrom: Int = 1, file: StaticString = #filePath, line: UInt = #line) -> (Game, Int) {
    let g = Game(mode: mode, width: shape.w, height: shape.h, top: shape.top, seed: seed, difficulty: difficulty)
    if arcadeFrom > 1 { g.continueArcade(from: arcadeFrom) }
    if pages { g.foldPlay = true }
    var r = SplitMix(seed: seed &* 0x2545F491 &+ 17)
    var skip = Set<Int>()
    var frames = 0, peak = 0
    let dt = 1.0 / 60
    let what = "\(mode) \(difficulty) seed \(seed)\(pages ? " pages" : "")"
    func point() -> (Double, Double) { (r.unit() * shape.w, shape.top + r.unit() * (shape.h - shape.top)) }
    // One run in four is reckless (it touches villains and swipes blind); the rest defend the line between random
    // moves, so runs last long enough to reach surges, overtime, bosses' later phases and fevers.
    let reckless = seed % 4 == 0
    let across = { (b: Bubble) in abs((g.vertical ? b.x : b.y) - g.hinge) }
    while g.status == .playing && g.time < FuzzTests.cap {
      // A hitch now and then: the app clamps its frame step, but the sim must take any small positive dt.
      let step = r.unit() < 0.01 ? dt * (1 + r.unit() * 5) : dt
      g.step(step)
      frames += 1
      if r.unit() < rate * dt {
        switch r.int(reckless ? 10 : 16) {
        case 10...15:
          // Defend: the touchable bubble nearest the line, with a villain beside it left alone.
          if let b = g.bubbles.filter({ g.canTouch($0) }).min(by: { across($0) < across($1) }), g.hitVillain(x: b.x, y: b.y) == nil {
            g.illuminate(x: b.x, y: b.y)
            g.tap(b, atX: b.x, atY: b.y)
          }
        case 0, 1:
          // A tap aimed at a bubble, sometimes a flick in a random direction.
          if !g.bubbles.isEmpty {
            let b = g.bubbles[r.int(g.bubbles.count)]
            if r.unit() < 0.5 { g.tap(b, atX: b.x, atY: b.y) }
            else { let a = r.unit() * 2 * .pi; g.tap(b, dirX: cos(a), dirY: sin(a), atX: b.x, atY: b.y) }
          }
        case 2:
          // A tap anywhere, as the scene resolves it: villain, pickup, guest, then bubble.
          let (x, y) = point()
          g.illuminate(x: x, y: y)
          if let v = g.hitVillain(x: x, y: y) { if reckless { g.strike(v) } }
          else if let p = g.hitPickup(x: x, y: y) { _ = g.collect(p) }
          else if let v = g.hitVisitor(x: x, y: y) { _ = g.catchVisitor(v.id, owner: g.versus && (g.vertical ? x : y) > g.hinge ? 1 : 0) }
          else if let b = g.hit(x: x, y: y) { g.tap(b, atX: x, atY: y) }
        case 3, 4:
          // A swipe of a few segments, as a stroke arrives in pieces.
          var (x, y) = point()
          skip.removeAll(keepingCapacity: true)
          for _ in 0..<(1 + r.int(5)) {
            let nx = x + (r.unit() - 0.5) * 240, ny = y + (r.unit() - 0.5) * 240
            _ = g.slice(fromX: x, fromY: y, toX: nx, toY: ny, skip: &skip)
            g.illuminate(x: nx, y: ny)
            x = nx; y = ny
          }
        case 5:
          g.snap(along: r.unit() * shape.w, owner: g.versus ? r.int(2) : 0)
        case 6:
          if pages { g.clap() } else { g.snap(along: r.unit() * shape.h) }
        case 7:
          // A touch squarely on a villain (the blind player's mistake).
          if reckless, !g.villains.isEmpty { let v = g.villains[r.int(g.villains.count)]; g.strike(v) }
        case 8:
          if let p = g.pickups.first { _ = g.collect(p) }
        default:
          // Taps that miss, and the odd degenerate point (a resize can briefly hand the scene zero-sized arenas).
          let (x, y) = r.unit() < 0.1 ? (0.0, 0.0) : point()
          _ = g.hit(x: x, y: y); _ = g.hitPickup(x: x, y: y); _ = g.onHinge(x: x, y: y); _ = g.besideCrease(x: x, y: y)
        }
      }
      peak = max(peak, g.bubbles.count)
      if frames % 6 == 0 || g.status != .playing { check(g, what, file: file, line: line) }
      g.events.removeAll(keepingCapacity: true)
    }
    if ProcessInfo.processInfo.environment["HP_FUZZ_LOG"] != nil { print("FUZZ \(what) \(g.status) t=\(Int(g.time)) peak=\(peak) frames=\(frames)") }
    XCTAssertNotEqual(g.status, .playing, "\(what): still playing after \(Int(FuzzTests.cap)) s", file: file, line: line)
    return (g, peak)
  }

  func check(_ g: Game, _ what: String, file: StaticString, line: UInt) {
    func ok(_ v: Double) -> Bool { v.isFinite }
    // Bounds generous enough for anything that bounces off a wall in one frame.
    let slackX = (-g.w)...(2 * g.w), slackY = (-g.h)...(2 * g.h)
    XCTAssertLessThan(g.bubbles.count, 400, "\(what): runaway crowd", file: file, line: line)
    XCTAssertLessThan(g.villains.count, 20, "\(what): runaway villains", file: file, line: line)
    XCTAssertLessThan(g.pickups.count, 50, "\(what)", file: file, line: line)
    XCTAssertLessThan(g.visitors.count, 20, "\(what)", file: file, line: line)
    for b in g.bubbles {
      guard ok(b.x), ok(b.y), ok(b.vx), ok(b.vy), ok(b.r) else {
        XCTFail("\(what): bubble \(b.id) not finite at t=\(g.time): \(b.x),\(b.y) v \(b.vx),\(b.vy) r \(b.r)", file: file, line: line); return
      }
      XCTAssertTrue(slackX.contains(b.x) && slackY.contains(b.y), "\(what): bubble \(b.id) far off the arena at \(b.x),\(b.y)", file: file, line: line)
      XCTAssertGreaterThan(b.r, 0, "\(what)", file: file, line: line)
      XCTAssertTrue((0...3).contains(b.size), "\(what): size \(b.size)", file: file, line: line)
      XCTAssertGreaterThanOrEqual(b.armor, 0, "\(what)", file: file, line: line)
    }
    for v in g.villains {
      XCTAssertTrue(ok(v.x) && ok(v.y) && ok(v.vx) && ok(v.vy) && ok(v.r), "\(what): villain not finite", file: file, line: line)
    }
    for p in g.pickups { XCTAssertTrue(ok(p.x) && ok(p.y), "\(what): pickup not finite", file: file, line: line) }
    for v in g.visitors { XCTAssertTrue(ok(v.x) && ok(v.y), "\(what): guest not finite", file: file, line: line) }
    for p in g.players {
      XCTAssertTrue((0...g.meterMax).contains(p.meter), "\(what): meter \(p.meter)/\(g.meterMax)", file: file, line: line)
      XCTAssertTrue((0...max(g.tuning.shields, 6)).contains(p.shields), "\(what): shields \(p.shields)", file: file, line: line)
      XCTAssertGreaterThanOrEqual(p.score, 0, "\(what): score \(p.score)", file: file, line: line)
      XCTAssertTrue(p.combo.isFinite && p.combo >= 1, "\(what): combo \(p.combo)", file: file, line: line)
      XCTAssertTrue(p.snapLeft.isFinite && p.snapLeft >= -1, "\(what): snap \(p.snapLeft)", file: file, line: line)
      XCTAssertTrue(p.fever.isFinite && p.fever >= 0, "\(what): fever", file: file, line: line)
    }
    XCTAssertTrue(g.time.isFinite && g.hinge.isFinite && g.overtimeSpeed.isFinite && g.wind.isFinite, "\(what): clocks", file: file, line: line)
    XCTAssertGreaterThan(g.meterMax, 0, "\(what)", file: file, line: line)
  }

  // MARK: The sample

  /// Levels from every realm and the shapes of a world: openers, mid-world, ninths, bosses, and Infinity.
  static func levels() -> [Int] {
    if heavy { return Array(stride(from: 1, through: 800, by: 3)) + [801, 802, 809, 810, 850, 999, 1200, 5000] }
    return [1, 2, 3, 5, 9, 10, 14, 31, 45, 77, 80, 99, 150, 236, 310, 400, 469, 555, 640, 719, 790, 799, 800, 801, 810, 1200]
  }

  func testCampaignUnderRandomHands() {
    let seeds: [UInt64] = FuzzTests.heavy ? [1, 2, 3, 4] : [1]
    for n in FuzzTests.levels() {
      for s in seeds {
        for d in [Difficulty.normal, .overdrive] {
          let shape = (Int(s) + n) % 3 == 0 ? FuzzTests.wide : (n % 7 == 0 ? FuzzTests.pad : FuzzTests.phone)
          fuzz(.campaign(n), shape, seed: s &* 7919 &+ UInt64(n), rate: n % 2 == 0 ? 9 : 6, difficulty: d)
        }
      }
    }
  }

  func testPagePlayOnAFold() {
    let levels = FuzzTests.heavy ? Array(stride(from: 2, through: 800, by: 37)) + [801] : [2, 6, 41, 300, 801]
    for n in levels {
      // A book-held Duo: two pages either side of a vertical fold.
      fuzz(.campaign(n), Shape(w: 1398, h: 1000, top: 60), seed: UInt64(n), rate: 5, pages: true)
    }
  }

  func testArcadeFromSeveralWaves() {
    let waves = FuzzTests.heavy ? [1, 5, 10, 20, 35, 50, 80] : [1, 10, 40]
    for w in waves {
      for s in (FuzzTests.heavy ? [1, 2, 3] : [1]) as [UInt64] {
        fuzz(.arcade(seed: s &+ UInt64(w)), FuzzTests.phone, seed: s, rate: 3, arcadeFrom: w)
      }
    }
  }

  func testDailyAndVersus() {
    let days = FuzzTests.heavy ? Array(1...28) : [1, 16, 29]
    for d in days { fuzz(.daily(year: 2026, month: 11 + d % 2, day: min(28, d)), FuzzTests.phone, seed: UInt64(d), rate: 4) }
    let seeds: [UInt64] = FuzzTests.heavy ? Array(1...20) : [1, 2]
    for s in seeds {
      fuzz(.versus, FuzzTests.wide, seed: s, rate: 6)
      fuzz(.versus, FuzzTests.phone, seed: s &+ 100, rate: 6)
    }
  }

  /// Nobody touches anything: every timed mode still ends (the line punishes watching).
  func testIdleRunsEnd() {
    for m in [GameMode.campaign(1), .campaign(400), .campaign(801), .daily(year: 2026, month: 11, day: 18), .versus, .arcade(seed: 3)] {
      fuzz(m, FuzzTests.phone, seed: 9, rate: 0)
    }
  }

  /// Degenerate arenas the scene can briefly hand the sim while a window resizes: tiny and very thin.
  func testOddShapesDontBreakTheSim() {
    for shape in [Shape(w: 120, h: 200, top: 20), Shape(w: 2000, h: 300, top: 40), Shape(w: 320, h: 1800, top: 0)] {
      for m in [GameMode.campaign(3), .campaign(250), .versus, .arcade(seed: 1)] {
        fuzz(m, shape, seed: 5, rate: 5)
      }
    }
  }
}
