import Foundation

/// Every number that shapes how the game feels. Tests and bots read this, so there is one source of truth.
public struct Tuning: Sendable {
  public var radii: [Double] = [44, 31, 21, 14]
  public var speeds: [Double] = [110, 152, 200, 250]
  public var points: [Int] = [100, 200, 300, 500]
  /// Each size is its own kind of object: mass decides who wins a collision, bounce how much speed
  /// survives an impact, recover how fast it swims back up to cruising speed.
  public var mass: [Double] = [8, 4, 2, 1]
  public var bounce: [Double] = [0.7, 0.8, 0.9, 0.98]
  public var recover: [Double] = [0.9, 1.4, 2.2, 3]
  public var meterMax = 4
  public var rechargeStreak = 8
  public var shields = 3
  public var comboStep = 0.5
  public var comboMax = 10.0
  public var comboWindow = 1.6
  public var graceHinge = 0.6
  public var graceTap = 0.2
  public var readyTime = 0.8
  public var cleanBonus = 1.25
  public var minCross = 0.25
  public var hingePull = 0.6
  /// Popping a smallest bubble also pops other smallest bubbles this close (scaled), and those chain on.
  public var chainPopRadius = 62.0
  public var chainStep = 0.25
  /// A swipe reaches this far past a bubble's edge.
  public var sliceReach = 8.0
  public var goldenMultiplier = 5
  public var armorPoints = 50
  public var dropChance = 0.1
  public var pickupLife = 7.0
  public var overchargeTime = 8.0
  public var freezeTime = 3.0
  public var freezeScale = 0.35
  public var focusTime = 4.0
  public var focusInterval = 0.14
  public var chainRadius = 130.0
  public var fieldRadius = 190.0
  public var fieldForce = 240.0
  public var bossRadius = 1.75
  public var bossMass = 40.0
  public var bossHitsPerPhase = 8
  public var bossContactCooldown = 0.8
  /// After a hit a boss shrugs off touches for this long, so hammering the screen can't melt it.
  public var bossGuard = 0.28
  public var bossPhaseSpeed = 0.3
  /// Every so often a boss winds up, then dashes at the hinge. A hit during the wind-up staggers it for double damage.
  public var bossWindupEvery = 6.0
  public var bossWindupEveryPhase = 1.2
  public var bossWindupTime = 1.1
  public var bossDashSpeed = 3.0
  public var bossDashCharge = 4
  public var bossMinions = 2
  /// Cameos: visitors who wander through, ignore the hinge and leave a gift if you catch them.
  public var cameoFirst = 5.0
  public var cameoGap = 16.0
  public var cameoLife = 8.5
  public var cameoPoints = 1000
  public var cameoRadius = 34.0
  /// Busy levels arrive in stages: a new bubble comes when the arena has this little work left, or after the gap.
  public var arrivalWork = 12
  public var arrivalOpening = 22
  public var arrivalGap = 9.0
  public var gateWidth = 150.0
  public var gateSpeed = 70.0
  public init() {}
}

/// A small deterministic generator, so levels, drops and bots replay exactly from a seed.
public struct SplitMix: Sendable {
  private var state: UInt64
  public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
  public mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
  public mutating func int(_ below: Int) -> Int { below <= 0 ? 0 : Int(next() % UInt64(below)) }
}
