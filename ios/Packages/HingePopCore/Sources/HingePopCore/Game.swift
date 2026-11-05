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
  var contactCooldown = 0.0
  init(id: Int, kind: ActorKind, size: Int, x: Double, y: Double, vx: Double, vy: Double, r: Double, grace: Double) {
    self.id = id; self.kind = kind; self.size = size; self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.r = r; self.grace = grace; side = 0
  }
}

public struct Pickup: Identifiable, Sendable {
  public let id: Int
  public let kind: PowerUp
  public var x: Double, y: Double
  public var life: Double
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
  case bump(strength: Double, size: Int)
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
  public private(set) var bubbles: [Bubble] = []
  public private(set) var pickups: [Pickup] = []
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
  private var nextId = 1
  private var rng: SplitMix
  private let isVersus: Bool
  public let meterMax: Int

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
    spawnLevel()
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

  public func radius(of kind: ActorKind, size: Int) -> Double {
    tuning.radii[size] * scale * (kind == .boss ? tuning.bossRadius : 1)
  }
  private func mass(_ b: Bubble) -> Double {
    b.kind == .boss ? tuning.bossMass : tuning.mass[b.size] * b.kind.massFactor
  }
  private func cruise(_ b: Bubble) -> Double {
    let phaseBoost = b.kind == .boss ? 1 + 0.2 * Double(b.bossPhase) : 1
    return tuning.speeds[b.size] * scale * spec.speed * b.kind.speedFactor * phaseBoost
  }

  // MARK: Building

  @discardableResult
  public func add(_ kind: ActorKind, size: Int, x: Double, y: Double, angle: Double, grace: Double = 0, speed: Double = 1) -> Bubble {
    let b = Bubble(id: nextId, kind: kind, size: size, x: x, y: y, vx: 0, vy: 0, r: radius(of: kind, size: size), grace: grace)
    nextId += 1
    let sp = cruise(b) * speed
    b.vx = cos(angle) * sp; b.vy = sin(angle) * sp
    if kind == .armored { b.armor = 1 }
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
    let near = Int((Double(spec.spawns.count) / 2).rounded(.up))
    for (i, s) in spec.spawns.enumerated() {
      let inNear = i < near
      let row = inNear ? i : i - near
      let count = inNear ? near : spec.spawns.count - near
      let u = s.kind == .boss ? 0.5 : Double(row + 1) / Double(count + 1)
      let stagger = row % 2 == 0 ? 0.0 : 0.09
      let v = inNear ? 0.2 + stagger : 0.8 - stagger
      let deg = inNear ? (row % 2 == 1 ? 145.0 : 35.0) : (row % 2 == 1 ? 40.0 : 140.0)
      put(s.kind, size: s.size, u: u, v: v, degrees: deg)
    }
  }

  public func clearScene() {
    bubbles.removeAll(); pickups.removeAll(); gates.removeAll(); events.removeAll(); ready = 0
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
    return Int(value.rounded())
  }

  private func bumpCombo(_ p: inout Player) {
    p.combo = min(tuning.comboMax, p.combo + tuning.comboStep)
    p.bestCombo = max(p.bestCombo, p.combo)
    p.comboT = tuning.comboWindow
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
  @discardableResult
  public func tap(_ b: Bubble, dirX: Double? = nil, dirY: Double? = nil) -> Bool {
    guard status == .playing, ready <= 0, bubbles.contains(where: { $0 === b }) else { return false }
    let owner = playerIndex(of: b)
    players[owner].taps += 1
    if dirX != nil { players[owner].flicks += 1 }
    if b.kind == .boss {
      hitBoss(b, by: owner)
      advanceStreak(owner)
      checkEnd()
      return true
    }
    if b.armor > 0 {
      b.armor = 0
      let pts = Int(Double(tuning.armorPoints) * players[owner].combo)
      players[owner].score += pts
      bumpCombo(&players[owner])
      impact(b, 0, cruise(b))
      advanceStreak(owner)
      events.append(.armorCrack(x: b.x, y: b.y, r: b.r, points: pts))
      return true
    }
    let pts = points(b, &players[owner])
    players[owner].score += pts
    bumpCombo(&players[owner])
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
    for b in bubbles where b.grace <= 0 && !skip.contains(b.id) {
      if isVersus && b.side != touch { continue }
      let t = max(0, min(1, ((b.x - x0) * dx + (b.y - y0) * dy) / len2))
      let px = x0 + dx * t, py = y0 + dy * t
      if hypot(b.x - px, b.y - py) <= b.r + reach { hits.append((b, t)) }
    }
    hits.sort { $0.1 < $1.1 }
    var count = 0
    for (b, _) in hits where status == .playing {
      skip.insert(b.id)
      if tap(b, dirX: dx * 3, dirY: dy * 3) { count += 1 }
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
    for sign in [-1.0, 1.0] {
      let a = base + sign * spread
      add(b.kind.childKind, size: b.size + 1, x: b.x + cos(a) * childR * 0.7, y: b.y + sin(a) * childR * 0.7, angle: a, grace: tuning.graceTap, speed: launch)
    }
  }

  /// Chain Burst and Focus use this: it pops or splits without counting as a tap.
  private func burst(_ b: Bubble, by owner: Int) {
    guard bubbles.contains(where: { $0 === b }) else { return }
    b.armor = 0
    let pts = points(b, &players[owner])
    players[owner].score += pts
    remove(b)
    if b.size < 3 { splitPieces(b, dirX: nil, dirY: nil) }
    events.append(b.size < 3
      ? .split(x: b.x, y: b.y, r: b.r, size: b.size, points: pts, kind: b.kind)
      : .pop(x: b.x, y: b.y, r: b.r, size: b.size, points: pts, kind: b.kind))
  }

  private func hitBoss(_ b: Bubble, by owner: Int) {
    let pts = Int(Double(tuning.points[1]) * players[owner].combo) * (players[owner].overcharge > 0 ? 2 : 1)
    players[owner].score += pts
    bumpCombo(&players[owner])
    b.bossHits += 1
    impact(b, 0, cruise(b) * 2)
    events.append(.bossHit(x: b.x, y: b.y, r: b.r, points: pts, phase: b.bossPhase))
    guard b.bossHits >= tuning.bossHitsPerPhase else { return }
    b.bossHits = 0
    b.bossPhase += 1
    events.append(.bossPhase(x: b.x, y: b.y, r: b.r, phase: b.bossPhase))
    for sign in [-1.0, 1.0] {
      add(.fast, size: 2, x: b.x + sign * b.r, y: b.y, angle: sign > 0 ? 0.4 : .pi - 0.4, grace: tuning.graceTap)
    }
    addPickup(.chainBurst, x: b.x, y: b.y)
    if b.bossPhase >= max(1, spec.bossPhases) {
      remove(b)
      players[owner].score += tuning.points[3] * 4
    }
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
        add(childKind, size: childSize, x: x, y: y, angle: outward + sign * 0.87, grace: tuning.graceHinge)
      } else {
        add(childKind, size: childSize, x: b.x, y: b.y, angle: heading + sign * 0.96)
      }
    }
    charge(owner, players[owner].overcharge > 0 ? 2 : 1)
    checkEnd()
  }

  private func checkEnd() {
    guard status == .playing, bubbles.isEmpty else { return }
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

    for i in players.indices {
      if players[i].comboT > 0 {
        players[i].comboT -= real
        if players[i].comboT <= 0 { players[i].combo = 1 }
      }
      if players[i].overcharge > 0 { players[i].overcharge = max(0, players[i].overcharge - real) }
    }
    stepFocus(real)
    stepPickups(real)
    stepGates(dt)
    applyFields(dt)
    move(dt)
    collideAll()
    resolveCrossings()
    if case .arcade = mode, status == .playing {
      waveClock -= real
      if waveClock <= 0 { spawnWave() }
    }
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
      let bounce = b.kind == .boss ? 0.9 : tuning.bounce[b.size]
      if b.x < b.r { impact(b, 0, abs(b.vx)); b.x = b.r; b.vx = abs(b.vx) * bounce }
      if b.x > w - b.r { impact(b, 0, abs(b.vx)); b.x = w - b.r; b.vx = -abs(b.vx) * bounce }
      if b.y < top + b.r { impact(b, .pi / 2, abs(b.vy)); b.y = top + b.r; b.vy = abs(b.vy) * bounce }
      if b.y > h - b.r { impact(b, .pi / 2, abs(b.vy)); b.y = h - b.r; b.vy = -abs(b.vy) * bounce }
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

  /// A boss is too big to cross. It slams the hinge and bounces, charging the meter.
  private func slamBoss(_ b: Bubble) {
    if vertical { b.x = hinge + Double(b.side) * 1; b.vx = abs(b.vx) * Double(b.side) }
    else { b.y = hinge + Double(b.side) * 1; b.vy = abs(b.vy) * Double(b.side) }
    impact(b, vertical ? 0 : .pi / 2, cruise(b))
    guard b.contactCooldown <= 0 else { return }
    b.contactCooldown = tuning.bossContactCooldown
    let owner = playerIndex(of: b)
    events.append(.bossSlam(x: b.x, y: b.y, r: b.r, player: owner))
    charge(owner, 1)
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
    hinge = newHinge ?? defaultHinge()
    let ratio = scale / before
    _ = oldHinge
    for b in bubbles {
      let u = b.x / oldW, t = (b.y - oldTop) / oldH
      b.x = (turned ? t : u) * w
      b.y = top + (turned ? u : t) * (h - top)
      if turned { swap(&b.vx, &b.vy) }
      b.vx *= ratio; b.vy *= ratio
      b.r = radius(of: b.kind, size: b.size)
      b.side = sideOf(b)
    }
    let span = alongSpan
    for i in gates.indices {
      gates[i].width = tuning.gateWidth * scale
      gates[i].at = min(span.upperBound, max(span.lowerBound, gates[i].at))
    }
    return turned
  }

  // MARK: Results

  /// Three stars for a clean run, two for losing at most one shield, one for any clear.
  public var stars: Int {
    guard status == .won else { return 0 }
    let p = players[0]
    if p.shieldsLost == 0 && p.crossings <= 2 { return 3 }
    return p.shieldsLost <= 1 ? 2 : 1
  }
}
