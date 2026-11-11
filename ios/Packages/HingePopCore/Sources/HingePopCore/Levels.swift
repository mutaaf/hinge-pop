import Foundation

/// The bubble actors from the design sheet.
public enum ActorKind: String, CaseIterable, Sendable, Codable {
  case basic, fast, armored, magnetic, repel, golden, frozen, boss

  /// Multiplies this kind's cruising speed.
  public var speedFactor: Double {
    switch self {
    case .fast: 1.45
    case .frozen: 0.55
    case .boss: 1.1
    case .golden: 1.2
    default: 1
    }
  }
  /// Multiplies this kind's mass.
  public var massFactor: Double {
    switch self {
    case .armored: 1.6
    case .frozen: 1.25
    case .magnetic, .repel: 1.3
    default: 1
    }
  }
  /// What its pieces become when it splits. Only `fast` keeps its nature.
  public var childKind: ActorKind { self == .fast ? .fast : .basic }
}

public enum PowerUp: String, CaseIterable, Sendable, Codable { case overcharge, freeze, focus, shield, chainBurst }

/// Guest stars. Original characters that nod at film and TV genres, each with its own way of moving and its own gift.
public enum Cameo: String, CaseIterable, Sendable, Codable {
  case captainFizz, docFlux, sirGlowstick, chosenFizz, merlinFizz, bigBurp, booBubble, discoDot
}

/// A world's biome: its backdrop art and colours. Worlds reuse biomes with a variant (see `Worlds`).
public enum Arena: String, CaseIterable, Sendable, Codable {
  case classic, neon, forest, space, frost, reef, magma
  case candy, dunes, storm, crystal, haunted, circuit, jungle, clouds, clockwork
}

public struct Spawn: Equatable, Sendable {
  public var kind: ActorKind
  public var size: Int
  public init(_ kind: ActorKind, size: Int = 0) { self.kind = kind; self.size = size }
}

public struct LevelSpec: Equatable, Sendable {
  public var number: Int
  public var chapter: Int
  public var spawns: [Spawn]
  public var speed: Double
  public var meterMax: Int
  public var gates: Int
  public var bossPhases: Int
  public var arena: Arena
  /// Coral Drift: how hard the current pushes everything along the hinge, before scaling. It turns around slowly.
  public var current = 0.0
  /// The world's rules on top of the core ones (see `Twist`). Empty for the first realm, except Coral Drift.
  public var twists: [Twist] = []
  /// How this level's boss fights, when it has one.
  public var boss: BossStyle = .crown
  /// Which take on the biome's art to draw (0 is the original).
  public var variant = 0
  public func has(_ t: Twist) -> Bool { twists.contains(t) }
  public var isBoss: Bool { bossPhases > 0 }
}

public struct Chapter: Sendable, Equatable {
  public var number: Int
  public var title: String
  public var levels: ClosedRange<Int>
  public var teaches: String
  public var arena: Arena
  public var realm = 1
  public var variant = 0
  public var twists: [Twist] = []
  public var boss: BossStyle = .crown
}

public enum Campaign {
  /// One chapter per world (`Worlds.all`): ten levels each.
  public static let chapters: [Chapter] = Worlds.all.map { w in
    Chapter(number: w.number, title: w.name, levels: w.levels, teaches: w.teaches, arena: w.biome, realm: w.realm, variant: w.variant, twists: w.twists, boss: w.boss)
  }
  public static let finalAuthored = Worlds.count * 10

  public static func chapter(of level: Int) -> Chapter {
    chapters.first { $0.levels.contains(level) }
      ?? .init(number: Worlds.count + 1, title: "Infinity", levels: (finalAuthored + 1)...Int.max, teaches: "Generated levels that keep climbing.", arena: Arena.allCases[(level / 10) % Arena.allCases.count])
  }

  /// How many taps a size takes to clear by hand. A level's difficulty is measured in this, not in bubbles:
  /// six large bubbles look like six, but they take 90 taps, which nobody can do.
  public static let work = [15, 7, 3, 1]

  public static func work(of spawns: [Spawn]) -> Int {
    spawns.reduce(0) { total, s in
      if s.kind == .boss { return total + 16 }
      return total + work[s.size] + (s.kind == .armored ? 1 : 0)
    }
  }

  /// Sizes that add up to a budget of work. A big bubble that gets through costs a whole shield, so only two
  /// come at once, and the rest of the budget arrives as lighter pieces that forgive a miss.
  public static func sizes(forWork budget: Int) -> [Int] {
    var left = budget, out: [Int] = []
    for size in 0..<4 {
      let most = size == 0 ? 2 : 7
      var made = 0
      while left >= work[size], out.count < 7, made < most { out.append(size); left -= work[size]; made += 1 }
    }
    return out.isEmpty ? [0] : out
  }

  /// The first chapter, by hand: one big, then one big and one small, then one big and one medium, and on up.
  private static let firstChapter: [[Int]] = [[0], [0, 2], [0, 1], [0, 1, 2], [0, 0], [0, 0, 2], [0, 0, 1], [0, 0, 1, 2], [0, 0, 1, 1, 2]]

  /// The budget climbs slowly inside a chapter, and eases back at each new one so its new bubble gets room.
  private static func budget(chapter: Int, step k: Int) -> Int { min(chapter >= 5 ? 84 : 76, 24 + chapter * 7 + (k - 1) * 3 - (chapter >= 5 ? 10 : 0)) }

  /// Speed barely moves for a long time. Later levels ask for more swiping before they ask for faster hands.
  private static func speed(chapter: Int, step k: Int) -> Double { min(1, 0.5 + 0.06 * Double(chapter) + 0.014 * Double(k - 1)) }

  /// Swaps some of a level's bubbles for special kinds. Fast and golden come in small, since they move quickly.
  private static func dressed(_ sizes: [Int], with kinds: [ActorKind]) -> [Spawn] {
    sizes.enumerated().map { i, size in
      guard i < kinds.count else { return Spawn(.basic, size: size) }
      let kind = kinds[i]
      return Spawn(kind, size: kind == .fast || kind == .golden ? max(size, 1) : size)
    }
  }

  public static func level(_ n: Int) -> LevelSpec {
    let n = max(1, n)
    let ch = chapter(of: n)
    let k = (n - 1) % 10 + 1
    if n > finalAuthored { return generated(n, chapter: ch) }
    if ch.number > 8 { return worldLevel(n, chapter: ch, step: k) }
    let index = ch.number - 1
    let pace = index == 7 ? min(0.94, speed(chapter: index, step: k)) : speed(chapter: index, step: k)
    if k == 10 {
      // Every chapter ends on a boss, with more phases and more company as the game goes on.
      var spawns = [Spawn(.boss)]
      if index >= 1 { spawns.append(Spawn(.fast, size: 2)) }
      if index >= 3 { spawns.append(Spawn(.armored, size: 1)) }
      if index == 5 { spawns.append(Spawn(.frozen, size: 1)) }
      if index == 6 { spawns.append(Spawn(.magnetic, size: 1)) }
      if index >= 7 { spawns.append(Spawn(.fast, size: 2)) }
      var boss = LevelSpec(number: n, chapter: ch.number, spawns: spawns, speed: pace, meterMax: 4, gates: 0, bossPhases: index >= 7 ? 4 : 3, arena: ch.arena)
      if index == 6 { boss.current = 50 }
      return boss
    }
    if index == 0 {
      let sizes = firstChapter[k - 1]
      var kinds: [ActorKind] = []
      if k >= 6 { kinds = Array(repeating: .basic, count: sizes.count - 1) + [.fast] }
      if k >= 8 { kinds[2] = .golden }
      return LevelSpec(number: n, chapter: 1, spawns: dressed(sizes, with: kinds), speed: pace, meterMax: 4, gates: 0, bossPhases: 0, arena: ch.arena)
    }
    // Magma's fast bubbles do the work extra bubbles would, so it brings a few less.
    let sizes = Campaign.sizes(forWork: index == 7 ? min(58, budget(chapter: index, step: k) - 12) : budget(chapter: index, step: k))
    var kinds: [ActorKind]
    var meter = 4, gates = 0
    switch index {
    case 1:
      kinds = k <= 2 ? [.armored] : k <= 4 ? [.armored, .basic, .frozen] : [.armored, .frozen, .armored]
      if k >= 8 { meter = 3 }
    case 2:
      kinds = k <= 2 ? [.magnetic] : k <= 4 ? [.repel] : k <= 7 ? [.magnetic, .repel] : [.magnetic, .repel, .golden]
    case 3:
      gates = k >= 6 ? 2 : 1
      let pool: [ActorKind] = [.armored, .fast, .magnetic, .repel, .frozen, .golden]
      kinds = (0..<min(sizes.count, 2 + k / 3)).map { pool[($0 + k) % pool.count] }
    case 4:
      gates = k % 3 == 0 ? 1 : 0
      let pool: [ActorKind] = [.fast, .armored, .repel, .magnetic, .golden, .frozen]
      kinds = (0..<min(sizes.count, 3 + k / 3)).map { pool[($0 + k * 2) % pool.count] }
    case 5:
      // Frost Fair: heavy frozen crowds, then armor joins them and the meter shortens.
      kinds = k <= 3 ? [.frozen, .basic, .frozen] : k <= 6 ? [.frozen, .armored, .basic, .frozen] : [.armored, .frozen, .basic, .frozen, .golden]
      if k == 9 { meter = 3 }
    case 6:
      // Coral Drift: the current, with magnets and repellers stirring it up, then gates to thread.
      let pool: [ActorKind] = [.magnetic, .basic, .repel, .basic, .golden, .frozen]
      kinds = (0..<min(sizes.count, 2 + k / 3)).map { pool[($0 + k) % pool.count] }
      gates = k >= 6 ? 1 : 0
    default:
      // Magma Run: fast and golden, no gates. Its pace stops short of full speed, since fast bubbles add their own.
      let pool: [ActorKind] = [.fast, .golden, .basic, .armored, .fast, .basic]
      kinds = (0..<min(sizes.count, 2 + k / 3)).map { pool[($0 + k) % pool.count] }
    }
    // Chapters three to five run a shorter meter in their back half. The later worlds set their own.
    if (2...4).contains(index) && k >= 6 { meter = 3 }
    var spawns = dressed(sizes, with: kinds)
    var phases = 0
    if (index == 4 || index == 7) && k == 5 {
      spawns = [Spawn(.boss), Spawn(.fast, size: 2), Spawn(.fast, size: 2)]
      phases = 3
    }
    var spec = LevelSpec(number: n, chapter: ch.number, spawns: spawns, speed: pace, meterMax: meter, gates: gates, bossPhases: phases, arena: ch.arena)
    if index == 6 { spec.current = 30 + 4 * Double(k); spec.twists = [.current] }
    return spec
  }

  /// Levels for worlds 9–80, from the world's recipe: the same number always gives the same level.
  /// Difficulty climbs by realm and eases back a little at the start of each world so its twist gets room.
  public static func worldLevel(_ n: Int, chapter ch: Chapter, step k: Int) -> LevelSpec {
    var rng = SplitMix(seed: UInt64(n) &* 0x9E37)
    let tier = Double(ch.number - 9) / Double(max(1, Worlds.count - 9))   // 0 at world 9, 1 at the last
    let pace = min(1.1, 0.78 + 0.22 * tier + 0.012 * Double(k - 1))
    var spec: LevelSpec
    if k == 10 {
      var spawns = [Spawn(.boss), Spawn(.fast, size: 2)]
      if tier > 0.3 { spawns.append(Spawn(.armored, size: 1)) }
      if tier > 0.6 { spawns.append(Spawn(.fast, size: 2)) }
      spec = LevelSpec(number: n, chapter: ch.number, spawns: spawns, speed: pace, meterMax: 4, gates: 0, bossPhases: tier > 0.5 ? 4 : 3, arena: ch.arena)
    } else {
      let budget = min(90, 40 + Int(30 * tier) + (k - 1) * 3 - (k <= 2 ? 6 : 0))
      spec = mixed(number: n, chapter: ch.number, budget: budget, speed: pace, gates: k >= 7 && rng.int(3) == 0 ? 1 : 0, arena: ch.arena, rng: &rng)
      if k >= 6 && tier > 0.4 { spec.meterMax = 3 }
    }
    spec.twists = ch.twists
    spec.boss = ch.boss
    spec.variant = ch.variant
    if ch.twists.contains(.current) { spec.current = 30 + 3 * Double(k) }
    return spec
  }

  /// Procedural levels: the same number always gives the same level.
  public static func generated(_ n: Int, chapter ch: Chapter) -> LevelSpec {
    var rng = SplitMix(seed: UInt64(n) &* 0x1F3D)
    let pace = min(1.2, 0.85 + 0.005 * Double(n - finalAuthored))
    if n % 10 == 0 {
      return LevelSpec(number: n, chapter: ch.number, spawns: [Spawn(.boss), Spawn(.fast, size: 2), Spawn(.armored, size: 1)], speed: pace, meterMax: 4, gates: 0, bossPhases: 3, arena: ch.arena)
    }
    let budget = min(96, 52 + (n - finalAuthored) / 4 + rng.int(12))
    var level = mixed(number: n, chapter: ch.number, budget: budget, speed: pace, gates: rng.int(3) == 0 ? 1 : 0, arena: ch.arena, rng: &rng)
    if n % 3 == 0 { level.meterMax = 3 }
    return level
  }

  public static func mixed(number: Int, chapter: Int, budget: Int, speed: Double, gates: Int, arena: Arena, rng: inout SplitMix) -> LevelSpec {
    let pool: [ActorKind] = [.basic, .basic, .fast, .armored, .magnetic, .repel, .golden, .frozen]
    let spawns: [Spawn] = sizes(forWork: budget).map { size in
      let kind = pool[rng.int(pool.count)]
      return Spawn(kind, size: kind == .fast || kind == .golden ? max(size, 1) : size)
    }
    return LevelSpec(number: number, chapter: chapter, spawns: spawns, speed: speed, meterMax: 4, gates: gates, bossPhases: 0, arena: arena)
  }

  /// One shared level per calendar day, the same on every device.
  public static func daily(year: Int, month: Int, day: Int) -> LevelSpec {
    var rng = SplitMix(seed: UInt64(year * 10_000 + month * 100 + day))
    let arena = Arena.allCases[rng.int(Arena.allCases.count)]
    return mixed(number: 0, chapter: 0, budget: 40 + rng.int(16), speed: 0.7, gates: rng.int(2), arena: arena, rng: &rng)
  }

  public static let arcadeStart = LevelSpec(number: 0, chapter: 0, spawns: [Spawn(.basic), Spawn(.basic)], speed: 0.65, meterMax: 4, gates: 0, bossPhases: 0, arena: .space)
  public static let versusStart = LevelSpec(number: 0, chapter: 0, spawns: [Spawn(.basic), Spawn(.basic), Spawn(.basic)], speed: 0.85, meterMax: 4, gates: 0, bossPhases: 0, arena: .classic)
}
