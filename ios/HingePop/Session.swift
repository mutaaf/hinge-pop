import SwiftUI
import HingePopCore

struct PlayerHUD: Equatable {
  var shields = 3, meter = 0, score = 0, streak = 0
  var combo = 1.0
  var overcharge = 0.0
}

enum Overlay: Equatable {
  case none, paused, result, meet(ActorKind), tour
}

struct Tip: Identifiable, Equatable {
  let id = UUID()
  var title: String
  var live: String = ""
  var body: String
  var anchor: UnitPoint = .top
}

struct Toast: Identifiable, Equatable {
  let id = UUID()
  var text: String
  var power: PowerUp? = nil
}

/// One run of the game: it owns the rules object, the HUD snapshot and whatever is showing on top.
@MainActor @Observable
final class Session {
  private(set) var mode: GameMode
  @ObservationIgnored private(set) var game: Game!
  private(set) var generation = 0
  var hud: [PlayerHUD] = [PlayerHUD()]
  var bossLeft: Double?
  var freezeLeft = 0.0
  var focusLeft = 0.0
  var overlay = Overlay.none
  var tip: Tip?
  var toast: Toast?
  var tourIndex = 0
  var tourDone = false
  var tourNote = ""
  var meetQueue: [ActorKind] = []
  var resultWasBest = false
  var hudHeight: CGFloat = 76
  var levelNumber = 1

  @ObservationIgnored let app: AppModel
  @ObservationIgnored private var size = CGSize.zero
  @ObservationIgnored private var fold: CGRect?
  @ObservationIgnored var runScore = 0
  @ObservationIgnored private var acc = 0.0
  @ObservationIgnored private var endTimer = 0.0
  @ObservationIgnored private var toastTask: Task<Void, Never>?
  @ObservationIgnored var tourKind = TourKind.solo
  @ObservationIgnored var tourRun = false
  @ObservationIgnored var tourInput = false
  @ObservationIgnored var tourEntered = 0.0
  @ObservationIgnored var tourFreezeAt = 0.0
  @ObservationIgnored var tourClock = 0.0
  @ObservationIgnored var tourBubble: Bubble?
  @ObservationIgnored var startAfterLayout = true
  /// The rules give events to the scene for effects, and to the session for teaching.
  @ObservationIgnored var pendingEvents: [GameEvent] = []

  init(mode: GameMode, app: AppModel) {
    self.mode = mode
    self.app = app
    if case .campaign(let n) = mode { levelNumber = n }
  }

  var versus: Bool { mode == .versus }
  var isCampaign: Bool { if case .campaign = mode { true } else { false } }
  var arena: Arena {
    if let chosen = app.progress.arena { return chosen }
    return game?.spec.arena ?? .classic
  }
  var isHeld: Bool { overlay != .none || tip != nil }
  /// How far between the last two physics steps this frame lands.
  var stepAlpha: Double { min(1, acc * 120) }
  /// How close anyone is to losing a shield, for the aurora to warm up.
  var heat: Double {
    guard let game else { return 0 }
    let m = hud.map(\.meter).max() ?? 0
    return min(1, Double(m) / Double(max(1, game.meterMax - 1)))
  }

  /// Called on every layout. Builds the first game once the size is known, and adapts it after that.
  func layout(size: CGSize, fold: CGRect?) {
    let changed = size != self.size || fold != self.fold
    guard changed, size.width > 0, size.height > 0 else { return }
    self.size = size
    self.fold = fold
    if game == nil {
      begin()
      return
    }
    let place = placement(size: size, fold: fold, top: Double(hudHeight))
    let turned = game.resize(width: size.width, height: size.height, top: Double(hudHeight), vertical: place?.vertical, hinge: place?.hinge)
    if turned && overlay == .none && tip == nil && !versus { overlay = .paused }
    if overlay == .tour { enterTour(tourIndex) }
    generation += 1
  }

  private func placement(size: CGSize, fold: CGRect?, top: Double) -> FoldLayout? {
    guard let fold else { return nil }
    return FoldLayout.resolve(width: size.width, height: size.height, top: top, fold: (fold.minX, fold.minY, fold.width, fold.height), versus: versus)
  }

  /// True when the game's hinge sits on a real or synthesized fold.
  var onFold: Bool { placement(size: size, fold: fold, top: Double(hudHeight)) != nil }
  /// The fold's position along the HUD, when it splits left from right.
  var verticalFoldX: CGFloat? { fold.flatMap { placement(size: size, fold: $0, top: Double(hudHeight))?.vertical == true ? $0.midX : nil } }

  func setTourGame(_ g: Game) { game = g; generation += 1; acc = 0; endTimer = 0 }

  func makeGame(_ m: GameMode) -> Game {
    let place = placement(size: size, fold: fold, top: Double(hudHeight))
    let g = Game(mode: m, width: size.width, height: size.height, top: Double(hudHeight), vertical: place?.vertical, hinge: place?.hinge, score: m == mode && isCampaign ? runScore : 0)
    g.flick = app.progress.flick
    g.graceOn = app.progress.hingeGrace
    return g
  }

  /// Starts the mode, sending first-timers through the tour.
  func begin() {
    if case .campaign = mode, !app.progress.seenTour { startTour(.solo); return }
    if case .arcade = mode, !app.progress.seenTour { startTour(.solo); return }
    if case .daily = mode, !app.progress.seenTour { startTour(.solo); return }
    if versus, !app.progress.seenVersusTour { startTour(.versus); return }
    startGame()
  }

  func startGame() {
    if case .campaign(let n) = mode { levelNumber = n }
    game = makeGame(mode)
    generation += 1
    acc = 0; endTimer = 0
    overlay = .none; tip = nil; toast = nil; tourRun = false; tourInput = false
    syncHUD()
    introduce()
    #if DEBUG
    Debug.ready("play")
    #endif
  }

  private func introduce() {
    meetQueue = []
    for spawn in game.spec.spawns where spawn.kind != .basic {
      let key = "meet-\(spawn.kind.rawValue)"
      if !app.progress.taught.contains(key), !meetQueue.contains(spawn.kind) { meetQueue.append(spawn.kind) }
    }
    if game.spec.gates > 0, !app.progress.taught.contains("gate") {
      app.progress.taught.insert("gate")
      show("Green gaps are gates. Bubbles pass through them for free, with no split and no charge.", seconds: 5)
    }
    if let first = meetQueue.first {
      overlay = .meet(first)
    } else if versus {
      show(size.width < 600 && size.height > size.width ? "One side each. Turn sideways for more room." : "One side each. Tap your own bubbles.")
    } else if isCampaign {
      show("Level \(levelNumber): \(Campaign.chapter(of: levelNumber).title)", seconds: 1.6)
    }
  }

  func dismissMeet() {
    guard case .meet(let kind) = overlay else { return }
    app.progress.taught.insert("meet-\(kind.rawValue)")
    meetQueue.removeAll { $0 == kind }
    overlay = meetQueue.first.map { .meet($0) } ?? .none
  }

  func restart() { if isCampaign { /* the level's starting score stays */ } else { runScore = 0 }; startGame() }

  func nextLevel() {
    guard case .campaign(let n) = mode else { return }
    mode = .campaign(n + 1)
    startGame()
  }

  func pause() { if overlay == .none, game?.status == .playing { tip = nil; overlay = .paused } }
  func resume() {
    game.flick = app.progress.flick
    game.graceOn = app.progress.hingeGrace
    overlay = .none
  }

  // MARK: Frame

  /// Advances time. Tooltips, menus and cards all hold the game still.
  func tick(_ dt: Double) {
    guard let game else { return }
    let clamped = min(0.05, dt)
    if overlay == .tour {
      tourClock += clamped
      if tourRun { advance(clamped) }
      tickTour()
    } else if !isHeld {
      advance(clamped)
      if endTimer > 0 {
        endTimer -= clamped
        if endTimer <= 0 { finish() }
      }
      #if DEBUG
      demoTick(clamped)
      #endif
    }
    pendingEvents.append(contentsOf: game.events)
    handleTeaching(game.events)
    game.events.removeAll(keepingCapacity: true)
    syncHUD()
  }

  private func advance(_ dt: Double) {
    acc += dt
    let step = 1.0 / 120
    while acc >= step { game.step(step); acc -= step }
  }

  private func syncHUD() {
    guard let game else { return }
    let next = game.players.map { PlayerHUD(shields: $0.shields, meter: $0.meter, score: $0.score, streak: $0.streak, combo: $0.combo, overcharge: ($0.overcharge * 2).rounded(.up) / 2) }
    if next != hud { hud = next }
    let boss = game.bubbles.first { $0.kind == .boss }
    let phases = max(1, game.spec.bossPhases), hits = game.bossHitsPerPhase
    let left = boss.map { Double(phases * hits - $0.bossPhase * hits - $0.bossHits) / Double(phases * hits) }
    if left != bossLeft { bossLeft = left }
    let f = (game.freeze * 2).rounded(.up) / 2; if f != freezeLeft { freezeLeft = f }
    let o = (game.focus * 2).rounded(.up) / 2; if o != focusLeft { focusLeft = o }
  }

  // MARK: Teaching

  func show(_ text: String, power: PowerUp? = nil, seconds: Double = 3.4) {
    toast = Toast(text: text, power: power)
    toastTask?.cancel()
    toastTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled else { return }
      self?.toast = nil
    }
  }

  /// Each lesson shows once, the first time it matters.
  @discardableResult
  func teach(_ key: String, _ text: String, power: PowerUp? = nil) -> Bool {
    guard overlay != .tour, !app.progress.taught.contains(key) else { return false }
    app.progress.taught.insert(key)
    show(text, power: power, seconds: 4.2)
    return true
  }

  private func handleTeaching(_ events: [GameEvent]) {
    for e in events {
      switch e {
      case .crossed:
        if !teach("cross", "Crossings charge the meter. Bigger bubbles charge more."),
           game.players.contains(where: { $0.meter == game.meterMax - 1 }) {
          teach("nearfull", "One more crossing costs a shield.")
        }
      case .shieldLost: teach("shield", "A shield is gone. Tap \(game.tuning.rechargeStreak) times in a row with no crossing to win it back.")
      case .recharge: teach("recharge", "Shield restored. At full shields, a streak clears the meter instead.")
      case .split(_, _, _, 2, _, _): teach("small", "The smallest bubbles pop on the hinge for free. Tap them for more points, or let the hinge take them.")
      case .chainPop: teach("chain", "Chain pop! Tiny bubbles set each other off, so wait for a crowd and pop one.")
      case .gatePass: teach("gatepass", "Through the gate, free of charge.")
      case .dropped(let kind, _, _): teach("drop", "A power-up! Tap it before it fades: \(kind.title).", power: kind)
      case .collected(let kind, _, _, _): teach("got-\(kind.rawValue)", "\(kind.title): \(kind.detail)", power: kind)
      case .bossSlam: teach("slam", "Each slam charges your meter. Keep hitting it.")
      case .bossWindup: teach("windup", "It's winding up! Hit it now for double damage.")
      case .bossStagger: teach("stagger", "Staggered! Double damage.")
      case .bossPhase: teach("phase", "Next phase: faster, with friends.")
      case .cameoArrived(let c, _, _):
        show("\(c.title)! Catch for \(c.gift)", seconds: 3)
      case .cameoCaught(let c, _, _, _, _):
        app.progress.caught(c)
        show("“\(c.quip)”", seconds: 3)
      case .finished:
        endTimer = 0.7
      default: break
      }
      if game.players.contains(where: { $0.combo >= 3 }) { teach("combo", "Combo building. Tap again within \(String(format: "%.1f", game.tuning.comboWindow)) seconds to keep it. A crossing resets it.") }
    }
  }

  private func finish() {
    switch mode {
    case .campaign(let n):
      if game.status == .won {
        let score = game.players[0].score
        resultWasBest = score > (app.progress.bestScores[n] ?? 0)
        app.progress.record(level: n, stars: game.stars, score: score)
        runScore = score
        Haptics.shared.good()
      } else {
        Haptics.shared.bad()
      }
    case .arcade:
      let score = game.players[0].score
      resultWasBest = score > app.progress.arcadeBest
      app.progress.arcadeBest = max(app.progress.arcadeBest, score)
      Haptics.shared.bad()
    case .daily:
      let score = game.status == .won ? game.players[0].score : 0
      let key = app.dailyKey
      resultWasBest = score > (app.progress.dailyBest[key] ?? 0)
      app.progress.dailyBest[key] = max(app.progress.dailyBest[key] ?? 0, score)
    default: Haptics.shared.good()
    }
    overlay = .result
    #if DEBUG
    Debug.ready("result")
    #endif
  }

  // MARK: Tips

  func openTip(_ tip: Tip) { self.tip = tip }

  func tipShields(_ i: Int) -> Tip {
    let p = game.players[i], r = game.tuning.rechargeStreak, left = r - p.streak
    let end = versus ? "you lose the match." : isCampaign ? "the level starts again from the score you began it with." : "the run ends."
    return Tip(title: "Shields", live: "\(p.shields) of \(game.tuning.shields) left. Streak: \(p.streak) of \(r) taps.",
      body: "Full meter costs one. Lose the last and \(end) \(left) more \(left == 1 ? "tap" : "taps") with no crossing \(p.shields < game.tuning.shields ? "wins one back." : "clears the meter.")")
  }
  func tipMeter(_ i: Int) -> Tip {
    let p = game.players[i], left = game.meterMax - p.meter
    return Tip(title: "Overload meter", live: "\(p.meter) of \(game.meterMax) charged. \(left) to go.",
      body: "Big fills it. Medium adds \(game.crossingCost(size: 1)). Small adds 1. Tiny adds nothing, and neither do green gates. Full costs a shield.")
  }
  func tipScore(_ i: Int) -> Tip {
    let p = game.players[i]
    return Tip(title: "Score and combo", live: "\(p.score.formatted()) points at x\(p.combo.formatted()).",
      body: "Smaller pays more, times your combo. Keep tapping to build it. A crossing resets it.\(isCampaign ? " No crossings: +25%." : "")")
  }
  func tipBoss() -> Tip {
    Tip(title: "Boss", live: "\(max(1, game.spec.bossPhases)) phases, \(game.bossHitsPerPhase) hits each.", body: ActorKind.boss.detail)
  }
  func tipPower(_ p: PowerUp) -> Tip { Tip(title: p.title, body: p.detail) }

  // MARK: Debug helpers for screenshots

  #if DEBUG
  @ObservationIgnored private var demoClock = 0.0
  private func demoTick(_ dt: Double) {
    if Debug.has("-win"), game.status == .playing, game.time > 0.6 {
      var guardCount = 0
      while let b = game.bubbles.first, game.status == .playing, guardCount < 800 { game.tap(b); guardCount += 1 }
    }
    if Debug.has("-lose"), game.status == .playing, game.time > 0.6 {
      game.players[0].shields = 1; game.players[0].meter = game.meterMax - 1
      if let b = game.bubbles.first(where: { $0.size < 3 }) { if game.vertical { b.x = game.hinge - Double(b.side); b.vx = -Double(b.side) * 400 } else { b.y = game.hinge - Double(b.side); b.vy = -Double(b.side) * 400 }; b.grace = 0 }
    }
    guard Debug.has("-demo"), game.status == .playing else { return }
    // Store captures hold the action on screen: nobody loses while the camera is rolling.
    let meter = Debug.int("-demoMeter") ?? 0
    for i in game.players.indices { game.players[i].meter = meter; game.players[i].shields = 3 }
    demoClock -= dt
    if let name = Debug.string("-cameo"), let c = Cameo(rawValue: name), game.visitors.isEmpty, game.time > 0.5 { game.summon(c) }
    guard demoClock <= 0, game.bubbles.count < 14, let b = game.bubbles.first(where: { $0.size < 2 && $0.kind != .boss }) else { return }
    demoClock = 0.5
    game.tap(b)
  }
  #endif
}
