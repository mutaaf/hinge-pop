import Foundation

/// How badly a villain hurts the hand that touches it.
public enum VillainTier: Int, Sendable, Codable, Comparable, CaseIterable {
  /// Takes a shield and breaks the combo.
  case menace = 1
  /// Takes two shields.
  case brute = 2
  /// Ends the run on the spot.
  case doom = 3
  public static func < (a: VillainTier, b: VillainTier) -> Bool { a.rawValue < b.rawValue }

  /// Shields a touch takes (Doom takes the run instead).
  public var shields: Int { self == .menace ? 1 : self == .brute ? 2 : 0 }
  public var label: String {
    switch self {
    case .menace: "Menace"
    case .brute: "Brute"
    case .doom: "Doom"
    }
  }
  /// What a touch costs, in a few words.
  public var cost: String {
    switch self {
    case .menace: "Costs a shield"
    case .brute: "Costs two shields"
    case .doom: "Ends the run"
    }
  }
}

/// Villain bubbles: bad bubbles you must leave alone. They are original genre nods (a fairy-tale witch, a
/// haunted-house ghost, a monster-movie giant, a treasure-chest mimic, a machine tyrant and a cosmic maw), never
/// real characters, names or quotes. They never block a clear and never touch the meter: the danger is a touch.
public enum VillainKind: String, CaseIterable, Sendable, Codable {
  case hex, phantom, kaiju, mimic, overlord, void

  public var tier: VillainTier {
    switch self {
    case .hex, .phantom: .menace
    case .kaiju, .mimic: .brute
    case .overlord, .void: .doom
    }
  }
  public var title: String {
    switch self {
    case .hex: "Hex"
    case .phantom: "Phantom"
    case .kaiju: "Kaiju"
    case .mimic: "Mimic"
    case .overlord: "Overlord"
    case .void: "The Void"
    }
  }
  /// How to spot it and what to do, in a few words (the intro card's line).
  public var tell: String {
    switch self {
    case .hex: "Green brew, crooked hat. Let it fly by."
    case .phantom: "Solid, it bites. Faded, it can't."
    case .kaiju: "Huge and slow. Work around it."
    case .mimic: "Looks golden. Check for teeth."
    case .overlord: "One red eye. It hunts your bubbles."
    case .void: "It drags bubbles in. Pick carefully."
    }
  }
  /// What it says when it ends your run. Original lines only.
  public var taunt: String {
    switch self {
    case .hex: "One poke of the brew, and the curse is on you."
    case .phantom: "Boo. You never saw me coming."
    case .kaiju: "Stomp. This town is mine now."
    case .mimic: "Shiny, wasn't I? Chomp."
    case .overlord: "I have one eye, and it was on you."
    case .void: "The dark was hungry. You fed it."
    }
  }
  /// The genre it winks at (for the guide and tests). Never a real title.
  public var genre: String {
    switch self {
    case .hex: "fairy-tale witch"
    case .phantom: "haunted-house ghost"
    case .kaiju: "monster-movie giant"
    case .mimic: "dungeon treasure trap"
    case .overlord: "machine-tyrant sci-fi"
    case .void: "cosmic horror"
    }
  }
  /// First campaign level it can appear in (Normal). Overdrive brings each one in sooner.
  public var debut: Int {
    switch self {
    case .hex: 4
    case .phantom: 7
    case .kaiju: 11
    case .mimic: 16
    case .overlord: 31
    case .void: 45
    }
  }
  public var overdriveDebut: Int {
    switch self {
    case .hex: 2
    case .phantom: 4
    case .kaiju: 7
    case .mimic: 9
    case .overlord: 21
    case .void: 29
    }
  }
  /// Size against a medium bubble.
  public var radiusFactor: Double {
    switch self {
    case .kaiju: 1.55
    case .overlord: 1.2
    case .void: 1.15
    case .mimic: 1.0
    default: 1.0
    }
  }
  /// Speed against a medium bubble's cruise.
  public var speedFactor: Double {
    switch self {
    case .hex: 0.85
    case .phantom: 0.75
    case .kaiju: 0.45
    case .mimic: 1.15
    case .overlord: 0.6
    case .void: 0.5
    }
  }
}

/// How a villain got busted safely.
public enum VillainCounter: String, Sendable, Codable {
  /// Touched while everything was frozen: it shatters.
  case freeze
  /// Caught in a Chain Burst (or a guest's burst).
  case burst
  /// Whipped by Snap the Hinge.
  case snap
  /// Swept by a Crease Clap on iPhone Duo.
  case clap
}

/// A level's villains: which can come, when the first one does, how often after, and how many at once.
public struct VillainPlan: Equatable, Sendable {
  public var pool: [VillainKind] = []
  /// The level's newest villain comes first, so its intro matches what you meet.
  public var debut: VillainKind?
  /// Seconds into play before the first one, and between arrivals after that.
  public var first = 5.0
  public var gap = 9.0
  public var maxOn = 1
  /// Doom villains at most this many at once (they stay rare enough to read).
  public var maxDoom = 1
  /// A boss calls this villain in at each phase change.
  public var summons: VillainKind?
  public var isEmpty: Bool { pool.isEmpty }
  public init(pool: [VillainKind] = [], debut: VillainKind? = nil, first: Double = 5, gap: Double = 9, maxOn: Int = 1, maxDoom: Int = 1, summons: VillainKind? = nil) {
    self.pool = pool; self.debut = debut; self.first = first; self.gap = gap; self.maxOn = maxOn; self.maxDoom = maxDoom; self.summons = summons
  }
  public static let none = VillainPlan()
}

public enum Villains {
  /// Which villains a campaign level brings, and how densely. Density climbs with depth, a world's first two
  /// levels run lighter and its ninth heavier, and from realm 3 bosses call villains in. Overdrive brings each one
  /// sooner, more often and more at once.
  public static func plan(level n: Int, overdrive: Bool = false) -> VillainPlan {
    let n = max(1, n)
    let debutOf: (VillainKind) -> Int = { overdrive ? $0.overdriveDebut : $0.debut }
    var pool = VillainKind.allCases.filter { debutOf($0) <= n }
    guard !pool.isEmpty else { return .none }
    let depth = Double(min(n, 800))
    let k = (n - 1) % 10 + 1
    var gap = max(4.6, 11 - 1.5 * log(depth / 3))
    // Short levels (a world's first two) get theirs sooner, so a fast clear can't just outrun them.
    if k == 9 { gap *= 0.85 } else if k <= 2 { gap *= 0.75 }
    var maxOn = n < 11 ? 1 : n < 81 ? 2 : n < 321 ? 3 : 4
    // A boss fight is long and busy already: villains come less often, one at a time, and a Doom only by summons.
    if k == 10 { gap *= 1.6; maxOn = 1; pool = pool.filter { $0.tier != .doom } }
    if overdrive { gap *= 0.8; maxOn += 1 }
    let realm = (n - 1) / 80 + 1
    var summons: VillainKind?
    if k == 10, realm >= 3 {
      let pair: (VillainKind, VillainKind) = realm >= 9 ? (.overlord, .void) : realm >= 6 ? (.kaiju, .mimic) : (.hex, .phantom)
      summons = realm % 2 == 0 ? pair.0 : pair.1
    }
    if overdrive, k == 10, realm >= 2, summons == nil { summons = .kaiju }
    let debut = VillainKind.allCases.first { debutOf($0) == n }
    return VillainPlan(pool: pool, debut: debut, first: n < 11 ? 5 : n < 30 ? 2.5 : 1.2, gap: gap, maxOn: maxOn, maxDoom: n < 161 ? 1 : 2, summons: summons)
  }

  /// Arcade: menaces and brutes from the start, and the Overlord once it gets going.
  public static let arcade = VillainPlan(pool: [.hex, .phantom, .kaiju, .mimic, .overlord], first: 8, gap: 9, maxOn: 2)
  /// Daily: one plan for everyone, the same every day.
  public static let daily = plan(level: 60)
  /// Two players: villains come in mirrored pairs, one for each half, so nobody's dealt a worse hand.
  public static let versus = VillainPlan(pool: [.hex, .phantom, .kaiju, .mimic, .overlord], first: 7, gap: 10, maxOn: 2, maxDoom: 2)

  /// The villains that first appear in a campaign level (for intro cards). Normal and Overdrive differ.
  public static func debuts(at n: Int, overdrive: Bool = false) -> [VillainKind] {
    VillainKind.allCases.filter { (overdrive ? $0.overdriveDebut : $0.debut) == n }
  }
  /// Every villain a player has met up to a level (for the guide).
  public static func met(through n: Int, overdrive: Bool = false) -> [VillainKind] {
    VillainKind.allCases.filter { (overdrive ? $0.overdriveDebut : $0.debut) <= n }
  }
}

/// A villain on the field. Not a bubble: it never blocks a clear, never crosses at a cost and never splits.
public final class Villain: Identifiable {
  public let id: Int
  public let kind: VillainKind
  public internal(set) var x: Double, y: Double
  public internal(set) var vx: Double, vy: Double
  public internal(set) var r: Double
  public internal(set) var prevX: Double, prevY: Double
  public internal(set) var age = 0.0
  /// Seconds before it starts to leave.
  public internal(set) var life: Double
  /// Seconds it's still materialising after arriving: it glows its warning and can't hurt yet.
  public internal(set) var warn: Double
  /// 1 when solid. A Phantom fades low between bites, and everyone fades out as they leave.
  public internal(set) var presence = 0.0
  /// True once it's on its way out (harmless).
  public internal(set) var leaving = false
  /// Which side of the hinge it's on (-1 near, 1 far). In two-player it's whose problem it is.
  public internal(set) var side: Int
  /// Overlord: the bubble its eye is locked on.
  public internal(set) var targetId: Int?
  /// Kaiju: seconds to its next stomp.
  var stompClock = 2.4
  var phaseClock = 0.0
  public var tier: VillainTier { kind.tier }
  /// True when a touch on it would hurt (and when it can be busted).
  public var solid: Bool { warn <= 0 && !leaving && presence >= 0.5 }
  init(id: Int, kind: VillainKind, x: Double, y: Double, vx: Double, vy: Double, r: Double, life: Double, warn: Double, side: Int) {
    self.id = id; self.kind = kind; self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.r = r; self.life = life; self.warn = warn; self.side = side
    prevX = x; prevY = y
  }
}
