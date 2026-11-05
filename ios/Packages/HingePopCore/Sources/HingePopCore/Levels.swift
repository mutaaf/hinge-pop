import Foundation

/// The bubble actors from the design sheet.
public enum ActorKind: String, CaseIterable, Sendable, Codable {
  case basic, fast, armored, magnetic, repel, golden, frozen, boss

  /// Multiplies this kind's cruising speed.
  public var speedFactor: Double {
    switch self {
    case .fast: 1.45
    case .frozen: 0.55
    case .boss: 0.6
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

public enum Arena: String, CaseIterable, Sendable, Codable { case classic, neon, forest, space }

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
  public var isBoss: Bool { bossPhases > 0 }
}

public struct Chapter: Sendable, Equatable {
  public var number: Int
  public var title: String
  public var levels: ClosedRange<Int>
  public var teaches: String
  public var arena: Arena
}

public enum Campaign {
  public static let chapters: [Chapter] = [
    .init(number: 1, title: "First Contact", levels: 1...10, teaches: "Pop and split, then faster bubbles.", arena: .classic),
    .init(number: 2, title: "Electric Playground", levels: 11...20, teaches: "Armored bubbles and a touchier hinge.", arena: .neon),
    .init(number: 3, title: "Magnetic Storm", levels: 21...30, teaches: "Magnetic and repel bubbles move everything around them.", arena: .forest),
    .init(number: 4, title: "Overload Protocol", levels: 31...40, teaches: "Moving gates and mixed bubbles.", arena: .space),
    .init(number: 5, title: "Bosses & Beyond", levels: 41...50, teaches: "Boss patterns and combos.", arena: .neon),
  ]
  public static let finalAuthored = 50

  public static func chapter(of level: Int) -> Chapter {
    chapters.first { $0.levels.contains(level) }
      ?? .init(number: 6, title: "Infinity", levels: 51...Int.max, teaches: "Generated levels that keep climbing.", arena: Arena.allCases[(level / 10) % 4])
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

  /// Sizes that add up to a budget of work: as many large as fit, then the biggest pieces that fit the rest.
  public static func sizes(forWork budget: Int) -> [Int] {
    var left = budget, out: [Int] = []
    for size in 0..<4 {
      while left >= work[size], out.count < 7 { out.append(size); left -= work[size] }
    }
    return out.isEmpty ? [0] : out
  }

  /// The first chapter, by hand: one big, then one big and one small, then one big and one medium, and on up.
  private static let firstChapter: [[Int]] = [[0], [0, 2], [0, 1], [0, 1, 2], [0, 0], [0, 0, 2], [0, 0, 1], [0, 0, 1, 2], [0, 0, 1, 1, 2]]

  /// The budget climbs slowly inside a chapter, and eases back at each new one so its new bubble gets room.
  private static func budget(chapter: Int, step k: Int) -> Int { min(66, 22 + chapter * 6 + (k - 1) * 3) }

  /// Speed barely moves for a long time. Later levels ask for more swiping before they ask for faster hands.
  private static func speed(chapter: Int, step k: Int) -> Double { min(1, 0.5 + 0.05 * Double(chapter) + 0.012 * Double(k - 1)) }

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
    let index = ch.number - 1
    let pace = speed(chapter: index, step: k)
    if k == 10 {
      // Every chapter ends on a boss, with more phases and more company as the game goes on.
      var spawns = [Spawn(.boss)]
      if index >= 2 { spawns.append(Spawn(.fast, size: 2)) }
      if index >= 4 { spawns.append(Spawn(.armored, size: 1)) }
      return LevelSpec(number: n, chapter: ch.number, spawns: spawns, speed: pace, meterMax: 4, gates: 0, bossPhases: min(4, 2 + index / 2), arena: ch.arena)
    }
    if index == 0 {
      let sizes = firstChapter[k - 1]
      var kinds: [ActorKind] = []
      if k >= 6 { kinds = Array(repeating: .basic, count: sizes.count - 1) + [.fast] }
      if k >= 8 { kinds[2] = .golden }
      return LevelSpec(number: n, chapter: 1, spawns: dressed(sizes, with: kinds), speed: pace, meterMax: 4, gates: 0, bossPhases: 0, arena: ch.arena)
    }
    let sizes = Campaign.sizes(forWork: budget(chapter: index, step: k))
    var kinds: [ActorKind]
    var meter = 4, gates = 0
    switch index {
    case 1:
      kinds = k <= 2 ? [.armored] : k <= 4 ? [.armored, .basic, .frozen] : [.armored, .frozen, .armored]
      if k >= 7 { meter = 3 }
    case 2:
      kinds = k <= 2 ? [.magnetic] : k <= 4 ? [.repel] : k <= 7 ? [.magnetic, .repel] : [.magnetic, .repel, .golden]
    case 3:
      gates = k >= 6 ? 2 : 1
      let pool: [ActorKind] = [.armored, .fast, .magnetic, .repel, .frozen, .golden]
      kinds = (0..<min(sizes.count, 2 + k / 3)).map { pool[($0 + k) % pool.count] }
    default:
      gates = k % 3 == 0 ? 1 : 0
      let pool: [ActorKind] = [.fast, .armored, .repel, .magnetic, .golden, .frozen]
      kinds = (0..<min(sizes.count, 3 + k / 3)).map { pool[($0 + k * 2) % pool.count] }
    }
    var spawns = dressed(sizes, with: kinds)
    var phases = 0
    if index == 4 && k == 5 {
      spawns = [Spawn(.boss), Spawn(.fast, size: 2), Spawn(.fast, size: 2)]
      phases = 2
    }
    return LevelSpec(number: n, chapter: ch.number, spawns: spawns, speed: pace, meterMax: meter, gates: gates, bossPhases: phases, arena: ch.arena)
  }

  /// Procedural levels: the same number always gives the same level.
  public static func generated(_ n: Int, chapter ch: Chapter) -> LevelSpec {
    var rng = SplitMix(seed: UInt64(n) &* 0x1F3D)
    let pace = min(1.15, 0.75 + 0.004 * Double(n - 50))
    if n % 10 == 0 {
      return LevelSpec(number: n, chapter: ch.number, spawns: [Spawn(.boss), Spawn(.fast, size: 2), Spawn(.armored, size: 1)], speed: pace, meterMax: 4, gates: 0, bossPhases: 4, arena: ch.arena)
    }
    let budget = min(90, 48 + (n - 50) / 4 + rng.int(12))
    return mixed(number: n, chapter: ch.number, budget: budget, speed: pace, gates: rng.int(3) == 0 ? 1 : 0, arena: ch.arena, rng: &rng)
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
