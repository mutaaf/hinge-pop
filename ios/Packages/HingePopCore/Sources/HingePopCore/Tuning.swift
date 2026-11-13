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
  public var rechargeStreak = 12
  public var shields = 3
  public var comboStep = 0.5
  public var comboMax = 10.0
  public var comboWindow = 1.3
  public var graceHinge = 0.38
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
  public var bossHitsPerPhase = 12
  public var bossContactCooldown = 0.8
  /// After a hit a boss shrugs off touches for this long, so hammering the screen can't melt it.
  public var bossGuard = 0.32
  public var bossPhaseSpeed = 0.3
  /// Every so often a boss winds up, then dashes at the hinge. A hit during the wind-up staggers it for double damage.
  public var bossWindupEvery = 4.2
  public var bossWindupEveryPhase = 1.2
  public var bossWindupTime = 0.95
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
  public var arrivalWork = 26
  public var arrivalOpening = 32
  public var arrivalGap = 5.0
  /// Snap the Hinge: drag off the line and it cracks like a whip, flinging nearby bubbles away from it.
  public var snapCooldown = 7.0
  public var snapReach = 120.0
  public var snapForce = 620.0
  public var snapTouch = 26.0
  /// iPhone Duo. On a fold the two pages play differently. Every so often one page lights up as the rush page:
  /// its bubbles speed up and score double. Popping back and forth across the crease builds a crossfold combo,
  /// and touching both pages beside the crease at once claps it, sweeping the whole line. Only where the fold
  /// sits counts. Its angle never changes play.
  public var rushFirst = 6.0
  public var rushEvery = 13.0
  public var rushTime = 6.0
  public var rushSpeed = 1.2
  public var rushPoints = 2.0
  public var crossfoldStep = 0.5
  public var clapReach = 110.0
  public var clapWindow = 0.3
  public var clapSweep = 1.6
  /// Coral Drift: seconds for the current to swing one way and back.
  public var currentPeriod = 16.0
  public var gateWidth = 120.0
  public var gateSpeed = 70.0
  /// World twists (see `Twist`). Each scales with the level's `LevelSpec.intensity`.
  /// Wind: a gust every `windEvery` seconds blows across for `windTime`, after `windWarn` seconds of warning.
  public var windEvery = 7.5
  public var windTime = 3.2
  public var windWarn = 1.0
  public var windForce = 62.0
  /// Tide: the hinge rises and falls this far (a fraction of the arena's depth) over `tidePeriod` seconds.
  public var tideReach = 0.13
  public var tidePeriod = 13.0
  /// Fog: a bubble is clear within `fogClear` of the way from the hinge to its wall, and gone past `fogDense`.
  /// Bubbles you can't see can't be touched.
  public var fogClear = 0.42
  public var fogDense = 0.78
  /// Ghost: each bubble fades out of phase for `ghostTime` seconds, every `ghostEvery` (± a little).
  public var ghostEvery = 4.2
  public var ghostTime = 1.2
  public var ghostFade = 0.22
  /// Wells: how far a well reaches, how hard it pulls in and how hard it swirls round.
  public var wellReach = 150.0
  public var wellPull = 230.0
  public var wellSwirl = 170.0
  /// Portals: a bubble that leaves through one wall comes out of the other this much faster.
  public var portalBoost = 1.25
  /// Bounce: each wall bounce adds this much to a bubble's speed, up to `springMax`, easing off at `springEase`/s.
  public var springGain = 0.14
  public var springMax = 1.6
  public var springEase = 0.06
  /// Regrow: a piece left untouched this long grows back one size (never back to the biggest).
  public var regrowTime = 8.5
  /// Pulse: the beat's period, how close to it counts as on the beat, and how much bubbles surge on it.
  public var beatPeriod = 0.9
  public var beatWindow = 0.14
  public var beatSurge = 0.22
  /// Blackout: the lit band either side of the hinge, the light a touch leaves, and how long a bubble stays lit.
  public var darkBand = 95.0
  public var lanternReach = 105.0
  public var lanternTime = 1.6
  public var litTime = 1.1
  /// Boss styles. Twins are smaller; a shield covers this half-angle and turns this fast; a splitter shrinks each phase.
  public var twinScale = 0.74
  public var shieldArc = 1.15
  public var shieldSpin = 1.1
  public var splitterShrink = 0.86
  public var blinkEcho = 0.55
  /// Overtime: a level that drags past its par (`overtimeBase` + `overtimePerWork` per tap of work, plus
  /// `overtimePerHit` per boss hit) speeds everything up by `overtimeGain` every `overtimeEvery` seconds,
  /// up to `overtimeSteps` times. Stalling never pays.
  public var overtimeBase = 6.0
  public var overtimePerWork = 0.24
  public var overtimePerHit = 0.7
  public var overtimeEvery = 4.0
  public var overtimeGain = 0.12
  public var overtimeSteps = 6
  /// Fever: a combo filled to `comboMax` starts a fever for `feverTime` seconds. Pops score `feverPoints`×,
  /// bubbles slow to `feverSlow` and the combo holds. A crossing ends it.
  public var feverTime = 5.0
  public var feverSlow = 0.82
  public var feverPoints = 2.0
  /// Champions: crowned bubbles late in a world. Each takes `championArmor` extra hits and moves a little faster.
  public var championArmor = 1
  public var championSpeed = 1.12
  /// A boss in its last phase sheds a small piece toward the line this often.
  public var bossShedEvery = 6.5
  /// Surge: a level's last push is announced this long before it lands.
  public var surgeWarn = 1.5
  /// Villains: seconds each one materialises (glowing, harmless) before it can bite, how long it stays, what
  /// leaving one alone pays (by tier), and what busting one with a power pays (by tier, times the combo).
  /// Off only for measuring the game without them (`hp-balance --no-villains`).
  public var villains = true
  public var villainWarn = 0.9
  public var villainLife = 11.0
  public var villainFade = 0.7
  public var villainDodgePoints = [0, 50, 100, 200]
  public var villainBustPoints = [0, 300, 600, 1200]
  /// A touch has to land this close to a villain's edge to reach it (a bit stingier than a bubble's).
  public var villainTouch = 4.0
  /// The Void drags bubbles within `voidReach` toward it; the Overlord's eye turns toward its prey this fast.
  public var voidReach = 160.0
  public var voidPull = 230.0
  public var overlordTurn = 1.1
  /// Phantom: seconds solid, then seconds faded (harmless) between bites.
  public var phantomSolid = 2.2
  public var phantomFaint = 1.5
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
