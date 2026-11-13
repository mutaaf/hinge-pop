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
  /// A crowned champion: it takes an extra hit (`Tuning.championArmor`) and moves a little faster.
  public var champion = false
  public init(_ kind: ActorKind, size: Int = 0, champion: Bool = false) { self.kind = kind; self.size = size; self.champion = champion }
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
  /// How hard this level's twists push, 0...1.3. The first levels of a world run them gently.
  public var intensity = 1.0
  /// Wells: how many gravity wells the arena has (when it has the `wells` twist).
  public var wells = 2
  /// Surge: how many small bubbles rush in as the level's last push, announced by `surgeWarning` (0 for none).
  public var surge = 0
  /// Villain bubbles: which can come and how densely (see `Villains.plan`). None by default.
  public var villains = VillainPlan.none
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

/// Realm 1's pressure: the hand-built chapters, tuned to the same per-world bands as the rest (see AGENTS.md).
enum HomePressure {
  /// World 1, level by level: the first two are the tutorial, then it bites from level 3.
  static let firstPaces: [Double] = [0.5, 0.55, 0.9, 0.9, 0.9, 0.84, 0.86, 0.9, 0.9, 0.92]
  static let firstSurges = [0, 0, 5, 5, 5, 4, 4, 5, 5]
  static let pace = 0.72, paceChapter = 0.02, paceStep = 0.01
  /// Each chapter's own nudge: gates make Overload Protocol forgiving, frozen crowds make Frost Fair heavy.
  static let chapterPace = [0, 0.02, 0, 0.09, 0, -0.06, -0.03, 0.02]
  /// Surge from a chapter's third level (from the sixth in the first), champions from its seventh.
  /// Magma Run, the realm's last world, starts with a bigger surge and no crowns: its fast bubbles are enough.
  static func surge(chapter: Int, step k: Int) -> Int {
    chapter == 0 ? firstSurges[min(8, k - 1)] : k < 3 ? (chapter == 7 || chapter == 1 ? 4 : 2) : 2 + (k - 3) / 2 + (chapter == 7 && k < 7 ? 3 : 0)
  }
  static func champions(chapter: Int, step k: Int) -> Int { chapter == 0 || chapter == 7 || k < 7 ? 0 : 1 }
}

/// The pressure curve in one place: how hard each part of a world pushes. `hp-balance` measures it.
struct Pressure {
  var pace: Double, paceTier: Double, paceStep: Double, paceFinale: Double, paceCap: Double, bossPaceCap: Double
  var base: Double, baseTier: Double, finale: Double
  /// Work added at each of a world's first nine levels: gentle opener, a spike at 5, the hardest at 9.
  var ramp: [Double]
  var bossShortMeterTier: Double

  /// Champions arrive in a world's back half, more of them later in the game.
  func champions(_ k: Int, _ tier: Double, _ finale: Bool) -> Int {
    k < 6 ? 0 : (k >= 9 ? 2 : 1) - (k == 9 && (finale || tier >= 0.5) ? 1 : 0)
  }
  /// The level a world's meter shortens to three from.
  func shortMeterFrom(_ tier: Double, _ finale: Bool) -> Int { 11 }
  /// Surge: how many small bubbles rush in as the last push.
  func surge(_ k: Int, _ tier: Double, _ finale: Bool) -> Int {
    k < 3 ? 0 : 2 + (k - 3) / 2 + (tier >= 0.6 && k < 9 ? 1 : 0) + (finale && k < 7 ? 2 : 0)
  }

  static let world = Pressure(pace: 0.78, paceTier: 0.02, paceStep: 0.012, paceFinale: 0.07, paceCap: 0.96, bossPaceCap: 0.9,
                              base: 40, baseTier: 2, finale: 15, ramp: [3, 4, 6, 6, 10, 6, 6, 6, 6], bossShortMeterTier: 2)
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
      return total + work[s.size] + (s.kind == .armored ? 1 : 0) + (s.champion ? 1 : 0)
    }
  }

  /// Sizes that add up to a budget of work. A big bubble that gets through costs a whole shield, so only two
  /// come at once, and the rest of the budget arrives as lighter pieces that forgive a miss.
  public static func sizes(forWork budget: Int, table: [Int] = work) -> [Int] {
    var left = budget, out: [Int] = []
    for size in 0..<4 {
      let most = size == 0 ? 2 : 7
      var made = 0
      while left >= table[size], out.count < 7, made < most { out.append(size); left -= table[size]; made += 1 }
    }
    return out.isEmpty ? [0] : out
  }

  /// The first chapter, by hand: one big, then one big and one small, then one big and one medium, and on up.
  /// The first two are the tutorial; from the third there's always more than one thing to watch.
  private static let firstChapter: [[Int]] = [[0], [0, 2], [0, 1, 2], [0, 1, 1, 2], [0, 0, 2], [0, 0, 2, 2], [0, 0, 1, 2], [0, 0, 1, 1], [0, 0, 1, 1, 2, 2]]

  /// The budget climbs slowly inside a chapter, and eases back at each new one so its new bubble gets room.
  private static func budget(chapter: Int, step k: Int) -> Int { min(chapter >= 5 ? 84 : 76, 24 + chapter * 7 + (k - 1) * 3 - (chapter >= 5 ? 10 : 0)) }

  /// The first two levels are the tutorial and stay slow. From the third the pace starts to bite, and every chapter
  /// opens a notch faster than the last.
  private static func speed(chapter: Int, step k: Int) -> Double {
    if chapter == 0 { return HomePressure.firstPaces[min(9, k - 1)] }
    return min(0.93, HomePressure.pace + HomePressure.chapterPace[min(7, chapter)] + HomePressure.paceChapter * Double(chapter) + HomePressure.paceStep * Double(k - 1))
  }

  /// Swaps some of a level's bubbles for special kinds. Fast and golden come in small, since they move quickly.
  private static func dressed(_ sizes: [Int], with kinds: [ActorKind]) -> [Spawn] {
    sizes.enumerated().map { i, size in
      guard i < kinds.count else { return Spawn(.basic, size: size) }
      let kind = kinds[i]
      return Spawn(kind, size: kind == .fast || kind == .golden ? max(size, 1) : size)
    }
  }

  public static func level(_ n: Int) -> LevelSpec {
    var s = authored(n)
    s.villains = Villains.plan(level: max(1, n))
    return s
  }

  private static func authored(_ n: Int) -> LevelSpec {
    let n = max(1, n)
    let ch = chapter(of: n)
    let k = (n - 1) % 10 + 1
    if n > finalAuthored { return generated(n, chapter: ch) }
    if ch.number > 8 { return worldLevel(n, chapter: ch, step: k) }
    let index = ch.number - 1
    let pace = index == 7 ? min(0.92, speed(chapter: index, step: k)) : speed(chapter: index, step: k)
    if k == 10 {
      // Every chapter ends on a boss, with more phases and more company as the game goes on.
      var spawns = [Spawn(.boss)]
      if index <= 2 { spawns.append(Spawn(.basic, size: 1)) }
      spawns.append(Spawn(.fast, size: 2))
      if index >= 2 { spawns.append(Spawn(.armored, size: 1)) }
      if index == 5 { spawns.append(Spawn(.frozen, size: 1)) }
      if index == 6 { spawns.append(Spawn(.magnetic, size: 1)) }
      if index >= 7 { spawns.append(Spawn(.fast, size: 2)) }
      var boss = LevelSpec(number: n, chapter: ch.number, spawns: spawns, speed: min(0.9, pace), meterMax: 4, gates: 0, bossPhases: index >= 7 ? 4 : 3, arena: ch.arena)
      if index == 6 { boss.current = 50 }
      return boss
    }
    if index == 0 {
      let sizes = firstChapter[k - 1]
      var kinds: [ActorKind] = []
      if k >= 6 { kinds = Array(repeating: .basic, count: sizes.count - 1) + [.fast] }
      if k >= 8 { kinds[2] = .golden }
      var first = LevelSpec(number: n, chapter: 1, spawns: dressed(sizes, with: kinds), speed: pace, meterMax: 4, gates: 0, bossPhases: 0, arena: ch.arena)
      first.surge = HomePressure.surge(chapter: 0, step: k)
      return first
    }
    // Magma's fast bubbles do the work extra bubbles would, so it brings a few less.
    // Frost Fair's short meter at its end leaves room for fewer bubbles.
    let sizes = Campaign.sizes(forWork: index == 7 ? min(54, budget(chapter: index, step: k) - 14) : budget(chapter: index, step: k) - (index == 5 && k == 9 ? 18 : 0))
    var kinds: [ActorKind]
    var meter = 4, gates = 0
    switch index {
    case 1:
      kinds = k <= 2 ? [.armored] : k <= 4 ? [.armored, .basic, .frozen] : [.armored, .frozen, .armored]
    case 2:
      kinds = k <= 2 ? [.magnetic] : k <= 4 ? [.repel] : k <= 7 ? [.magnetic, .repel] : [.magnetic, .repel, .golden]
    case 3:
      gates = k >= 8 ? 2 : 1
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
    var spawns = dressed(sizes, with: kinds)
    var phases = 0
    if (index == 4 || index == 7) && k == 5 {
      spawns = [Spawn(.boss), Spawn(.fast, size: 2), Spawn(.fast, size: 2)]
      phases = 3
    }
    if phases == 0 { crown(&spawns, count: HomePressure.champions(chapter: index, step: k)) }
    var spec = LevelSpec(number: n, chapter: ch.number, spawns: spawns, speed: pace, meterMax: meter, gates: gates, bossPhases: phases, arena: ch.arena)
    if phases == 0 { spec.surge = HomePressure.surge(chapter: index, step: k) }
    if index == 6 { spec.current = 30 + 4 * Double(k); spec.twists = [.current] }
    return spec
  }

  /// What each twist asks of a level: how much of the usual work budget it leaves room for, and the bubble kinds
  /// that play best with it (the first is the one its world teaches with).
  static func recipe(for t: Twist) -> (load: Double, kinds: [ActorKind]) {
    switch t {
    case .current: (1.0, [.magnetic, .repel, .golden, .fast])
    case .wind: (0.92, [.frozen, .fast, .armored, .golden])
    case .tide: (0.9, [.armored, .basic, .fast, .golden])
    case .fog: (0.92, [.fast, .golden, .armored, .basic])
    case .ghost: (1.1, [.armored, .fast, .golden, .basic])
    case .wells: (0.97, [.golden, .magnetic, .fast, .frozen])
    case .portals: (0.95, [.fast, .golden, .repel, .armored])
    case .bounce: (0.9, [.frozen, .armored, .golden, .fast])
    case .regrow: (0.87, [.golden, .basic, .armored, .fast])
    case .triple: (1.08, [.golden, .basic, .fast, .frozen])
    case .pulse: (0.88, [.fast, .golden, .basic, .repel])
    case .blackout: (0.84, [.golden, .basic, .fast, .armored])
    }
  }

  /// Taps to clear each size when every split makes three. Tiny crowds chain, so it's less than the full tree.
  static let tripleWork = [30, 11, 4, 1]

  /// Levels for worlds 9–80, from the world's recipe: the same number always gives the same level.
  /// Each world opens gently on its twist with plain bubbles, brings in the kinds that suit it, spikes at its
  /// fifth level, eases, climbs to its ninth and ends on its boss. Realms climb, and each realm's last world is
  /// its hardest.
  public static func worldLevel(_ n: Int, chapter ch: Chapter, step k: Int) -> LevelSpec {
    var rng = SplitMix(seed: UInt64(n) &* 0x9E37)
    let world = Worlds.world(ch.number)!
    let slot = (world.number - 1) % 8                       // 0...7 inside its realm
    let tier = Double(world.realm - 2) / 8                  // 0 in Sugar Rush, 1 in Clockwork Sky
    let finale = slot == 7
    let twists = world.twists
    let p = Pressure.world
    // How hard the twist pushes: gentle while it's new, full from the third level, a notch more at the spike.
    let intensity = min(1.3, [0.6, 0.8, 0.95, 1, 1.12, 1.02, 1.05, 1.08, 1.14][min(8, k - 1)] + 0.06 * tier + (finale ? 0.06 : 0))
    // A realm's last world starts fast and climbs less, so its end is a test, not a wall.
    let pace = min(p.paceCap, p.pace + p.paceTier * tier + 0.004 * Double(slot) + (finale ? p.paceStep / 2 : p.paceStep) * Double(k - 1) + (finale ? p.paceFinale : 0))
    var spec: LevelSpec
    if k == 10 {
      var spawns = [Spawn(.boss), Spawn(.fast, size: 2)]
      let kind = recipe(for: twists[0]).kinds[0] == .golden ? .armored : recipe(for: twists[0]).kinds[0]
      // A finale's boss already runs four phases under two twists, so it brings speed, not weight.
      if !finale { spawns.append(Spawn(kind, size: 1)) }
      if tier > 0.6 || finale { spawns.append(Spawn(.fast, size: 2)) }
      spec = LevelSpec(number: n, chapter: ch.number, spawns: spawns, speed: min(p.bossPaceCap - (finale ? 0.06 : 0), pace), meterMax: tier >= p.bossShortMeterTier ? 3 : 4, gates: 0, bossPhases: finale ? 4 : 3, arena: ch.arena)
      spec.intensity = min(1.05, intensity)
    } else {
      let load = twists.map { recipe(for: $0).load }.reduce(1, *) * (twists.count > 1 ? 1.06 : 1)
      let raw = p.base + p.baseTier * tier + 0.6 * Double(slot) + (finale ? p.finale + 5 - 6 * tier : 0) + p.ramp[k - 1] * (finale ? 0.6 : 1)
      let budget = max(14, min(90, Int((raw * load).rounded())))
      let table = twists.contains(.triple) ? tripleWork : work
      var sizes = Campaign.sizes(forWork: budget, table: table)
      // A big bubble left alone costs all three shields, so every level keeps at least one: none can be won by watching.
      if !sizes.contains(0) { sizes[0] = 0 }
      // Teach with plain bubbles, then bring in the twist's own kinds one at a time, then mix.
      let pool = recipe(for: twists[0]).kinds + (twists.count > 1 ? recipe(for: twists[1]).kinds : [])
      let specials = k <= 1 ? 0 : k <= 3 ? 1 : k <= 6 ? 2 : min(sizes.count, 2 + (k - 5) + Int(tier * 1.5))
      let kinds: [ActorKind] = (0..<min(specials, sizes.count)).map { i in
        k <= 4 ? pool[i % 2] : pool[(i + rng.int(pool.count)) % pool.count]
      }
      // Specials go on the lighter bubbles first, so a new kind never arrives as the biggest thing on screen.
      let order = sizes.indices.sorted { sizes[$0] > sizes[$1] }
      var spawns = sizes.map { Spawn(.basic, size: $0) }
      for (i, kind) in kinds.enumerated() {
        let at = order[i]
        // Fast and golden come small; they never take the place of a big one.
        if (kind == .fast || kind == .golden) && sizes[at] == 0 { continue }
        spawns[at] = Spawn(kind, size: sizes[at])
      }
      crown(&spawns, count: p.champions(k, tier, finale))
      spec = LevelSpec(number: n, chapter: ch.number, spawns: spawns, speed: pace, meterMax: 4, gates: 0, bossPhases: 0, arena: ch.arena)
      spec.intensity = intensity
      if k >= p.shortMeterFrom(tier, finale) { spec.meterMax = 3 }
      if k >= 7, !twists.contains(.portals), rng.int(5) == 0 { spec.gates = 1 }
      spec.surge = p.surge(k, tier, finale)
    }
    spec.twists = twists
    spec.boss = world.boss
    spec.variant = world.variant
    spec.wells = k <= 2 ? 1 : (k >= 7 || finale) && tier >= 0.3 ? 3 : 2
    if twists.contains(.current) { spec.current = 26 + 3 * Double(k) + 10 * tier }
    return spec
  }

  /// Crowns the first champions on medium bubbles (then smalls), never on a big one: a champion takes an extra hit,
  /// and a big one is already fifteen.
  static func crown(_ spawns: inout [Spawn], count: Int) {
    var left = count
    for size in [1, 2] {
      for i in spawns.indices where left > 0 && spawns[i].size == size && spawns[i].kind != .boss && !spawns[i].champion {
        spawns[i].champion = true; left -= 1
      }
    }
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
