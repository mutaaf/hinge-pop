import Foundation

public enum GameMode: Equatable, Sendable {
  case campaign(Int)
  case arcade(seed: UInt64)
  case daily(year: Int, month: Int, day: Int)
  case versus
  /// A hand-built scene for the guided tour: no bubbles to start, nothing can end it by itself.
  case sandbox
}

public final class Bubble: Identifiable {
  public let id: Int
  public internal(set) var kind: ActorKind
  public internal(set) var size: Int
  public var x: Double, y: Double
  public var vx: Double, vy: Double
  public internal(set) var r: Double
  public var grace: Double
  public internal(set) var side: Int
  public internal(set) var sq = 0.0
  public internal(set) var sqA = 0.0
  public internal(set) var armor = 0
  public internal(set) var bossHits = 0
  public internal(set) var bossPhase = 0
  public internal(set) var bossGuard = 0.0
  /// Seconds left in a wind-up, while it glows and slows before dashing.
  public internal(set) var bossWindup = 0.0
  public internal(set) var bossDashing = false
  var bossClock = 0.0
  /// Where it was one physics step ago, so drawing can land between steps.
  public internal(set) var prevX = 0.0
  public internal(set) var prevY = 0.0
  var contactCooldown = 0.0
  /// Ghost: 1 when solid, 0 when out of phase. Under half, it can't be touched and can't cross.
  public internal(set) var presence = 1.0
  /// Ghost: true while it's fading out or gone.
  public internal(set) var phasing = false
  var ghostClock = 0.0
  /// Bounce: how much faster than cruising its springy bounces have made it (1 is normal).
  public internal(set) var spring = 1.0
  /// Regrow: 0 when fresh, 1 the moment it grows back a size.
  public internal(set) var regrow = 0.0
  /// Blackout: seconds it stays lit. A dark bubble can't be touched.
  public internal(set) var lit = 0.0
  /// Triple: a piece from a three-way split, a little lighter on the meter.
  public internal(set) var light = false
  /// Twin bosses are smaller, and a splitter shrinks at each phase.
  public internal(set) var shrink = 1.0
  /// Shielded boss: the way its shield faces, in radians (arena coordinates, y down).
  public internal(set) var shieldAngle = 0.0
  /// A crowned champion: its extra hits sit in `armor`, and it cruises a little faster.
  public internal(set) var champion = false
  var blinked = false
  var shedClock = 0.0
  init(id: Int, kind: ActorKind, size: Int, x: Double, y: Double, vx: Double, vy: Double, r: Double, grace: Double) {
    self.id = id; self.kind = kind; self.size = size; self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.r = r; self.grace = grace; side = 0; prevX = x; prevY = y
  }
}

public struct Pickup: Identifiable, Sendable {
  public let id: Int
  public let kind: PowerUp
  public var x: Double, y: Double
  public var life: Double
}

/// A guest passing through. Not a bubble: it never blocks a clear and never touches the meter.
public struct Visitor: Identifiable, Sendable {
  public let id: Int
  public let cameo: Cameo
  public var x: Double, y: Double
  public var prevX: Double, prevY: Double
  public var age = 0.0
  public var life: Double
  /// Fades in and out for the ghost, and is 1 for everyone else.
  public var presence = 1.0
  var startX: Double, baseY: Double, dir: Double
  var blink = 0.0
  var dodgesLeft = 0
  public var dodgesLeftForTest: Int { dodgesLeft }
}

/// Wells: a gravity well that pulls bubbles on its side into a slow orbit. `spin` is +1 or -1.
public struct Well: Sendable, Equatable {
  public var x: Double, y: Double
  public var reach: Double
  public var spin: Double
  var u: Double, v: Double
}

/// Blackout: the light a touch leaves behind for a moment.
public struct Lantern: Sendable, Equatable {
  public var x: Double, y: Double
  public var left: Double
  public var reach: Double
}

public struct Gate: Sendable {
  public var at: Double
  public var width: Double
  public var dir: Double
}

public struct Player: Sendable {
  public var score: Int
  public var combo = 1.0
  public var comboT = 0.0
  public var bestCombo = 1.0
  public var meter = 0
  public var shields: Int
  public var shieldsLost = 0
  public var streak = 0
  public var recharges = 0
  public var taps = 0
  public var flicks = 0
  public var crossings = 0
  public var zaps = 0
  public var chained = 0
  public var slices = 0
  public var overcharge = 0.0
  public var pickups = 0
  public var cameos = 0
  public var snaps = 0
  public var snapLeft = 0.0
  public var crossfolds = 0
  public var claps = 0
  /// Fever: seconds left (0 when none), and how many this level.
  public var fever = 0.0
  public var fevers = 0
}

public enum GameEvent: Equatable, Sendable {
  case split(x: Double, y: Double, r: Double, size: Int, points: Int, kind: ActorKind)
  case pop(x: Double, y: Double, r: Double, size: Int, points: Int, kind: ActorKind)
  case zap(x: Double, y: Double, r: Double, points: Int)
  case chainPop(x: Double, y: Double, r: Double, points: Int, count: Int)
  case crossed(x: Double, y: Double, r: Double, size: Int, player: Int)
  case gatePass(x: Double, y: Double, r: Double)
  case armorCrack(x: Double, y: Double, r: Double, points: Int)
  case bossHit(x: Double, y: Double, r: Double, points: Int, phase: Int)
  case bossPhase(x: Double, y: Double, r: Double, phase: Int)
  case bossSlam(x: Double, y: Double, r: Double, player: Int)
  case bossWindup(x: Double, y: Double, r: Double)
  case bossStagger(x: Double, y: Double, r: Double, points: Int)
  case bossBlocked(x: Double, y: Double, r: Double)
  case hingeSnap(along: Double, player: Int, flung: Int)
  case snapReady(player: Int)
  /// iPhone Duo page play: a page lights up, then settles; a pop across the crease; both pages clapped at once.
  case rushStart(side: Int)
  case rushOver
  case crossfold(x: Double, y: Double, combo: Double)
  case creaseClap(flung: Int)
  /// The level's secret bubble was hit. Easter egg only: it plays like any other bubble.
  case secretBubble(level: Int, x: Double, y: Double)
  case cameoArrived(Cameo, x: Double, y: Double)
  case cameoCaught(Cameo, x: Double, y: Double, points: Int, player: Int)
  case cameoDodged(Cameo, x: Double, y: Double)
  case cameoBlink(Cameo, fromX: Double, fromY: Double, x: Double, y: Double)
  case bump(strength: Double, size: Int)
  /// World twists: a gust starts blowing (dir is +1 or -1 across the hinge), a beat lands, a pop lands on it,
  /// a bubble goes through a portal, bounces off a springy wall, grows back, or was out of reach for a touch.
  case gust(dir: Double)
  case beat(Int)
  case beatPop(x: Double, y: Double, points: Int)
  case portal(fromX: Double, fromY: Double, x: Double, y: Double, r: Double)
  case spring(x: Double, y: Double, r: Double)
  case regrow(x: Double, y: Double, r: Double, size: Int)
  case untouchable(x: Double, y: Double, r: Double)
  /// Boss styles: a blinker teleports, a summoner calls a wave, a splitter throws off a minion, a shield turns a hit.
  case bossBlink(fromX: Double, fromY: Double, x: Double, y: Double, r: Double)
  case bossSummon(x: Double, y: Double, r: Double, count: Int)
  case bossSplit(x: Double, y: Double, r: Double)
  case bossShielded(x: Double, y: Double, r: Double)
  /// Pressure. Overtime: the level ran past par and everything sped up a step (1, 2, ...). Fever: a full combo
  /// started (or ended) a fever. A champion's crown cracked (`armorLeft` hits to go before it pops like the rest).
  /// A surge is announced, then lands. A boss in its last phase shed a small piece.
  case overtime(step: Int)
  case feverStart(player: Int)
  case feverEnd(player: Int)
  case championCrack(x: Double, y: Double, r: Double, points: Int, armorLeft: Int)
  case surgeWarning(count: Int)
  case surge(count: Int)
  case bossShed(x: Double, y: Double, r: Double)
  case shieldLost(player: Int)
  case recharge(player: Int)
  case cooled(player: Int)
  case dropped(PowerUp, x: Double, y: Double)
  case collected(PowerUp, x: Double, y: Double, player: Int)
  case wave(Int)
  case finished
}

public enum GameStatus: Equatable, Sendable { case playing, won, lost, ended }

/// The whole game state, advanced by `step` and changed by `tap`. Arena coordinates have y growing down.
public final class Game {
  public let tuning: Tuning
  public let mode: GameMode
  public let spec: LevelSpec
  public private(set) var w: Double
  public private(set) var h: Double
  public private(set) var top: Double
  public private(set) var vertical: Bool
  /// Where the hinge sits across the arena. On an iPhone Duo this is the real fold.
  public private(set) var hinge: Double
  private var fixedHinge: Double?
  public var flick = true
  public var graceOn = true
  /// True when the hinge sits on a real fold, which turns on page play. The app sets it from where the fold is,
  /// never from its angle.
  public var foldPlay = false {
    didSet { if !foldPlay { rushSide = 0; rushLeft = 0; lastPage = [0, 0] } }
  }
  /// The page that's rushing: -1 the near page, 1 the far one, 0 none.
  public private(set) var rushSide = 0
  public private(set) var rushLeft = 0.0
  private var rushClock = 0.0
  private var rushTurn = 0
  private var lastPage = [0, 0]
  /// The id of the bubble that hides this level's nod, until it's hit.
  public private(set) var secretBubble: Int?
  public private(set) var bubbles: [Bubble] = []
  public private(set) var pickups: [Pickup] = []
  public private(set) var visitors: [Visitor] = []
  public private(set) var gates: [Gate] = []
  public var players: [Player]
  public private(set) var status = GameStatus.playing
  public private(set) var winner: Int?
  public var ready: Double
  public private(set) var time = 0.0
  public private(set) var freeze = 0.0
  public private(set) var focus = 0.0
  public private(set) var cleanBonus = false
  public private(set) var waves = 0
  public var events: [GameEvent] = []
  private var focusClock = 0.0
  private var waveClock = 8.0
  /// Bubbles still waiting to come in, and how long since the last one did.
  private var arrivals: [Spawn] = []
  private var arrivalClock = 0.0
  public var bubblesToCome: Int { arrivals.count + (surgeDone ? 0 : spec.surge) }
  /// Surge: seconds until an announced surge lands (0 when none is on its way).
  public private(set) var surgeIn = 0.0
  private var surgeDone = false
  /// Overtime: seconds into play when it starts (the level's par; beat it for three stars), how many steps
  /// it has taken, and how much faster everything moves for it (1 before it starts).
  public private(set) var overtimeAt = Double.infinity
  public private(set) var overtime = 0
  public var overtimeSpeed: Double { 1 + tuning.overtimeGain * Double(overtime) }
  /// Seconds until overtime starts or takes its next step (0 once it has taken them all, or never runs).
  public var overtimeIn: Double {
    guard overtimeAt.isFinite, overtime < tuning.overtimeSteps else { return 0 }
    return max(0, overtimeAt + Double(overtime) * tuning.overtimeEvery - time)
  }
  /// Fever for the solo player (see `Player.fever`).
  public var feverLeft: Double { players[0].fever }
  private var cameoClock = 0.0
  /// Holds guests where they are, for automated touch tests.
  public var visitorsHeld = false
  private var cameoRng = SplitMix(seed: 1)
  private var cameoTurn = 0
  private var nextId = 1
  private var rng: SplitMix
  private let isVersus: Bool
  public let meterMax: Int

  // MARK: Twist state (read-only for the renderer)

  /// Where the hinge rests. With the tide it rises and falls around this by `tideOffset`.
  public private(set) var baseHinge = 0.0
  public private(set) var tideOffset = 0.0
  /// Wind: the push across the hinge right now, in points a second (signed: + pushes toward larger x or y).
  public private(set) var wind = 0.0
  /// Wind: which way the current or next gust blows, and seconds until it starts (0 while it blows).
  public private(set) var windDir = 1.0
  public private(set) var gustIn = 0.0
  /// The strongest the wind gets this level, for drawing it to scale.
  public var windPeak: Double { tuning.windForce * scale * spec.intensity }
  private var windClock = 0.0
  public private(set) var wells: [Well] = []
  /// Pulse: beats so far, and how far into the current beat we are (0 right on it).
  public private(set) var beats = 0
  public var beatPhase: Double { spec.has(.pulse) ? (time / tuning.beatPeriod).truncatingRemainder(dividingBy: 1) : 0 }
  /// True inside the window around a beat, where a pop scores double.
  public var onBeat: Bool {
    guard spec.has(.pulse) else { return false }
    let w = tuning.beatWindow / tuning.beatPeriod, p = beatPhase
    return p <= w || p >= 1 - w * 0.6
  }
  public private(set) var lantern: Lantern?
  private var twistRng = SplitMix(seed: 3)

  public var versus: Bool { isVersus }

  public init(mode: GameMode, width: Double, height: Double, top: Double = 0, vertical: Bool? = nil, hinge: Double? = nil, score: Int = 0, tuning: Tuning = Tuning(), seed: UInt64 = 1) {
    self.mode = mode
    self.tuning = tuning
    w = width; h = height; self.top = top
    isVersus = mode == .versus
    self.vertical = isVersus || (vertical ?? (width > height))
    fixedHinge = hinge
    self.hinge = 0
    ready = tuning.readyTime
    rushClock = tuning.rushFirst
    players = isVersus
      ? [Player(score: 0, shields: tuning.shields), Player(score: 0, shields: tuning.shields)]
      : [Player(score: score, shields: tuning.shields)]
    switch mode {
    case .campaign(let n): spec = Campaign.level(n); rng = SplitMix(seed: UInt64(max(1, n)) &+ seed &* 977)
    case .arcade(let s): spec = Campaign.arcadeStart; rng = SplitMix(seed: s)
    case .daily(let y, let m, let d): spec = Campaign.daily(year: y, month: m, day: d); rng = SplitMix(seed: UInt64(y * 10_000 + m * 100 + d) &+ 7)
    case .versus: spec = Campaign.versusStart; rng = SplitMix(seed: seed)
    case .sandbox: spec = LevelSpec(number: 1, chapter: 1, spawns: [], speed: 0.6, meterMax: tuning.meterMax, gates: 0, bossPhases: 0, arena: .classic); rng = SplitMix(seed: seed)
    }
    meterMax = spec.meterMax
    self.hinge = fixedHinge ?? defaultHinge()
    baseHinge = self.hinge
    twistRng = SplitMix(seed: UInt64(max(1, spec.number)) &* 0x51ED &+ seed)
    windClock = 0
    windDir = twistRng.int(2) == 0 ? 1 : -1
    if spec.has(.wells) { makeWells() }
    cameoRng = SplitMix(seed: UInt64(max(1, spec.number)) &+ seed &* 131)
    cameoClock = tuning.cameoFirst + cameoRng.unit() * 4
    cameoTurn = spec.number
    spawnLevel()
    overtimeAt = par()
    for i in 0..<spec.gates {
      let span = alongSpan
      gates.append(Gate(at: span.lowerBound + (span.upperBound - span.lowerBound) * (Double(i) + 0.5) / Double(spec.gates), width: tuning.gateWidth * scale, dir: i % 2 == 0 ? 1 : -1))
    }
  }

  // MARK: Geometry

  public var scale: Double { max(0.85, min(2.4, min(w, h - top) / 400)) }
  private func defaultHinge() -> Double { vertical ? w / 2 : top + (h - top) / 2 }
  private var alongSpan: ClosedRange<Double> { vertical ? top...h : 0...w }
  private func across(_ b: Bubble) -> Double { vertical ? b.x : b.y }
  private func along(_ b: Bubble) -> Double { vertical ? b.y : b.x }
  private func sideOf(_ b: Bubble) -> Int { across(b) < hinge ? -1 : 1 }
  public func playerIndex(of b: Bubble) -> Int { isVersus && b.side > 0 ? 1 : 0 }

  /// Page play only runs solo: in versus each page already belongs to a player.
  private var pagePlay: Bool {
    guard foldPlay, !isVersus, mode != .sandbox else { return false }
    if case .campaign(let n) = mode { return n >= 2 }
    return true
  }
  public func onRush(_ b: Bubble) -> Bool { rushLeft > 0 && b.side == rushSide }

  public func radius(of kind: ActorKind, size: Int) -> Double {
    tuning.radii[size] * scale * (kind == .boss ? tuning.bossRadius : 1)
  }
  private func radius(_ b: Bubble) -> Double { radius(of: b.kind, size: b.size) * b.shrink }
  private func mass(_ b: Bubble) -> Double {
    b.kind == .boss ? tuning.bossMass : tuning.mass[b.size] * b.kind.massFactor
  }
  /// How fast a bubble wants to move right now (internal so tests can read it).
  func cruise(_ b: Bubble) -> Double {
    let pressure = overtimeSpeed * (players[playerIndex(of: b)].fever > 0 ? tuning.feverSlow : 1)
    guard b.kind == .boss else { return tuning.speeds[b.size] * scale * spec.speed * b.kind.speedFactor * (onRush(b) ? tuning.rushSpeed : 1) * b.spring * surge * pressure * (b.champion ? tuning.championSpeed : 1) }
    let phaseBoost = 1 + tuning.bossPhaseSpeed * Double(b.bossPhase)
    let state = b.bossWindup > 0 ? 0.15 : b.bossDashing ? tuning.bossDashSpeed : 1
    return tuning.speeds[b.size] * scale * spec.speed * b.kind.speedFactor * phaseBoost * state * pressure
  }

  /// The level's par: about how long a steady player takes. Overtime starts there. Endless and practice modes have none.
  private func par() -> Double {
    switch mode {
    case .campaign, .daily: break
    default: return .infinity
    }
    let plain = spec.spawns.filter { $0.kind != .boss }
    let work = Double(Campaign.work(of: plain) + spec.surge * Campaign.work[2])
    let hits = spec.isBoss ? Double(bossHitsPerPhase * max(1, spec.bossPhases)) : 0
    return tuning.overtimeBase + tuning.overtimePerWork * work + tuning.overtimePerHit * hits
  }

  /// Puts a level's bubble in, crowned when it's a champion.
  @discardableResult
  private func place(_ s: Spawn, u: Double, v: Double, degrees: Double) -> Bubble {
    let b = put(s.kind, size: s.size, u: u, v: v, degrees: degrees)
    if s.champion && s.kind != .boss {
      b.champion = true
      b.armor += tuning.championArmor
      let sp = hypot(b.vx, b.vy), target = cruise(b)
      if sp > 0 { b.vx *= target / sp; b.vy *= target / sp }
    }
    return b
  }

  // MARK: Building

  @discardableResult
  public func add(_ kind: ActorKind, size: Int, x: Double, y: Double, angle: Double, grace: Double = 0, speed: Double = 1) -> Bubble {
    let b = Bubble(id: nextId, kind: kind, size: size, x: x, y: y, vx: 0, vy: 0, r: radius(of: kind, size: size), grace: grace)
    nextId += 1
    let sp = cruise(b) * speed
    b.vx = cos(angle) * sp; b.vy = sin(angle) * sp
    if kind == .armored { b.armor = 1 }
    if kind != .boss && spec.has(.ghost) { b.ghostClock = ghostGap() * (0.35 + 0.5 * twistRng.unit()) }
    b.side = sideOf(b)
    bubbles.append(b)
    return b
  }

  /// Places a bubble by fractions: u along the hinge, v across it (below 0.5 is the near side).
  @discardableResult
  public func put(_ kind: ActorKind, size: Int, u: Double, v: Double, degrees: Double, speed: Double = 1) -> Bubble {
    let a = degrees * .pi / 180
    let span = h - top
    let toward = v < 0.5 ? 1.0 : -1.0
    let al = cos(a), ac = abs(sin(a)) * toward
    let nearLen = vertical ? hinge : hinge - top, farLen = vertical ? w - hinge : h - hinge
    let acrossAt = v < 0.5 ? v * 2 * nearLen : (v - 0.5) * 2 * farLen
    if vertical {
      return add(kind, size: size, x: v < 0.5 ? acrossAt : hinge + acrossAt, y: top + u * span, angle: atan2(al, ac), speed: speed)
    }
    return add(kind, size: size, x: u * w, y: v < 0.5 ? top + acrossAt : hinge + acrossAt, angle: atan2(ac, al), speed: speed)
  }

  private func spawnLevel() {
    if isVersus {
      // Exact mirrors, so neither player starts ahead.
      for (j, s) in spec.spawns.enumerated() {
        let u = Double(j + 1) / Double(spec.spawns.count + 1), deg = j % 2 == 0 ? 35.0 : 145.0
        put(s.kind, size: s.size, u: u, v: 0.2, degrees: deg)
        put(s.kind, size: s.size, u: u, v: 0.8, degrees: deg)
      }
      return
    }
    // Only what a person can handle comes in first. The rest follows as the arena clears.
    var opening: [Spawn] = [], work = 0
    for (i, s) in spec.spawns.enumerated() {
      let cost = Campaign.work(of: [s])
      if i == 0 || work + cost <= tuning.arrivalOpening { opening.append(s); work += cost } else { arrivals.append(s) }
    }
    let firstId = nextId
    let near = Int((Double(opening.count) / 2).rounded(.up))
    for (i, s) in opening.enumerated() {
      let inNear = i < near
      let row = inNear ? i : i - near
      let count = inNear ? near : opening.count - near
      let u = s.kind == .boss ? 0.5 : Double(row + 1) / Double(count + 1)
      let stagger = row % 2 == 0 ? 0.0 : 0.09
      let v = inNear ? 0.2 + stagger : 0.8 - stagger
      let deg = inNear ? (row % 2 == 1 ? 145.0 : 35.0) : (row % 2 == 1 ? 40.0 : 140.0)
      place(s, u: u, v: v, degrees: deg)
    }
    // Twin bosses: two smaller ones, one on each side, sharing one health bar and taking turns to wind up.
    if spec.boss == .twins, spec.isBoss, let first = bubbles.first(where: { $0.kind == .boss }) {
      first.shrink = tuning.twinScale; first.r = radius(first)
      let twin = put(.boss, size: 0, u: 0.5, v: 0.8, degrees: 140)
      twin.shrink = tuning.twinScale; twin.r = radius(twin)
      twin.bossClock = tuning.bossWindupEvery / 2
    }
    // Every campaign level from 2 hides one secret bubble, picked the same way each time.
    if case .campaign(let n) = mode, n >= 2 {
      let pool = bubbles.filter { $0.id >= firstId && $0.kind != .boss }
      if !pool.isEmpty { secretBubble = pool[n % pool.count].id }
    }
  }

  private func stepArrivals(_ real: Double) {
    guard !arrivals.isEmpty else { return }
    arrivalClock += real
    let onScreen = bubbles.reduce(0) { $0 + ($1.kind == .boss ? 16 : Campaign.work[$1.size]) }
    guard onScreen <= tuning.arrivalWork || arrivalClock >= tuning.arrivalGap else { return }
    bringNext()
  }

  private func bringNext() {
    guard !arrivals.isEmpty else { return }
    arrivalClock = 0
    let s = arrivals.removeFirst()
    let near = rng.int(2) == 0
    let b = place(s, u: 0.15 + rng.unit() * 0.7, v: near ? 0.12 : 0.88, degrees: 25 + rng.unit() * 130)
    b.grace = tuning.graceHinge
  }

  /// Surge: once the last arrival is in and the arena is thinning, the level's last push is announced, then lands.
  private func stepSurge(_ real: Double) {
    guard spec.surge > 0, !surgeDone, arrivals.isEmpty else { return }
    if surgeIn > 0 {
      surgeIn -= real
      if surgeIn <= 0 { launchSurge() }
      return
    }
    let onScreen = bubbles.reduce(0) { $0 + ($1.kind == .boss ? 16 : Campaign.work[$1.size]) }
    guard onScreen <= tuning.arrivalWork else { return }
    surgeIn = tuning.surgeWarn
    events.append(.surgeWarning(count: spec.surge))
  }

  /// Small bubbles rush in from both walls at once. Never a big one, so two bigs stay the most at a time.
  private func launchSurge() {
    guard !surgeDone else { return }
    surgeDone = true
    surgeIn = 0
    for i in 0..<spec.surge {
      let u = (Double(i / 2) + 0.5) / Double((spec.surge + 1) / 2)
      let near = i % 2 == 0
      let b = put(.basic, size: 2, u: 0.1 + 0.8 * u, v: near ? 0.06 : 0.94, degrees: near ? 40 + 100 * u : 140 - 100 * u)
      b.grace = tuning.graceHinge
    }
    events.append(.surge(count: spec.surge))
  }

  public func clearScene() {
    bubbles.removeAll(); pickups.removeAll(); gates.removeAll(); visitors.removeAll(); events.removeAll(); arrivals.removeAll(); ready = 0
    surgeDone = true; surgeIn = 0; overtimeAt = .infinity
  }
  public func addPickup(_ kind: PowerUp, x: Double, y: Double) {
    pickups.append(Pickup(id: nextId, kind: kind, x: x, y: y, life: tuning.pickupLife)); nextId += 1
  }
  public func addGate(at: Double) { gates.append(Gate(at: at, width: tuning.gateWidth * scale, dir: 1)) }

  // MARK: Input

  /// Finds what a touch reached. Pickups win, since they sit on top. In versus a touch stays on its side.
  public func hitPickup(x: Double, y: Double) -> Pickup? {
    let touch = (vertical ? x : y) < hinge ? -1 : 1
    return pickups.first {
      if isVersus && ((vertical ? $0.x : $0.y) < hinge ? -1 : 1) != touch { return false }
      return hypot($0.x - x, $0.y - y) <= 34 * max(1, scale)
    }
  }
  public func hit(x: Double, y: Double) -> Bubble? {
    let touch = (vertical ? x : y) < hinge ? -1 : 1
    var best: Bubble?, bestGap = Double.infinity
    for b in bubbles {
      if isVersus && b.side != touch { continue }
      let gap = hypot(b.x - x, b.y - y) - b.r
      if gap <= max(10, 26 - b.r), gap < bestGap { best = b; bestGap = gap }
    }
    return best
  }

  @discardableResult
  public func collect(_ pickup: Pickup) -> Bool {
    guard status == .playing, ready <= 0, let i = pickups.firstIndex(where: { $0.id == pickup.id }) else { return false }
    pickups.remove(at: i)
    let owner = isVersus && (vertical ? pickup.x : pickup.y) >= hinge ? 1 : 0
    players[owner].pickups += 1
    events.append(.collected(pickup.kind, x: pickup.x, y: pickup.y, player: owner))
    switch pickup.kind {
    case .overcharge: players[owner].overcharge = tuning.overchargeTime
    case .freeze: freeze = tuning.freezeTime
    case .focus: focus = tuning.focusTime; focusClock = 0
    case .shield: players[owner].shields = min(tuning.shields, players[owner].shields + 1)
    case .chainBurst:
      let radius = tuning.chainRadius * scale
      let reached = bubbles.filter { $0.kind != .boss && hypot($0.x - pickup.x, $0.y - pickup.y) <= radius && (!isVersus || playerIndex(of: $0) == owner) }
      for b in reached { burst(b, by: owner) }
      if let boss = bubbles.first(where: { $0.kind == .boss && hypot($0.x - pickup.x, $0.y - pickup.y) <= radius + $0.r }) { hitBoss(boss, by: owner) }
      checkEnd()
    }
    return true
  }

  private func points(_ b: Bubble, _ p: inout Player) -> Int {
    var value = Double(tuning.points[b.size]) * p.combo
    if b.kind == .golden { value *= Double(tuning.goldenMultiplier) }
    if p.overcharge > 0 { value *= 2 }
    if onRush(b) { value *= tuning.rushPoints }
    if p.fever > 0 { value *= tuning.feverPoints }
    return Int(value.rounded())
  }

  private func bumpCombo(_ owner: Int, by step: Double? = nil) {
    players[owner].combo = min(tuning.comboMax, players[owner].combo + (step ?? tuning.comboStep))
    players[owner].bestCombo = max(players[owner].bestCombo, players[owner].combo)
    players[owner].comboT = max(players[owner].comboT, tuning.comboWindow)
    checkFever(owner)
  }

  /// A combo filled to the top starts a fever. Practice never does.
  private func checkFever(_ owner: Int) {
    guard mode != .sandbox, players[owner].fever <= 0, players[owner].combo >= tuning.comboMax else { return }
    players[owner].fever = tuning.feverTime
    players[owner].fevers += 1
    events.append(.feverStart(player: owner))
  }

  /// The fever burns out (or a crossing puts it out). The combo is spent.
  private func endFever(_ owner: Int) {
    guard players[owner].fever > 0 else { return }
    players[owner].fever = 0
    players[owner].combo = 1; players[owner].comboT = 0
    events.append(.feverEnd(player: owner))
  }

  /// On a fold, a pop on the other page from the last one, inside the combo window, adds a crossfold step.
  private func crossfold(_ b: Bubble, owner: Int, fresh: Bool) {
    guard pagePlay else { return }
    let page = b.side
    defer { lastPage[owner] = page }
    guard !fresh, lastPage[owner] != 0, page != lastPage[owner] else { return }
    bumpCombo(owner, by: tuning.crossfoldStep)
    players[owner].crossfolds += 1
    events.append(.crossfold(x: b.x, y: b.y, combo: players[owner].combo))
  }

  private func revealSecret(_ b: Bubble) {
    guard b.id == secretBubble, case .campaign(let n) = mode else { return }
    secretBubble = nil
    events.append(.secretBubble(level: n, x: b.x, y: b.y))
  }

  private func advanceStreak(_ owner: Int) {
    players[owner].streak += 1
    guard players[owner].streak >= tuning.rechargeStreak else { return }
    players[owner].streak = 0
    if players[owner].shields < tuning.shields {
      players[owner].shields += 1
      players[owner].recharges += 1
      events.append(.recharge(player: owner))
    } else if players[owner].meter > 0 {
      players[owner].meter = 0
      events.append(.cooled(player: owner))
    }
  }

  /// A touch on a bubble. A flick direction aims the pieces, and a harder flick launches them faster.
  /// `atX`/`atY` is where the touch landed, which matters only for a shielded boss.
  /// A bubble you can't reach (fogged, dark or out of phase) ignores the touch.
  @discardableResult
  public func tap(_ b: Bubble, dirX: Double? = nil, dirY: Double? = nil, atX: Double? = nil, atY: Double? = nil) -> Bool {
    guard status == .playing, ready <= 0, bubbles.contains(where: { $0 === b }) else { return false }
    guard canTouch(b) else { events.append(.untouchable(x: b.x, y: b.y, r: b.r)); return false }
    let owner = playerIndex(of: b)
    players[owner].taps += 1
    if dirX != nil { players[owner].flicks += 1 }
    if b.kind == .boss {
      if b.bossGuard > 0 {
        events.append(.bossBlocked(x: b.x, y: b.y, r: b.r))
        return true
      }
      if let atX, let atY, shieldCovers(b, x: atX, y: atY) {
        events.append(.bossShielded(x: b.x, y: b.y, r: b.r))
        return true
      }
      // A boss hit doesn't feed the streak, or the fight would refill its own shields.
      hitBoss(b, by: owner)
      checkEnd()
      return true
    }
    if b.armor > 0 {
      b.armor -= 1
      let pts = Int(Double(tuning.armorPoints) * players[owner].combo * (b.champion ? 2 : 1))
      players[owner].score += pts
      bumpCombo(owner)
      impact(b, 0, cruise(b))
      advanceStreak(owner)
      events.append(b.champion
        ? .championCrack(x: b.x, y: b.y, r: b.r, points: pts, armorLeft: b.armor)
        : .armorCrack(x: b.x, y: b.y, r: b.r, points: pts))
      return true
    }
    revealSecret(b)
    var pts = points(b, &players[owner])
    // Pulse: a pop on the beat scores double and adds an extra combo step.
    let beatHit = onBeat
    if beatHit { pts *= 2 }
    players[owner].score += pts
    let fresh = players[owner].comboT <= 0
    bumpCombo(owner)
    if beatHit { bumpCombo(owner); events.append(.beatPop(x: b.x, y: b.y, points: pts)) }
    crossfold(b, owner: owner, fresh: fresh)
    advanceStreak(owner)
    remove(b)
    if b.size < 3 { splitPieces(b, dirX: dirX, dirY: dirY) }
    events.append(b.size < 3
      ? .split(x: b.x, y: b.y, r: b.r, size: b.size, points: pts, kind: b.kind)
      : .pop(x: b.x, y: b.y, r: b.r, size: b.size, points: pts, kind: b.kind))
    maybeDrop(x: b.x, y: b.y, size: b.size)
    if b.size == 3 { chainFrom(b, owner: owner) }
    checkEnd()
    return true
  }

  /// One stroke of a finger. Everything the segment crosses gets hit, and its pieces fly the way the finger is
  /// moving, faster for a faster stroke. `skip` lets the caller keep one stroke from hitting a bubble twice.
  /// Pieces fresh from a split can't be hit until their grace ends, so a straight swipe doesn't shred everything.
  @discardableResult
  public func slice(fromX x0: Double, fromY y0: Double, toX x1: Double, toY y1: Double, skip: inout Set<Int>) -> Int {
    guard status == .playing, ready <= 0 else { return 0 }
    let dx = x1 - x0, dy = y1 - y0, len2 = dx * dx + dy * dy
    guard len2 > 0 else { return 0 }
    let touch = (vertical ? x0 : y0) < hinge ? -1 : 1
    let reach = tuning.sliceReach * max(1, scale)
    var hits: [(Bubble, Double)] = []
    for b in bubbles where b.grace <= 0 && !skip.contains(b.id) && canTouch(b) {
      if isVersus && b.side != touch { continue }
      let t = max(0, min(1, ((b.x - x0) * dx + (b.y - y0) * dy) / len2))
      let px = x0 + dx * t, py = y0 + dy * t
      if hypot(b.x - px, b.y - py) <= b.r + reach { hits.append((b, t)) }
    }
    hits.sort { $0.1 < $1.1 }
    var count = 0
    for v in visitors where !skip.contains(v.id) && v.presence > 0.35 {
      let t = max(0, min(1, ((v.x - x0) * dx + (v.y - y0) * dy) / len2))
      guard hypot(v.x - (x0 + dx * t), v.y - (y0 + dy * t)) <= visitorRadius + reach else { continue }
      skip.insert(v.id)
      catchVisitor(v.id, owner: 0)
    }
    let len = len2.squareRoot()
    for (b, _) in hits where status == .playing {
      skip.insert(b.id)
      // A swipe meets a bubble on the side it came from.
      if tap(b, dirX: dx * 3, dirY: dy * 3, atX: b.x - dx / len * b.r, atY: b.y - dy / len * b.r) { count += 1 }
    }
    if count > 0 { players[isVersus && touch > 0 ? 1 : 0].slices += 1 }
    return count
  }

  /// Tiny bubbles set each other off. It's how a crowd of them gets cleared in one touch.
  private func chainFrom(_ start: Bubble, owner: Int) {
    let radius = tuning.chainPopRadius * scale
    var frontier = [(start.x, start.y)]
    var count = 0
    while let (x, y) = frontier.popLast() {
      for b in bubbles where b.size == 3 && hypot(b.x - x, b.y - y) <= radius {
        if isVersus && playerIndex(of: b) != owner { continue }
        count += 1
        var multiplier = players[owner].combo + tuning.chainStep * Double(count)
        if players[owner].overcharge > 0 { multiplier *= 2 }
        if b.kind == .golden { multiplier *= Double(tuning.goldenMultiplier) }
        let pts = Int((Double(tuning.points[3]) * multiplier).rounded())
        players[owner].score += pts
        players[owner].chained += 1
        remove(b)
        frontier.append((b.x, b.y))
        events.append(.chainPop(x: b.x, y: b.y, r: b.r, points: pts, count: count))
      }
    }
  }

  private func splitPieces(_ b: Bubble, dirX: Double?, dirY: Double?) {
    let childR = radius(of: b.kind.childKind, size: b.size + 1)
    let aimed = dirX != nil
    let base = aimed ? atan2(dirY ?? 0, dirX ?? 0) : atan2(b.vy, b.vx)
    let spread = aimed ? 0.35 : 0.96
    let launch = aimed ? 1 + min(1, hypot(dirX ?? 0, dirY ?? 0) / 120) : 1
    // Triple: three pieces, each a little lighter on the meter.
    let triple = spec.has(.triple)
    for sign in triple ? [-1.15, 0, 1.15] : [-1.0, 1.0] {
      let a = base + sign * spread
      let piece = add(b.kind.childKind, size: b.size + 1, x: b.x + cos(a) * childR * 0.7, y: b.y + sin(a) * childR * 0.7, angle: a, grace: tuning.graceTap, speed: launch)
      if triple { piece.light = true }
      if spec.has(.blackout) { piece.lit = tuning.litTime }
    }
  }

  /// Chain Burst and Focus use this: it pops or splits without counting as a tap.
  private func burst(_ b: Bubble, by owner: Int) {
    guard bubbles.contains(where: { $0 === b }) else { return }
    revealSecret(b)
    b.armor = 0
    let pts = points(b, &players[owner])
    players[owner].score += pts
    remove(b)
    if b.size < 3 { splitPieces(b, dirX: nil, dirY: nil) }
    events.append(b.size < 3
      ? .split(x: b.x, y: b.y, r: b.r, size: b.size, points: pts, kind: b.kind)
      : .pop(x: b.x, y: b.y, r: b.r, size: b.size, points: pts, kind: b.kind))
  }

  /// Bosses get tougher chapter by chapter.
  public var bossHitsPerPhase: Int {
    // The first chapters add a hit each; after that every third realm adds one more.
    let realm = (max(1, spec.chapter) - 1) / 8
    var hits = max(1, tuning.bossHitsPerPhase - 1 + min(4, max(1, spec.chapter)) + realm / 3)
    // A four-phase finale is long enough already, so each of its phases is a little shorter.
    if spec.bossPhases >= 4 { hits = hits * 3 / 4 }
    // Twins share one bar, and you can hit one while the other guards, so their bar is a little shorter.
    return spec.boss == .twins ? max(1, hits * 2 / 3) : hits
  }

  private func hitBoss(_ b: Bubble, by owner: Int) {
    let staggered = b.bossWindup > 0
    if staggered { b.bossWindup = 0; b.bossDashing = false; b.bossClock = 0; b.blinked = false }
    let damage = staggered ? 2 : 1
    let pts = Int(Double(tuning.points[1]) * players[owner].combo) * (players[owner].overcharge > 0 ? 2 : 1) * damage
    players[owner].score += pts
    bumpCombo(owner)
    b.bossHits += damage
    b.bossGuard = tuning.bossGuard
    impact(b, 0, cruise(b) * 2)
    events.append(staggered ? .bossStagger(x: b.x, y: b.y, r: b.r, points: pts) : .bossHit(x: b.x, y: b.y, r: b.r, points: pts, phase: b.bossPhase))
    // Twins share one health bar.
    let twins = spec.boss == .twins ? bubbles.filter { $0.kind == .boss && $0 !== b } : []
    guard b.bossHits >= bossHitsPerPhase else { for t in twins { t.bossHits = b.bossHits }; return }
    b.bossHits = 0
    b.bossPhase += 1
    b.bossWindup = 0; b.bossDashing = false; b.bossClock = 0; b.blinked = false
    for t in twins { t.bossHits = 0; t.bossPhase = b.bossPhase }
    events.append(.bossPhase(x: b.x, y: b.y, r: b.r, phase: b.bossPhase))
    if b.bossPhase >= max(1, spec.bossPhases) {
      remove(b)
      for t in twins { remove(t); events.append(.bossPhase(x: t.x, y: t.y, r: t.r, phase: t.bossPhase)) }
      players[owner].score += tuning.points[3] * 4
      return
    }
    switch spec.boss {
    case .splitter:
      // It sheds a fast piece of itself and comes back smaller and quicker.
      b.shrink *= tuning.splitterShrink
      b.r = radius(b)
      let away = atan2(b.vy, b.vx) + .pi
      add(.fast, size: 1, x: b.x + cos(away) * b.r, y: b.y + sin(away) * b.r, angle: away, grace: tuning.graceTap)
      for i in 0..<(b.bossPhase - 1) {
        let a = away + (i % 2 == 0 ? 1.4 : -1.4)
        add(.fast, size: 2, x: b.x + cos(a) * b.r, y: b.y + sin(a) * b.r, angle: a, grace: tuning.graceTap)
      }
      events.append(.bossSplit(x: b.x, y: b.y, r: b.r))
    case .summoner:
      // A wave of basics marches in from its own wall.
      let count = 2 + b.bossPhase
      for i in 0..<count {
        let u = (Double(i) + 0.5) / Double(count)
        let kind: ActorKind = b.bossPhase >= 3 && i == count / 2 ? .armored : .basic
        let m = put(kind, size: kind == .armored ? 1 : 2, u: u, v: b.side < 0 ? 0.06 : 0.94, degrees: 35 + 110 * u)
        m.grace = tuning.graceHinge
      }
      events.append(.bossSummon(x: b.x, y: b.y, r: b.r, count: count))
    default:
      // Each phase calls in more help, armored from the third on.
      let helpers = tuning.bossMinions + b.bossPhase - 1
      for i in 0..<helpers {
        let a = Double(i) / Double(helpers) * 2 * .pi + 0.4
        let kind: ActorKind = b.bossPhase >= 3 && i == 0 ? .armored : .fast
        add(kind, size: kind == .armored ? 1 : 2, x: b.x + cos(a) * b.r, y: b.y + sin(a) * b.r, angle: a, grace: tuning.graceTap)
      }
    }
    // The first phase also leaves a Chain Burst to deal with the help.
    if b.bossPhase == 1 { addPickup(.chainBurst, x: b.x, y: b.y) }
  }

  private func maybeDrop(x: Double, y: Double, size: Int) {
    guard mode != .sandbox, rng.unit() < tuning.dropChance else { return }
    let kind = PowerUp.allCases[rng.int(PowerUp.allCases.count)]
    addPickup(kind, x: x, y: y)
    events.append(.dropped(kind, x: x, y: y))
  }

  private func remove(_ b: Bubble) { bubbles.removeAll { $0 === b } }

  private func impact(_ b: Bubble, _ normal: Double, _ strength: Double) {
    let q = min(1, strength / (tuning.speeds[b.size] * scale))
    if q > b.sq { b.sq = q; b.sqA = normal }
  }

  // MARK: Hinge

  /// True when a touch landed on the line itself.
  public func onHinge(x: Double, y: Double) -> Bool {
    guard y >= top else { return false }
    return abs((vertical ? x : y) - hinge) <= tuning.snapTouch * max(1, scale)
  }

  /// Snap the Hinge. The line cracks like a whip and flings what's near it back, lighter bubbles hardest.
  /// Bosses are too heavy to care, and tiny bubbles are left alone since the line pops those for free.
  /// In versus it only moves your own side. Returns false while it's recharging.
  @discardableResult
  public func snap(along: Double, owner: Int = 0) -> Bool {
    guard status == .playing, ready <= 0, players[owner].snapLeft <= 0 else { return false }
    players[owner].snapLeft = tuning.snapCooldown
    players[owner].snaps += 1
    let flung = fling(reach: tuning.snapReach * scale, owner: owner)
    events.append(.hingeSnap(along: along, player: owner, flung: flung))
    return true
  }

  /// True when a touch is beside the crease, close enough to clap it. Returns the page it's on.
  public func besideCrease(x: Double, y: Double) -> Int? {
    guard pagePlay, y >= top else { return nil }
    let gap = (vertical ? x : y) - hinge
    guard abs(gap) <= tuning.clapReach * max(1, scale) else { return nil }
    return gap < 0 ? -1 : 1
  }

  /// Crease Clap, iPhone Duo only: both pages touched beside the fold at once. It throws back everything along
  /// the whole line, further than a snap reaches, and shares the snap's recharge.
  @discardableResult
  public func clap() -> Bool {
    guard pagePlay, status == .playing, ready <= 0, players[0].snapLeft <= 0 else { return false }
    players[0].snapLeft = tuning.snapCooldown
    players[0].claps += 1
    let flung = fling(reach: tuning.snapReach * tuning.clapSweep * scale, owner: 0)
    events.append(.creaseClap(flung: flung))
    return true
  }

  private func fling(reach: Double, owner: Int) -> Int {
    var flung = 0
    for b in bubbles where b.kind != .boss && b.size < 3 {
      if isVersus && playerIndex(of: b) != owner { continue }
      let gap = across(b) - hinge
      guard abs(gap) <= reach else { continue }
      let dir = gap >= 0 ? 1.0 : -1.0
      let push = tuning.snapForce * scale * (1 - abs(gap) / reach * 0.5) / (mass(b) / 2).squareRoot()
      if vertical { b.vx = dir * max(abs(b.vx), push) } else { b.vy = dir * max(abs(b.vy), push) }
      impact(b, vertical ? 0 : .pi / 2, push)
      flung += 1
    }
    return flung
  }

  private func inGate(_ b: Bubble) -> Bool {
    let pos = along(b)
    return gates.contains { abs(pos - $0.at) <= $0.width / 2 }
  }

  /// The smallest size pops on the hinge at no cost. Combo and streak are left untouched.
  private func zap(_ b: Bubble) {
    let owner = playerIndex(of: b)
    let pts = tuning.points[b.size]
    players[owner].zaps += 1
    players[owner].score += pts
    remove(b)
    events.append(.zap(x: b.x, y: b.y, r: b.r, points: pts))
    checkEnd()
  }

  private func charge(_ owner: Int, _ amount: Int) {
    for _ in 0..<amount where status == .playing {
      players[owner].meter += 1
      guard players[owner].meter >= meterMax else { continue }
      players[owner].meter = 0
      players[owner].shields -= 1
      players[owner].shieldsLost += 1
      events.append(.shieldLost(player: owner))
      if players[owner].shields <= 0 {
        if isVersus { status = .ended; winner = 1 - owner } else if mode != .sandbox { status = .lost }
        if mode == .sandbox { players[owner].shields = 1 } else { events.append(.finished) }
      }
    }
  }

  /// b.side still holds the side the bubble left, so the cost goes to that player.
  private func cross(_ b: Bubble, to newSide: Int) {
    let owner = playerIndex(of: b)
    players[owner].crossings += 1
    endFever(owner)
    players[owner].combo = 1; players[owner].comboT = 0
    players[owner].streak = 0
    remove(b)
    events.append(.crossed(x: b.x, y: b.y, r: b.r, size: b.size, player: owner))
    let childSize = b.size + 1, childKind = b.kind.childKind
    let childR = radius(of: childKind, size: childSize)
    let heading = atan2(b.vy, b.vx)
    let outward = vertical ? (newSide > 0 ? 0 : Double.pi) : (newSide > 0 ? Double.pi / 2 : -Double.pi / 2)
    for sign in [-1.0, 1.0] {
      if graceOn {
        let off = childR + 2, al = sign * childR
        let x = vertical ? hinge + Double(newSide) * off : b.x + al
        let y = vertical ? b.y + al : hinge + Double(newSide) * off
        add(childKind, size: childSize, x: x, y: y, angle: outward + sign * 0.87, grace: tuning.graceHinge).light = b.light
      } else {
        add(childKind, size: childSize, x: b.x, y: b.y, angle: heading + sign * 0.96).light = b.light
      }
    }
    charge(owner, crossingCost(size: b.size, light: b.light) * (players[owner].overcharge > 0 ? 2 : 1))
    checkEnd()
  }

  /// Heavier bubbles hit harder. A big one fills the meter by itself, and each generation of its pieces costs
  /// a full meter again, so a big bubble left completely alone always takes all three shields with it.
  public func crossingCost(size: Int) -> Int {
    switch size {
    case 0: meterMax
    case 1: (meterMax + 1) / 2
    default: 1
    }
  }

  /// Triple: a medium piece from a three-way split costs a step less (never less than 1).
  public func crossingCost(size: Int, light: Bool) -> Int {
    light && size == 1 ? max(1, crossingCost(size: size) - 1) : crossingCost(size: size)
  }

  private func checkEnd() {
    guard status == .playing, bubbles.isEmpty else { return }
    if !arrivals.isEmpty { bringNext(); return }
    if spec.surge > 0, !surgeDone, mode != .sandbox {
      if surgeIn <= 0 { events.append(.surgeWarning(count: spec.surge)) }
      launchSurge(); return
    }
    switch mode {
    case .sandbox: return
    case .arcade: spawnWave(); return
    case .versus:
      status = .ended
      winner = players[0].score == players[1].score ? nil : (players[0].score > players[1].score ? 0 : 1)
    default:
      status = .won
      if players[0].crossings == 0 {
        cleanBonus = true
        players[0].score = Int((Double(players[0].score) * tuning.cleanBonus).rounded())
      }
    }
    events.append(.finished)
  }

  private func spawnWave() {
    waves += 1
    let count = 1 + min(3, waves / 3)
    let pool: [ActorKind] = waves < 3 ? [.basic, .fast] : [.basic, .fast, .armored, .magnetic, .repel, .golden, .frozen]
    for _ in 0..<count {
      let kind = pool[rng.int(pool.count)]
      let near = rng.int(2) == 0
      put(kind, size: kind == .fast || kind == .golden ? 1 : 0, u: 0.15 + rng.unit() * 0.7, v: near ? 0.14 : 0.86, degrees: 20 + rng.unit() * 140)
    }
    waveClock = max(3.5, 9 - Double(waves) * 0.25)
    events.append(.wave(waves))
  }

  // MARK: Time

  public func step(_ real: Double) {
    guard status == .playing else { return }
    if ready > 0 { ready -= real; return }
    time += real
    if freeze > 0 { freeze = max(0, freeze - real) }
    let dt = freeze > 0 ? real * tuning.freezeScale : real

    stepOvertime()
    for i in players.indices {
      if players[i].fever > 0 {
        // A fever holds the combo, then spends it.
        players[i].comboT = max(players[i].comboT, tuning.comboWindow)
        if players[i].fever <= real { endFever(i) } else { players[i].fever -= real }
      } else if players[i].comboT > 0 {
        players[i].comboT -= real
        if players[i].comboT <= 0 { players[i].combo = 1 }
      }
      if players[i].overcharge > 0 { players[i].overcharge = max(0, players[i].overcharge - real) }
      if players[i].snapLeft > 0 {
        players[i].snapLeft -= real
        if players[i].snapLeft <= 0 { players[i].snapLeft = 0; events.append(.snapReady(player: i)) }
      }
    }
    stepRush(real)
    stepFocus(real)
    stepPickups(real)
    stepVisitors(real)
    stepArrivals(real)
    stepSurge(real)
    stepGates(dt)
    stepBosses(dt)
    stepTwists(dt, real: real)
    applyFields(dt)
    applyWells(dt)
    move(dt)
    collideAll()
    resolveCrossings()
    if case .arcade = mode, status == .playing {
      waveClock -= real
      if waveClock <= 0 { spawnWave() }
    }
  }

  /// Past par, everything speeds up a step every few seconds, and what's still waiting comes in sooner.
  private func stepOvertime() {
    guard overtimeAt.isFinite, overtime < tuning.overtimeSteps else { return }
    guard time >= overtimeAt + Double(overtime) * tuning.overtimeEvery else { return }
    overtime += 1
    events.append(.overtime(step: overtime))
    if !arrivals.isEmpty { bringNext() }
    for b in bubbles { impact(b, 0, cruise(b) * 0.5) }
  }

  /// Every so often the busier page lights up. Its bubbles hurry and score double until it settles.
  private func stepRush(_ real: Double) {
    guard pagePlay else { return }
    if rushLeft > 0 {
      rushLeft -= real
      if rushLeft <= 0 { rushLeft = 0; rushSide = 0; events.append(.rushOver) }
      return
    }
    rushClock -= real
    guard rushClock <= 0, !bubbles.isEmpty else { return }
    rushClock = tuning.rushEvery
    let near = bubbles.filter { $0.side < 0 }.count, far = bubbles.count - near
    rushTurn += 1
    rushSide = near > far ? -1 : far > near ? 1 : (rushTurn % 2 == 0 ? -1 : 1)
    rushLeft = tuning.rushTime
    events.append(.rushStart(side: rushSide))
  }

  private func stepFocus(_ real: Double) {
    guard focus > 0 else { return }
    focus = max(0, focus - real)
    focusClock -= real
    guard focusClock <= 0 else { return }
    focusClock = tuning.focusInterval
    if let b = bubbles.filter({ $0.size == 3 }).first ?? bubbles.filter({ $0.size == 2 && $0.armor == 0 }).first {
      burst(b, by: playerIndex(of: b))
      checkEnd()
    }
  }

  /// The wind-up telegraphs a dash straight at the hinge. Hit it in time and it staggers instead.
  private func stepBosses(_ dt: Double) {
    for b in bubbles where b.kind == .boss {
      if b.bossGuard > 0 { b.bossGuard -= dt }
      // In its last phase it keeps shedding small pieces toward the line, so the end of a fight is the hardest part.
      if spec.bossPhases > 1, b.bossPhase >= spec.bossPhases - 1, mode != .sandbox {
        b.shedClock += dt
        if b.shedClock >= tuning.bossShedEvery * (spec.boss == .twins ? 2 : 1) {
          b.shedClock = 0
          let toward = vertical ? (hinge > b.x ? 0.0 : Double.pi) : (hinge > b.y ? Double.pi / 2 : -Double.pi / 2)
          let a = toward + (twistRng.unit() - 0.5) * 1.2
          add(.basic, size: 2, x: b.x + cos(a) * b.r, y: b.y + sin(a) * b.r, angle: a, grace: tuning.graceTap)
          events.append(.bossShed(x: b.x, y: b.y, r: b.r))
        }
      }
      if spec.boss == .shielded {
        b.shieldAngle = (b.shieldAngle + tuning.shieldSpin * (1 + 0.25 * Double(b.bossPhase)) * dt).truncatingRemainder(dividingBy: 2 * .pi)
      }
      if b.bossWindup > 0 {
        b.bossWindup -= dt
        guard b.bossWindup <= 0 else { continue }
        b.bossWindup = 0
        // A blinker teleports first, then dashes from wherever it lands after a short echo.
        if spec.boss == .blinker && !b.blinked { blink(b); continue }
        b.blinked = false
        b.bossDashing = true
        let toHinge = hinge - across(b) > 0 ? 1.0 : -1.0
        let sp = cruise(b)
        if vertical { b.vx = toHinge * sp * 0.92; b.vy = (b.vy >= 0 ? 1 : -1) * sp * 0.39 }
        else { b.vy = toHinge * sp * 0.92; b.vx = (b.vx >= 0 ? 1 : -1) * sp * 0.39 }
      } else if !b.bossDashing {
        b.bossClock += dt
        // Twins take turns, so each winds up less often.
        if b.bossClock >= max(2.6, tuning.bossWindupEvery - tuning.bossWindupEveryPhase * Double(b.bossPhase)) * (spec.boss == .twins ? 1.7 : 1) {
          b.bossClock = 0
          b.bossWindup = tuning.bossWindupTime
          events.append(.bossWindup(x: b.x, y: b.y, r: b.r))
        }
      }
    }
  }

  // MARK: Cameos

  public var visitorRadius: Double { tuning.cameoRadius * scale }
  public func hitVisitor(x: Double, y: Double) -> Visitor? {
    visitors.first { $0.presence > 0.35 && hypot($0.x - x, $0.y - y) <= visitorRadius + 12 }
  }

  /// A touch on a visitor. The Chosen Fizz sees the first one coming.
  @discardableResult
  public func catchVisitor(_ id: Int, owner: Int = 0) -> Bool {
    guard status == .playing, ready <= 0, let i = visitors.firstIndex(where: { $0.id == id }) else { return false }
    if visitors[i].dodgesLeft > 0 {
      visitors[i].dodgesLeft -= 1
      let from = (visitors[i].x, visitors[i].y)
      visitors[i].baseY = max(top + 70 * scale, min(h - 70 * scale, visitors[i].baseY + (visitors[i].baseY > top + (h - top) / 2 ? -1 : 1) * 130 * scale))
      visitors[i].y = visitors[i].baseY
      visitors[i].prevY = visitors[i].baseY
      events.append(.cameoDodged(visitors[i].cameo, x: from.0, y: from.1))
      return true
    }
    let v = visitors.remove(at: i)
    let pts = Int(Double(tuning.cameoPoints) * players[owner].combo)
    players[owner].score += pts
    players[owner].cameos += 1
    bumpCombo(owner)
    events.append(.cameoCaught(v.cameo, x: v.x, y: v.y, points: pts, player: owner))
    gift(v, owner: owner)
    checkEnd()
    return true
  }

  private func gift(_ v: Visitor, owner: Int) {
    switch v.cameo {
    case .captainFizz:
      if players[owner].shields < tuning.shields { players[owner].shields += 1; players[owner].recharges += 1; events.append(.recharge(player: owner)) }
      else { players[owner].meter = 0; events.append(.cooled(player: owner)) }
    case .docFlux:
      players[owner].meter = 0
      events.append(.cooled(player: owner))
    case .sirGlowstick, .bigBurp:
      let radius = tuning.chainRadius * scale * (v.cameo == .bigBurp ? 1.3 : 1)
      for b in bubbles where b.kind != .boss && hypot(b.x - v.x, b.y - v.y) <= radius { burst(b, by: owner) }
      if let boss = bubbles.first(where: { $0.kind == .boss && hypot($0.x - v.x, $0.y - v.y) <= radius + $0.r }), boss.bossGuard <= 0 { hitBoss(boss, by: owner) }
    case .chosenFizz: freeze = tuning.freezeTime
    case .merlinFizz: focus = tuning.focusTime; focusClock = 0
    case .booBubble: players[owner].overcharge = tuning.overchargeTime
    case .discoDot:
      bumpCombo(owner, by: 3)
      players[owner].comboT = max(players[owner].comboT, tuning.comboWindow * 2)
    }
  }

  /// Brings a chosen guest on stage, part way across. For store captures and the guide.
  public func summon(_ cameo: Cameo) {
    cameoTurn = Cameo.allCases.firstIndex(of: cameo) ?? 0
    spawnVisitor()
    if let i = visitors.indices.last {
      visitors[i].age = tuning.cameoLife * 0.42
      visitors[i].life = tuning.cameoLife * 0.58
      visitors[i].x = visitors[i].startX + (w + 120 * scale) * 0.42 * visitors[i].dir
      visitors[i].prevX = visitors[i].x
    }
  }

  private func spawnVisitor() {
    let list = Cameo.allCases
    let cameo = list[((cameoTurn % list.count) + list.count) % list.count]
    cameoTurn += 1
    let dir: Double = cameoRng.int(2) == 0 ? 1 : -1
    let margin = 60 * scale
    let startX = dir > 0 ? -margin : w + margin
    let lo = top + 90 * scale, hi = max(lo + 1, h - 90 * scale)
    // The stomper walks the floor. Everyone else comes in at their own height.
    let y = cameo == .bigBurp ? h - visitorRadius - 8 : lo + cameoRng.unit() * (hi - lo)
    let v = Visitor(id: nextId, cameo: cameo, x: startX, y: y, prevX: startX, prevY: y, life: tuning.cameoLife, presence: cameo == .booBubble ? 0 : 1, startX: startX, baseY: y, dir: dir, dodgesLeft: cameo == .chosenFizz ? 1 : 0)
    nextId += 1
    visitors.append(v)
    events.append(.cameoArrived(cameo, x: v.x, y: y))
  }

  /// Each guest moves its own way: a hero's swoop, a time traveller's jumps, a knight's glide, and so on.
  private func stepVisitors(_ real: Double) {
    if !isVersus, mode != .sandbox {
      let allowed: Bool
      if case .campaign(let n) = mode { allowed = n >= 2 } else { allowed = true }
      if allowed, status == .playing {
        cameoClock -= real
        if cameoClock <= 0 {
          cameoClock = tuning.cameoGap + cameoRng.unit() * 6
          spawnVisitor()
        }
      }
    }
    if visitorsHeld { for i in visitors.indices { visitors[i].prevX = visitors[i].x; visitors[i].prevY = visitors[i].y }; return }
    for i in visitors.indices.reversed() {
      visitors[i].prevX = visitors[i].x; visitors[i].prevY = visitors[i].y
      visitors[i].age += real
      visitors[i].life -= real
      if visitors[i].life <= 0 { visitors.remove(at: i); continue }
      let v = visitors[i], u = v.age / tuning.cameoLife, t = v.age
      let run = (w + 120 * scale) * u * v.dir
      var nx = v.startX + run, ny = v.baseY
      switch v.cameo {
      case .captainFizz: ny = v.baseY + sin(t * 1.6) * 70 * scale
      case .docFlux:
        // Jumps ahead in steps, leaving a trail of fire where it was.
        let step = floor(u * 7) / 7
        nx = v.startX + (w + 120 * scale) * step * v.dir
        ny = v.baseY + sin(step * 19) * 60 * scale
        if abs(nx - v.x) > 1 { events.append(.cameoBlink(v.cameo, fromX: v.x, fromY: v.y, x: nx, y: ny)) }
      case .sirGlowstick: ny = v.baseY + sin(t * 0.6) * 12 * scale
      case .chosenFizz: ny = v.baseY + sin(t * 2.4) * 8 * scale
      case .merlinFizz:
        let tri = abs((t * 0.9).truncatingRemainder(dividingBy: 2) - 1) * 2 - 1
        ny = v.baseY + tri * 80 * scale
      case .bigBurp:
        // Heavy hops along the floor.
        let hop = abs(sin(t * 2.2))
        ny = h - visitorRadius - 8 - hop * hop * 90 * scale
      case .booBubble:
        ny = v.baseY + sin(t * 1.1) * 26 * scale
        visitors[i].presence = 0.5 + 0.5 * sin(t * 1.9 - 1.2)
      case .discoDot:
        ny = v.baseY + sin(t * 3.4) * 50 * scale
        nx += sin(t * 1.7) * 26 * scale
      }
      let lo = top + visitorRadius, hi = h - visitorRadius
      visitors[i].x = nx
      visitors[i].y = max(lo, min(hi, ny))
    }
  }

  private func stepPickups(_ real: Double) {
    for i in pickups.indices.reversed() {
      pickups[i].life -= real
      pickups[i].y -= 6 * real
      if pickups[i].life <= 0 { pickups.remove(at: i) }
    }
  }

  private func stepGates(_ dt: Double) {
    let span = alongSpan
    for i in gates.indices {
      gates[i].at += gates[i].dir * tuning.gateSpeed * scale * spec.speed * dt
      if gates[i].at - gates[i].width / 2 < span.lowerBound { gates[i].dir = 1 }
      if gates[i].at + gates[i].width / 2 > span.upperBound { gates[i].dir = -1 }
    }
  }

  /// Magnetic bubbles pull and repel bubbles push everything nearby on their side of the hinge.
  private func applyFields(_ dt: Double) {
    let radius = tuning.fieldRadius * scale
    for source in bubbles where source.kind == .magnetic || source.kind == .repel {
      let sign = source.kind == .magnetic ? 1.0 : -1.0
      for b in bubbles where b !== source && b.side == source.side && b.kind != .boss {
        let dx = source.x - b.x, dy = source.y - b.y, d = hypot(dx, dy)
        guard d > 1, d < radius + source.r else { continue }
        let force = sign * tuning.fieldForce * scale * (1 - d / (radius + source.r)) * dt / max(1, tuning.mass[b.size] / 4)
        b.vx += dx / d * force; b.vy += dy / d * force
      }
    }
  }

  private func move(_ dt: Double) {
    for b in bubbles {
      b.prevX = b.x; b.prevY = b.y
      let speed = hypot(b.vx, b.vy)
      if speed > 0.001 {
        let target = cruise(b)
        let next = speed + (target - speed) * min(1, tuning.recover[b.size] * dt)
        b.vx *= next / speed; b.vy *= next / speed
        // A bubble gliding almost parallel to the hinge feels a faint pull, so no level can stall.
        let crossV = vertical ? b.vx : b.vy
        if abs(crossV) < speed * tuning.minCross {
          let pull = (hinge - across(b) > 0 ? 1.0 : -1.0) * speed * tuning.hingePull * dt
          if vertical { b.vx += pull } else { b.vy += pull }
        }
      }
      b.x += b.vx * dt; b.y += b.vy * dt
      // Coral Drift: the current carries everything along the hinge, turning around every few seconds.
      if spec.current != 0 && b.kind != .boss {
        let drift = spec.current * scale * sin(time * 2 * .pi / tuning.currentPeriod) * dt
        if vertical { b.y += drift } else { b.x += drift }
      }
      // Wind: a gust shoves everything across the line, the light pieces hardest.
      if wind != 0 && b.kind != .boss {
        let drift = wind * dt / max(1, mass(b) / 2).squareRoot()
        if vertical { b.x += drift } else { b.y += drift }
      }
      let springy = spec.has(.bounce) && b.kind != .boss
      if springy && b.spring > 1 { b.spring = max(1, b.spring - tuning.springEase * dt) }
      let bounce = b.kind == .boss ? 0.9 : springy ? 1.0 : tuning.bounce[b.size]
      // Portals: the two walls at the ends of the hinge lead into each other. Bosses are too big to fit.
      let portals = spec.has(.portals) && b.kind != .boss
      if portals { portal(b) }
      if !(portals && !vertical) {
        if b.x < b.r { impact(b, 0, abs(b.vx)); b.x = b.r; b.vx = abs(b.vx) * bounce; if springy { springHit(b) } }
        if b.x > w - b.r { impact(b, 0, abs(b.vx)); b.x = w - b.r; b.vx = -abs(b.vx) * bounce; if springy { springHit(b) } }
      }
      if !(portals && vertical) {
        if b.y < top + b.r { impact(b, .pi / 2, abs(b.vy)); b.y = top + b.r; b.vy = abs(b.vy) * bounce; if springy { springHit(b) } }
        if b.y > h - b.r { impact(b, .pi / 2, abs(b.vy)); b.y = h - b.r; b.vy = -abs(b.vy) * bounce; if springy { springHit(b) } }
      }
      if b.grace > 0 { b.grace -= dt }
      if b.contactCooldown > 0 { b.contactCooldown -= dt }
      if b.sq > 0 { b.sq = max(0, b.sq - b.sq * 9 * dt - 0.2 * dt) }
    }
  }

  /// Fresh pieces pass through each other, and the hinge keeps the two sides apart.
  private func collideAll() {
    let list = bubbles
    for i in list.indices where list[i].grace <= 0 {
      for j in (i + 1)..<max(i + 1, list.count) where list[j].grace <= 0 && list[i].side == list[j].side {
        collide(list[i], list[j])
      }
    }
  }

  /// Equal and opposite impulses along the line between centres, so momentum is conserved.
  private func collide(_ a: Bubble, _ b: Bubble) {
    let dx = b.x - a.x, dy = b.y - a.y, minDist = a.r + b.r, d2 = dx * dx + dy * dy
    guard d2 < minDist * minDist, d2 > 0 else { return }
    let d = d2.squareRoot(), nx = dx / d, ny = dy / d
    let inva = 1 / mass(a), invb = 1 / mass(b)
    let push = (minDist - d) / (inva + invb)
    a.x -= nx * push * inva; a.y -= ny * push * inva
    b.x += nx * push * invb; b.y += ny * push * invb
    let closing = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
    guard closing > 0 else { return }
    let e = min(tuning.bounce[a.size], tuning.bounce[b.size])
    let j = (1 + e) * closing / (inva + invb)
    a.vx -= j * inva * nx; a.vy -= j * inva * ny
    b.vx += j * invb * nx; b.vy += j * invb * ny
    let angle = atan2(ny, nx)
    impact(a, angle, j * inva); impact(b, angle, j * invb)
    if closing > 30 { events.append(.bump(strength: closing, size: min(a.size, b.size))) }
  }

  private func resolveCrossings() {
    for b in bubbles {
      let now = sideOf(b)
      guard now != b.side else { continue }
      guard status == .playing else { break }
      if b.kind == .boss { slamBoss(b); continue }
      // Ghost: a bubble out of phase can't cross. It glances off the line.
      if b.presence < 0.5 {
        if vertical { b.x = hinge + Double(b.side); b.vx = abs(b.vx) * Double(b.side) }
        else { b.y = hinge + Double(b.side); b.vy = abs(b.vy) * Double(b.side) }
        continue
      }
      if b.size == 3 { zap(b); continue }
      if b.grace > 0 { b.side = now; continue }
      if inGate(b) {
        b.side = now
        events.append(.gatePass(x: b.x, y: b.y, r: b.r))
        continue
      }
      cross(b, to: now)
    }
  }

  /// A boss is too big to cross. It slams the hinge and bounces, charging the meter. A dash hits much harder.
  private func slamBoss(_ b: Bubble) {
    let dashed = b.bossDashing
    b.bossDashing = false
    if vertical { b.x = hinge + Double(b.side) * 1; b.vx = abs(b.vx) * Double(b.side) }
    else { b.y = hinge + Double(b.side) * 1; b.vy = abs(b.vy) * Double(b.side) }
    impact(b, vertical ? 0 : .pi / 2, cruise(b))
    guard dashed || b.contactCooldown <= 0 else { return }
    b.contactCooldown = tuning.bossContactCooldown
    // Twins share their slam cooldown, so two of them aren't twice the pressure.
    if spec.boss == .twins { for t in bubbles where t.kind == .boss { t.contactCooldown = tuning.bossContactCooldown * 2 } }
    let owner = playerIndex(of: b)
    events.append(.bossSlam(x: b.x, y: b.y, r: b.r, player: owner))
    charge(owner, dashed ? tuning.bossDashCharge : 1)
  }

  // MARK: Twists

  /// Pulse: everything surges a little on each beat, then settles.
  private var surge: Double { spec.has(.pulse) ? 1 + tuning.beatSurge * spec.intensity * exp(-beatPhase * 7) : 1 }

  private func ghostGap() -> Double { tuning.ghostEvery * (0.75 + 0.5 * twistRng.unit()) / max(0.5, spec.intensity) }

  /// How far it is from a line across the arena to the wall on one side.
  private func depth(_ side: Int, from line: Double) -> Double {
    side < 0 ? (vertical ? line : line - top) : (vertical ? w - line : h - line)
  }

  /// Tide: how far the line travels either side of where it rests.
  public var tideReachNow: Double {
    let d = min(depth(-1, from: baseHinge), depth(1, from: baseHinge))
    return tuning.tideReach * spec.intensity * max(0, d) * (foldPlay ? 0.4 : 1)
  }

  /// Fog: how much of a bubble you can see, 0...1. Bosses are too big to hide.
  public func visibility(_ b: Bubble) -> Double {
    guard spec.has(.fog), b.kind != .boss else { return 1 }
    let side = across(b) < hinge ? -1 : 1
    let f = abs(across(b) - hinge) / max(1, depth(side, from: hinge))
    let clear = tuning.fogClear + (1 - min(1, spec.intensity)) * 0.3
    let t = max(0, min(1, (f - clear) / max(0.05, tuning.fogDense - clear)))
    return 1 - t * t * (3 - 2 * t)
  }

  /// Blackout: true when a bubble is lit (near the line, or near where you last touched). Bosses always glow.
  public func isLit(_ b: Bubble) -> Bool { !spec.has(.blackout) || b.kind == .boss || b.lit > 0 }

  /// True when a touch can reach this bubble: it's in phase, out of the fog and in the light.
  public func canTouch(_ b: Bubble) -> Bool { b.presence >= 0.5 && visibility(b) >= 0.4 && isLit(b) }

  /// Blackout: a touch leaves a pool of light behind it for a moment, lighting what's near.
  public func illuminate(x: Double, y: Double) {
    guard spec.has(.blackout) else { return }
    lantern = Lantern(x: x, y: y, left: tuning.lanternTime, reach: tuning.lanternReach * scale)
    lightUp()
  }

  /// Blackout: how wide the lit band is either side of the line.
  public var darkBand: Double { tuning.darkBand * scale * (1.25 - 0.25 * min(1.2, spec.intensity)) }

  private func lightUp() {
    let band = darkBand
    for b in bubbles {
      let near = abs(across(b) - hinge) - b.r <= band
      let lamp = lantern.map { hypot(b.x - $0.x, b.y - $0.y) - b.r <= $0.reach } ?? false
      if near || lamp { b.lit = tuning.litTime }
    }
  }

  /// Shielded boss: true when a touch at this point would land on its shield.
  public func shieldCovers(_ b: Bubble, x: Double, y: Double) -> Bool {
    guard spec.boss == .shielded, b.kind == .boss else { return false }
    var d = (atan2(y - b.y, x - b.x) - b.shieldAngle).truncatingRemainder(dividingBy: 2 * .pi)
    if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
    return abs(d) < tuning.shieldArc
  }

  private func stepTwists(_ dt: Double, real: Double) {
    if spec.has(.tide) {
      tideOffset = tideReachNow * sin(time * 2 * .pi / tuning.tidePeriod)
      hinge = baseHinge + tideOffset
    }
    if spec.has(.wind) { stepWind(dt) }
    if spec.has(.pulse) {
      let n = Int(time / tuning.beatPeriod)
      if n > beats { beats = n; events.append(.beat(n)) }
    }
    if spec.has(.ghost) {
      for b in bubbles where b.kind != .boss {
        b.ghostClock -= dt
        if b.ghostClock <= 0 {
          b.phasing.toggle()
          b.ghostClock = b.phasing ? tuning.ghostTime * (0.7 + 0.3 * min(1.3, spec.intensity)) : ghostGap()
        }
        let step = dt / tuning.ghostFade
        b.presence = b.phasing ? max(0, b.presence - step) : min(1, b.presence + step)
      }
    }
    if spec.has(.regrow) {
      let every = tuning.regrowTime / max(0.5, spec.intensity)
      for b in bubbles where b.kind != .boss && b.size >= 2 {
        // Small pieces take longer to grow back than tiny ones.
        b.regrow += dt / (b.size == 2 ? every * 1.5 : every)
        guard b.regrow >= 1 else { continue }
        b.regrow = 0
        b.size -= 1
        b.light = false
        b.r = radius(b)
        impact(b, 0, cruise(b))
        events.append(.regrow(x: b.x, y: b.y, r: b.r, size: b.size))
      }
    }
    if spec.has(.blackout) {
      if var l = lantern { l.left -= real; lantern = l.left > 0 ? l : nil }
      for b in bubbles where b.lit > 0 { b.lit = max(0, b.lit - dt) }
      lightUp()
    }
  }

  /// A gust every few seconds: calm, a warning, then a push across that swells and fades.
  private func stepWind(_ dt: Double) {
    windClock += dt
    let calm = tuning.windEvery - tuning.windTime
    if windClock < calm { gustIn = calm - windClock; wind = 0; return }
    if windClock - dt < calm { events.append(.gust(dir: windDir)) }
    let u = (windClock - calm) / tuning.windTime
    if u >= 1 {
      windClock = 0; wind = 0; gustIn = calm
      // Mostly it turns around, so neither side always takes the push.
      if twistRng.int(3) != 0 { windDir = -windDir }
      return
    }
    gustIn = 0
    wind = windDir * windPeak * sin(.pi * u)
  }

  private func makeWells() {
    let n = max(1, min(4, spec.wells))
    wells = (0..<n).map { i in
      let near = i % 2 == 0
      let u = n <= 2 ? (near ? 0.3 : 0.7) : 0.18 + 0.64 * Double(i) / Double(n - 1)
      return Well(x: 0, y: 0, reach: 0, spin: near ? 1 : -1, u: u, v: near ? 0.27 : 0.73)
    }
    placeWells()
  }

  private func placeWells() {
    for i in wells.indices {
      let v = wells[i].v
      let acrossAt = v < 0.5 ? (vertical ? 0 : top) + v * 2 * depth(-1, from: baseHinge) : baseHinge + (v - 0.5) * 2 * depth(1, from: baseHinge)
      if vertical { wells[i].x = acrossAt; wells[i].y = top + wells[i].u * (h - top) }
      else { wells[i].x = wells[i].u * w; wells[i].y = acrossAt }
      wells[i].reach = tuning.wellReach * scale * (0.85 + 0.15 * min(1.3, spec.intensity))
    }
  }

  /// Wells pull bubbles in and swing them round, heavier ones less.
  private func applyWells(_ dt: Double) {
    for well in wells {
      for b in bubbles where b.kind != .boss {
        let dx = well.x - b.x, dy = well.y - b.y, d = hypot(dx, dy)
        guard d > 1, d < well.reach else { continue }
        let fall = 1 - d / well.reach
        let k = scale * spec.intensity * dt / max(1, mass(b) / 4)
        let pull = tuning.wellPull * fall * min(1, d / (well.reach * 0.3)) * k
        let swirl = tuning.wellSwirl * fall * k * well.spin
        b.vx += dx / d * pull - dy / d * swirl
        b.vy += dy / d * pull + dx / d * swirl
      }
    }
  }

  /// Portals: past one end wall, out of the other, a little faster.
  private func portal(_ b: Bubble) {
    let fromX = b.x, fromY = b.y
    var wrapped = false
    if vertical {
      if b.y < top { b.y += h - top; wrapped = true } else if b.y > h { b.y -= h - top; wrapped = true }
    } else {
      if b.x < 0 { b.x += w; wrapped = true } else if b.x > w { b.x -= w; wrapped = true }
    }
    guard wrapped else { return }
    b.prevX = b.x; b.prevY = b.y
    let boost = 1 + (tuning.portalBoost - 1) * spec.intensity
    b.vx *= boost; b.vy *= boost
    events.append(.portal(fromX: fromX, fromY: fromY, x: b.x, y: b.y, r: b.r))
  }

  /// Bounce: springy walls add speed with every hit, up to a cap, and it eases off slowly.
  private func springHit(_ b: Bubble) {
    let cap = 1 + (tuning.springMax - 1) * min(1.2, spec.intensity)
    b.spring = min(cap, b.spring + tuning.springGain * spec.intensity)
    events.append(.spring(x: b.x, y: b.y, r: b.r))
  }

  /// Blinker boss: vanishes and lands somewhere near the line on its own side, then dashes after a short echo.
  private func blink(_ b: Bubble) {
    let from = (b.x, b.y)
    let side = Double(b.side)
    let span = alongSpan
    let along = span.lowerBound + b.r + max(0, span.upperBound - span.lowerBound - 2 * b.r) * (0.1 + 0.8 * twistRng.unit())
    let room = depth(b.side, from: hinge)
    let gap = max(b.r + 6, min(room - b.r, room * 0.4))
    if vertical { b.x = hinge + side * gap; b.y = along } else { b.x = along; b.y = hinge + side * gap }
    b.prevX = b.x; b.prevY = b.y
    b.blinked = true
    b.bossWindup = tuning.blinkEcho
    events.append(.bossBlink(fromX: from.0, fromY: from.1, x: b.x, y: b.y, r: b.r))
  }

  // MARK: Layout changes

  /// The window changed. Turning the device swaps the axes, so each bubble keeps its place relative to the hinge.
  @discardableResult
  public func resize(width: Double, height: Double, top newTop: Double, vertical newVertical: Bool? = nil, hinge newHinge: Double? = nil) -> Bool {
    let v = isVersus || (newVertical ?? (width > height))
    let turned = v != vertical
    let before = scale
    let oldW = w, oldH = h - top, oldTop = top
    let oldHinge = hinge
    w = width; h = height; top = newTop; vertical = v
    fixedHinge = newHinge
    baseHinge = newHinge ?? defaultHinge()
    tideOffset = spec.has(.tide) ? tideReachNow * sin(time * 2 * .pi / tuning.tidePeriod) : 0
    hinge = baseHinge + tideOffset
    lantern = nil
    let ratio = scale / before
    _ = oldHinge
    for b in bubbles {
      let u = b.x / oldW, t = (b.y - oldTop) / oldH
      b.x = (turned ? t : u) * w
      b.y = top + (turned ? u : t) * (h - top)
      if turned { swap(&b.vx, &b.vy) }
      b.vx *= ratio; b.vy *= ratio
      b.r = radius(b)
      b.side = sideOf(b)
      b.prevX = b.x; b.prevY = b.y
    }
    visitors.removeAll()
    placeWells()
    let span = alongSpan
    for i in gates.indices {
      gates[i].width = tuning.gateWidth * scale
      gates[i].at = min(span.upperBound, max(span.lowerBound, gates[i].at))
    }
    return turned
  }

  // MARK: Results

  /// The one rule for stars. Three: no shield lost, at most two crossings, and cleared before overtime
  /// (inside par, `overtimeAt`). Two: at most one shield lost. One: any clear.
  public var stars: Int {
    guard status == .won else { return 0 }
    let p = players[0]
    if p.shieldsLost == 0 && p.crossings <= 2 && overtime == 0 { return 3 }
    return p.shieldsLost <= 1 ? 2 : 1
  }
}
