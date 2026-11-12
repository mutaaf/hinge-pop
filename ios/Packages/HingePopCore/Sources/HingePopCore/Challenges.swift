import Foundation

// Mastery: something to chase on every campaign level, on top of clearing it.
// Each level gets three challenges and a grade. Both come from the level's spec alone, so the same level always
// asks the same things, and both are judged from a `RunLog` the session fills from the game's events.

/// One thing to do on a level, beyond clearing it. Earned once, on a clear.
public struct Challenge: Hashable, Sendable {
  public enum Goal: Hashable, Sendable {
    /// Clear without losing a shield.
    case keepShields
    /// Clear with nothing crossing the line at all.
    case nothingCrosses
    /// Reach this combo at least once.
    case combo(Double)
    /// Clear within this many seconds of play.
    case under(seconds: Int)
    /// One snap of the hinge flings at least this many bubbles.
    case snap(Int)
    /// One chain pop sets off at least this many tiny bubbles.
    case chain(Int)
    /// Pulse worlds: pop this many on the beat.
    case onBeat(Int)
    /// Fog, ghost and blackout worlds: never touch a bubble you can't reach.
    case noBlindTouch(Twist)
    /// Regrow worlds: nothing grows back.
    case noRegrow
    /// Wind worlds: nothing crosses while a gust blows.
    case gustProof
    /// Portal worlds: no more than this many trips through the walls.
    case warps(atMost: Int)
    /// Bounce worlds: no more than this many wall springs.
    case springs(atMost: Int)
    /// Bosses: hit it during its wind-up this many times.
    case staggers(Int)
    /// Bosses: no more than this many hits wasted on its guard (or its shield).
    case cleanHits(atMost: Int)
  }

  public var goal: Goal

  /// A few words for a card. Original copy only.
  public var title: String {
    switch goal {
    case .keepShields: "Keep every shield"
    case .nothingCrosses: "Nothing crosses"
    case .combo(let x): "Hit a ×\(Self.number(x)) combo"
    case .under(let s): "Clear in \(s)s"
    case .snap(let n): "Snap \(n) at once"
    case .chain(let n): "Chain \(n) tinies"
    case .onBeat(let n): "Pop \(n) on the beat"
    case .noBlindTouch(.blackout): "No taps in the dark"
    case .noBlindTouch(.ghost): "Never touch a ghost"
    case .noBlindTouch: "Never touch the fog"
    case .noRegrow: "Let nothing grow back"
    case .gustProof: "Nothing crosses in a gust"
    case .warps(let n): n == 0 ? "No portal trips" : "At most \(n) portal trips"
    case .springs(let n): "At most \(n) wall springs"
    case .staggers(let n): "Stagger it \(n) times"
    case .cleanHits(let n): n == 0 ? "Never hit its guard" : "At most \(n) blocked hits"
    }
  }

  /// An SF Symbol for the challenge's pip.
  public var symbol: String {
    switch goal {
    case .keepShields: "shield.fill"
    case .nothingCrosses: "checkmark.shield.fill"
    case .combo: "flame.fill"
    case .under: "stopwatch.fill"
    case .snap: "bolt.fill"
    case .chain: "link"
    case .onBeat: "metronome.fill"
    case .noBlindTouch(.blackout): "moon.fill"
    case .noBlindTouch(.ghost): "eye.slash.fill"
    case .noBlindTouch: "cloud.fog.fill"
    case .noRegrow: "leaf.fill"
    case .gustProof: "wind"
    case .warps: "arrow.left.arrow.right"
    case .springs: "arrow.up.right.and.arrow.down.left"
    case .staggers: "burst.fill"
    case .cleanHits: "hand.raised.slash.fill"
    }
  }

  /// The world twist this challenge belongs to, when it only makes sense with one.
  public var twist: Twist? {
    switch goal {
    case .onBeat: .pulse
    case .noBlindTouch(let t): t
    case .noRegrow: .regrow
    case .gustProof: .wind
    case .warps: .portals
    case .springs: .bounce
    default: nil
    }
  }

  /// True for the boss-only ones.
  public var bossOnly: Bool {
    switch goal { case .staggers, .cleanHits: true; default: false }
  }

  /// Whether a run earned it. Every challenge needs a clear.
  public func met(by run: RunLog) -> Bool {
    guard run.won else { return false }
    switch goal {
    case .keepShields: return run.shieldsLost == 0
    case .nothingCrosses: return run.crossings == 0
    case .combo(let x): return run.bestCombo >= x - 1e-9
    case .under(let s): return run.time <= Double(s)
    case .snap(let n): return run.bestSnap >= n
    case .chain(let n): return run.bestChain >= n
    case .onBeat(let n): return run.beatPops >= n
    case .noBlindTouch: return run.blindTouches == 0
    case .noRegrow: return run.regrows == 0
    case .gustProof: return run.gustCrossings == 0
    case .warps(let n): return run.warps <= n
    case .springs(let n): return run.springs <= n
    case .staggers(let n): return run.staggers >= n
    case .cleanHits(let n): return run.wastedBossHits <= n
    }
  }

  static func number(_ x: Double) -> String { x == x.rounded() ? String(Int(x)) : String(format: "%.1f", x) }
}

public enum Challenges {
  /// Three per campaign level.
  public static let perLevel = 3
  public static let perWorld = perLevel * 10
  public static let total = perLevel * Campaign.finalAuthored

  public static func `for`(level n: Int) -> [Challenge] { `for`(Campaign.level(n)) }

  /// Three challenges from a level's spec: one about holding the line, one about pace, one about flair.
  /// The flair slot is the world's own when its twist has one.
  public static func `for`(_ spec: LevelSpec) -> [Challenge] {
    let n = max(1, spec.number), k = (n - 1) % 10 + 1
    let work = Campaign.work(of: spec.spawns)
    if spec.isBoss {
      // A stagger a phase and one more; mashing gets blocked, so a steady hand is the third.
      let phases = max(1, spec.bossPhases)
      return [Challenge(goal: .keepShields), Challenge(goal: .staggers(phases + 1)), Challenge(goal: .cleanHits(atMost: phases * 2))]
    }
    // Hold the line: every third level asks for a perfect wall.
    let hold = Challenge(goal: k % 3 == 0 ? .nothingCrosses : .keepShields)
    // Pace: alternate a combo to reach with a clock to beat.
    let pace = Challenge(goal: n % 2 == 1 ? .combo(comboTarget(spec, work: work)) : .under(seconds: parSeconds(spec, work: work)))
    // Flair: the world's twist when it has a challenge of its own, otherwise a snap or a chain.
    let own = spec.twists.compactMap { twistGoal($0, spec: spec, k: k) }
    let flair: Challenge
    if !own.isEmpty {
      flair = Challenge(goal: own[(n / 2) % own.count])
    } else if spec.has(.triple) {
      flair = Challenge(goal: .chain(k >= 6 ? 5 : 4))
    } else if spec.has(.wells) {
      flair = Challenge(goal: .snap(3))
    } else {
      flair = Challenge(goal: k % 2 == 1 ? .chain(3) : .snap(2))
    }
    return [hold, pace, flair]
  }

  /// A twist's own challenge, if it has one.
  static func twistGoal(_ t: Twist, spec: LevelSpec, k: Int) -> Challenge.Goal? {
    switch t {
    case .pulse: .onBeat(3 + k / 3)
    case .fog, .ghost, .blackout: .noBlindTouch(t)
    case .regrow: .noRegrow
    case .wind: .gustProof
    case .portals: .warps(atMost: max(2, Int(0.3 * Double(Campaign.work(of: spec.spawns)))))
    case .bounce: .springs(atMost: max(4, Int(0.45 * Double(Campaign.work(of: spec.spawns)))))
    case .current, .tide, .wells, .triple: nil
    }
  }

  /// A combo to reach, from how much tapping the level holds: a long run of pops with nothing crossing.
  /// Whole steps, ×6 up to the ×10 top.
  static func comboTarget(_ spec: LevelSpec, work: Int) -> Double {
    Double(max(6, min(10, 6 + work / 12)))
  }

  /// A clock to beat, in whole seconds: just under a quarter second per tap the level holds, plus a little to read
  /// it. Fog and the dark hide bubbles until they're close, so they get a few seconds more.
  static func parSeconds(_ spec: LevelSpec, work: Int) -> Int {
    let hidden = spec.has(.fog) || spec.has(.blackout) || spec.has(.ghost) ? 2.0 : 0
    return max(5, Int((1 + 0.24 * Double(work) + hidden).rounded(.up)))
  }

  /// Which of a level's challenges a run earned.
  public static func evaluate(_ list: [Challenge], _ run: RunLog) -> [Bool] { list.map { $0.met(by: run) } }
}

// MARK: - The run

/// What cost a shield.
public enum ShieldCause: String, Sendable, Equatable {
  case big, medium, small, boss
}

/// Everything a challenge, a grade or the losing card needs to know about one run, gathered from `GameEvent`s
/// as they arrive and closed with the game's final state.
public struct RunLog: Equatable, Sendable {
  public var won = false
  /// Seconds of play (the countdown doesn't count).
  public var time = 0.0
  /// This level's own points, without the score carried in.
  public var score = 0
  public var shieldsLost = 0
  public var crossings = 0
  public var bestCombo = 1.0
  public var bestSnap = 0
  public var bestChain = 0
  public var beatPops = 0
  public var blindTouches = 0
  public var regrows = 0
  public var warps = 0
  public var springs = 0
  public var staggers = 0
  public var wastedBossHits = 0
  public var gustCrossings = 0
  /// What cost each shield, in order.
  public var causes: [ShieldCause] = []
  private var gustUntil = -Double.infinity
  private var lastCost: ShieldCause?
  private let gustTime: Double

  public init(gustTime: Double = Tuning().windTime) { self.gustTime = gustTime }

  /// Reads one frame's events. `time` is the game's clock when they happened.
  public mutating func note(_ events: [GameEvent], at time: Double, player: Int = 0) {
    for e in events {
      switch e {
      case .crossed(_, _, _, let size, let p) where p == player:
        lastCost = size == 0 ? .big : size == 1 ? .medium : .small
        if time <= gustUntil { gustCrossings += 1 }
      case .bossSlam(_, _, _, let p) where p == player: lastCost = .boss
      case .shieldLost(let p) where p == player: causes.append(lastCost ?? .small)
      case .hingeSnap(_, let p, let flung) where p == player: bestSnap = max(bestSnap, flung)
      case .creaseClap(let flung): bestSnap = max(bestSnap, flung)
      case .chainPop(_, _, _, _, let count): bestChain = max(bestChain, count)
      case .beatPop: beatPops += 1
      case .untouchable: blindTouches += 1
      case .regrow: regrows += 1
      case .portal: warps += 1
      case .spring: springs += 1
      case .bossStagger: staggers += 1
      case .bossBlocked, .bossShielded: wastedBossHits += 1
      case .gust: gustUntil = time + gustTime
      default: break
      }
    }
  }

  /// Takes the final numbers from the game.
  public mutating func close(_ game: Game, startScore: Int = 0) {
    let p = game.players[0]
    won = game.status == .won
    time = game.time
    score = max(0, p.score - startScore)
    shieldsLost = p.shieldsLost
    crossings = p.crossings
    bestCombo = max(bestCombo, p.bestCombo)
  }

  /// Why a lost run was lost: whatever cost the most shields, the last one breaking a tie.
  public var lossCause: ShieldCause? {
    guard !causes.isEmpty else { return nil }
    var counts: [ShieldCause: Int] = [:]
    for c in causes { counts[c, default: 0] += 1 }
    let most = counts.values.max() ?? 0
    return causes.last { counts[$0] == most }
  }
}

extension ShieldCause {
  /// The losing card's headline: what went wrong, in a few words.
  public var headline: String {
    switch self {
    case .big: "A big one got through"
    case .medium: "Mediums kept slipping over"
    case .small: "Too many smalls slipped by"
    case .boss: "The boss broke through"
    }
  }
  /// And what to try next time.
  public var hint: String {
    switch self {
    case .big: "Split the big ones early."
    case .medium: "Snap the line when they bunch up."
    case .small: "Tap smalls, or split them to tiny."
    case .boss: "Hit it while it glows red."
    }
  }
}

// MARK: - Grades

/// A run's rank, from its score against the level's par. S is rare on purpose.
public enum Grade: Int, Codable, Comparable, CaseIterable, Sendable {
  case d, c, b, a, s
  public static func < (l: Grade, r: Grade) -> Bool { l.rawValue < r.rawValue }
  public var letter: String { ["D", "C", "B", "A", "S"][rawValue] }
  /// The share of par each grade needs.
  public var share: Double { [0, 0.45, 0.65, 0.85, 1.0][rawValue] }
}

public enum Par {
  /// Points a bubble and all its pieces pay at a ×1 combo, if every piece is tapped.
  static func tree(size: Int, kind: ActorKind, triple: Bool, tuning: Tuning) -> Double {
    guard size < 4 else { return 0 }
    var total = 0.0, count = 1.0
    for s in size..<4 {
      var each = Double(tuning.points[s])
      if s == size && kind == .golden { each *= Double(tuning.goldenMultiplier) }
      total += each * count
      count *= triple ? 3 : 2
    }
    if kind == .armored { total += Double(tuning.armorPoints) }
    return total
  }

  /// A level's points at a ×1 combo with every piece tapped, plus a boss's hits and its finishing bonus.
  public static func base(_ spec: LevelSpec, tuning: Tuning = Tuning()) -> Double {
    let triple = spec.has(.triple)
    var total = 0.0
    for s in spec.spawns where s.kind != .boss { total += tree(size: s.size, kind: s.kind, triple: triple, tuning: tuning) }
    if spec.isBoss {
      let hits = Double(max(1, spec.bossPhases) * bossHits(spec, tuning: tuning))
      total += hits * Double(tuning.points[1]) + Double(tuning.points[3] * 4)
    }
    return total
  }

  /// Hits per boss phase: the game's own formula.
  static func bossHits(_ spec: LevelSpec, tuning: Tuning) -> Int { Game.bossHitsPerPhase(spec, tuning: tuning) }

  /// The combo a great run holds on average. Boss hits keep the combo near its top and staggers pay double;
  /// triple splits make many tinies the line takes for free; on the beat pays double.
  public static func multiplier(_ spec: LevelSpec) -> Double {
    if spec.isBoss { return 14 }
    if spec.has(.triple) { return 4 }
    return spec.has(.pulse) ? 6.9 : 5.75
  }

  /// How much more a great run scores by catching fevers (a full combo multiplies points for a while).
  public static let feverShare = 1.45

  /// The score an S needs: every piece tapped at a great run's combo, fevers caught, with the no-crossing bonus.
  public static func score(_ spec: LevelSpec, tuning: Tuning = Tuning()) -> Int {
    Int((base(spec, tuning: tuning) * multiplier(spec) * feverShare * tuning.cleanBonus / 100).rounded()) * 100
  }

  public static func grade(score: Int, par: Int) -> Grade {
    let r = Double(score) / Double(max(1, par))
    return Grade.allCases.reversed().first { r >= $0.share } ?? .d
  }
  public static func grade(score: Int, spec: LevelSpec) -> Grade { grade(score: score, par: Par.score(spec)) }
}

// MARK: - Medal trails

/// A world's medal wins its biome's trail tint: the swipe trail drawn in that biome's colours. Cosmetic only,
/// never sold, and it changes nothing about play.
public enum Trails {
  /// Biomes whose trail is won, in the order their first medalled world comes.
  public static func won(_ p: GameProgress) -> [Arena] {
    var out: [Arena] = []
    for w in p.medals.compactMap({ Worlds.world($0) }) where !out.contains(w.biome) { out.append(w.biome) }
    return out
  }
  /// The trail to draw: the picked one if it's still won, otherwise none.
  public static func current(_ p: GameProgress) -> Arena? {
    guard let id = p.trail, let a = Arena(rawValue: id), won(p).contains(a) else { return nil }
    return a
  }
}
