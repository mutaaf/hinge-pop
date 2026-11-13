import SwiftUI
import HingePopCore

struct PlayerHUD: Equatable {
  var shields = 3, meter = 0, score = 0, streak = 0
  var combo = 1.0
  var overcharge = 0.0
}

enum Overlay: Equatable {
  case none, paused, result, meet(ActorKind), tour
  /// The first time you enter a world: its name and its twist.
  case world(Int)
  /// The first time villains can turn up: who they are and what a touch costs.
  case villains([VillainKind])
}

struct Tip: Identifiable, Equatable {
  let id = UUID()
  var title: String
  var live: String = ""
  var body: String
  var anchor: UnitPoint = .top
  /// In two-player games, the player it's for, so it turns to face them.
  var seat: Int? = nil
}

/// Two-player seats. The phone lies flat between two players at opposite ends, facing each other across the
/// long axis. Player index 0 owns the near half (top in portrait, left on a wide screen) and index 1 the far
/// half (bottom, or right). Everything that belongs to a player turns to face their edge.
enum Seat {
  /// How far that player's things turn, in SwiftUI degrees (clockwise): 0 reads from the bottom edge, 180 from
  /// the top, 90 from the left, -90 from the right.
  static func degrees(_ player: Int, vertical: Bool) -> Double {
    vertical ? (player == 0 ? 90 : -90) : (player == 0 ? 180 : 0)
  }
  /// The same turn for SpriteKit, whose angles run counter-clockwise.
  static func radians(_ player: Int, vertical: Bool) -> CGFloat { CGFloat(-degrees(player, vertical: vertical) * .pi / 180) }
  /// What the readouts call each player. Player 1 sits at the bottom (or the right), Player 2 across from them.
  static func name(_ player: Int) -> String { player == 1 ? "Player 1" : "Player 2" }
  /// How thick each player's scoreboard band is.
  static func band(wide: Bool) -> CGFloat { wide ? 64 : 56 }
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
  var villainQueue: [VillainKind] = []
  var resultWasBest = false
  /// A checkpoint the last arcade run reached for the first time.
  var arcadeNewCheckpoint: Int?
  /// Mastery for the run in play: its level's challenges, what it's done so far, and the verdict at the end.
  private(set) var challenges: [Challenge] = []
  private(set) var run = RunLog()
  private(set) var grade: Grade?
  private(set) var earned: [Bool] = []
  private(set) var news = GameProgress.RunNews()
  /// What the level asked of an S, for the end card.
  private(set) var par = 0
  var hudHeight: CGFloat = 76
  var levelNumber = 1

  @ObservationIgnored let app: AppModel
  @ObservationIgnored private var size = CGSize.zero
  @ObservationIgnored private var fold: CGRect?
  @ObservationIgnored var runScore = 0
  /// The score this level started from, so a grade only counts the level's own points.
  @ObservationIgnored private var startScore = 0
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
  /// The level in play runs on Overdrive.
  var overdrive: Bool { game?.difficulty == .overdrive }
  var arena: Arena {
    if let chosen = app.progress.arena { return chosen }
    return game?.spec.arena ?? .classic
  }
  /// The swipe trail's colours: a medal's trail when one is picked (cosmetic only), otherwise the arena's.
  var trailArena: Arena { Trails.current(app.progress) ?? arena }
  /// Which take on the biome's art this level uses (`LevelSpec.variant`). A biome picked in settings shows
  /// its original take, since the level's variant belongs to the level's own biome.
  var variant: Int {
    if app.progress.arena != nil { return 0 }
    return game?.spec.variant ?? 0
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
    playRect = arenaRect()
    if game == nil {
      begin()
      return
    }
    let place = placement()
    let turned = game.resize(width: playRect.width, height: playRect.height, top: versus ? 0 : Double(hudHeight), vertical: place?.vertical ?? versusAxis, hinge: place?.hinge)
    game.foldPlay = place != nil
    // Turning keeps the level and pauses it. In two-player games the seats move with the hinge, so both
    // players get a moment to see where their half went.
    var holdOnTurn = true
    #if DEBUG
    holdOnTurn = !Debug.has("-demo")
    #endif
    if turned && holdOnTurn && overlay == .none && tip == nil { overlay = .paused }
    if overlay == .tour { enterTour(tourIndex) }
    generation += 1
  }

  /// Where play happens, in the safe area's coordinates. Solo play fills it (the HUD reserves `top` inside the
  /// game). Two players each get a scoreboard band at their own edge, so the arena sits between the bands and
  /// both halves are the same size.
  private(set) var playRect = CGRect.zero
  /// Two players face each other across the long axis, so the hinge splits it. A real fold wins, whichever way
  /// it runs: each page is a player's half.
  private var versusAxis: Bool? {
    guard versus else { return nil }
    if let fold, fold.width > 0, fold.height > 0, fold.intersects(CGRect(origin: .zero, size: size)) { return fold.height >= fold.width }
    return size.width > size.height
  }
  var seatBand: CGFloat { Seat.band(wide: min(size.width, size.height) >= 600) }
  private func arenaRect() -> CGRect {
    guard let vertical = versusAxis else { return CGRect(origin: .zero, size: size) }
    let b = seatBand
    return vertical ? CGRect(x: b, y: 0, width: max(1, size.width - b * 2), height: size.height)
                    : CGRect(x: 0, y: b, width: size.width, height: max(1, size.height - b * 2))
  }

  private func placement() -> FoldLayout? {
    guard let fold else { return nil }
    let o = playRect.origin
    return FoldLayout.resolve(width: playRect.width, height: playRect.height, top: versus ? 0 : Double(hudHeight),
                              fold: (fold.minX - o.x, fold.minY - o.y, fold.width, fold.height), versus: versus)
  }

  /// True when the game's hinge sits on a real or synthesized fold.
  var onFold: Bool { placement() != nil }
  /// The fold's position along the HUD, when it splits left from right.
  var verticalFoldX: CGFloat? { fold.flatMap { placement()?.vertical == true ? $0.midX : nil } }
  /// Which way a player's things turn to face them (SwiftUI degrees); 0 outside two-player games.
  func seatDegrees(_ player: Int) -> Double { versus ? Seat.degrees(player, vertical: game?.vertical ?? (size.width > size.height)) : 0 }

  func setTourGame(_ g: Game) { game = g; generation += 1; acc = 0; endTimer = 0 }

  func makeGame(_ m: GameMode) -> Game {
    let place = placement()
    let g = Game(mode: m, width: playRect.width, height: playRect.height, top: versus ? 0 : Double(hudHeight), vertical: place?.vertical ?? versusAxis, hinge: place?.hinge, score: m == mode && isCampaign ? runScore : 0, difficulty: app.progress.difficulty)
    g.flick = app.progress.flick
    g.graceOn = app.progress.hingeGrace
    // Page play follows where the fold is. The fold's angle stays effects-only.
    g.foldPlay = place != nil
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
    if case .arcade = mode { game.continueArcade(from: app.arcadeFrom) }
    generation += 1
    acc = 0; endTimer = 0
    startScore = game.players[0].score
    run = RunLog(gustTime: game.tuning.windTime)
    grade = nil; earned = []; news = GameProgress.RunNews()
    // Challenges are the level's own list in both modes (one progression); par follows the level as played,
    // so an Overdrive run's bigger crowd and tougher boss raise the bar with it.
    challenges = isCampaign ? Challenges.for(level: levelNumber) : []
    par = isCampaign ? Par.score(game.spec, tuning: game.tuning) : 0
    overlay = .none; tip = nil; toast = nil; tourRun = false; tourInput = false
    syncHUD()
    introduce()
    calendarSecrets()
    #if DEBUG
    Debug.ready("play")
    #endif
  }

  private func introduce() {
    meetQueue = []
    villainQueue = game.villainPlan.pool.filter { !app.progress.taught.contains("villain-\($0.rawValue)") }
    if versus { villainQueue = [] }
    for spawn in game.spec.spawns where spawn.kind != .basic {
      let key = "meet-\(spawn.kind.rawValue)"
      if !app.progress.taught.contains(key), !meetQueue.contains(spawn.kind) { meetQueue.append(spawn.kind) }
    }
    if game.spec.gates > 0, !app.progress.taught.contains("gate") {
      app.progress.taught.insert("gate")
      show("Green gaps are gates. Bubbles pass through them for free, with no split and no charge.", seconds: 5)
    }
    if game.spec.current > 0, !app.progress.taught.contains("current") {
      app.progress.taught.insert("current")
      show("A current flows along the line. It carries every bubble with it, then turns around.", seconds: 5)
    }
    // A new world opens with its card, before any new bubble.
    if isCampaign, let w = Worlds.world(ofLevel: levelNumber), w.number > 1, !app.progress.taught.contains("world-\(w.number)") {
      overlay = .world(w.number)
    } else if let first = meetQueue.first {
      overlay = .meet(first)
    } else if !villainQueue.isEmpty {
      overlay = .villains(villainQueue)
    } else if versus {
      show("Face to face. Your half is the one nearest you.")
    } else if isCampaign {
      show("Level \(levelNumber): \(Campaign.chapter(of: levelNumber).title)", seconds: 1.6)
    }
  }

  /// Some days and hours hide something. Each turns up once.
  private func calendarSecrets() {
    let now = Calendar.current.dateComponents([.month, .day, .hour], from: Date())
    for s in Secrets.calendar(month: now.month ?? 0, day: now.day ?? 0, hour: now.hour ?? 0) where !app.progress.found(s.id) {
      reveal(s); return
    }
  }

  func dismissWorld() {
    guard case .world(let n) = overlay else { return }
    app.progress.taught.insert("world-\(n)")
    overlay = meetQueue.first.map { .meet($0) } ?? (villainQueue.isEmpty ? .none : .villains(villainQueue))
    if overlay == .none { show("Level \(levelNumber): \(Campaign.chapter(of: levelNumber).title)", seconds: 1.6) }
  }

  func dismissMeet() {
    guard case .meet(let kind) = overlay else { return }
    app.progress.taught.insert("meet-\(kind.rawValue)")
    meetQueue.removeAll { $0 == kind }
    overlay = meetQueue.first.map { .meet($0) } ?? (villainQueue.isEmpty ? .none : .villains(villainQueue))
  }

  func dismissVillains() {
    guard case .villains(let kinds) = overlay else { return }
    for k in kinds { app.progress.taught.insert("villain-\(k.rawValue)") }
    villainQueue = []
    overlay = .none
  }

  /// Again, from the score the level began with, even after a win (so retrying for an S never inflates it).
  func restart() { runScore = isCampaign ? startScore : 0; startGame() }

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
    if overlay != .tour, !game.events.isEmpty { run.note(game.events, at: game.time) }
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

  /// An Easter egg turned up. The first find is a bigger moment than a repeat.
  func reveal(_ secret: Secret) {
    let new = app.progress.find(secret.id)
    show(new ? "\(secret.emoji) Secret found: \(secret.title). \(secret.line)" : "\(secret.emoji) \(secret.line)", seconds: 4)
    if new { Haptics.shared.good() }
  }

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
      case .hingeSnap(_, _, let flung):
        if flung > 0 { teach("snapped", "Snapped! It recharges in \(Int(game.tuning.snapCooldown)) seconds. The line dims until it's ready.") }
      case .rushStart: teach("rush", "This page is rushing: faster bubbles, double points.")
      case .crossfold: teach("crossfold", "Crossfold! Pop across the fold to build combo faster.")
      case .untouchable:
        if game.spec.has(.blackout) { teach("dark", "Too dark to hit. Your touch lights it up: tap again.") }
        else if game.spec.has(.fog) { teach("fogged", "Lost in the fog. Hit it as it comes close.") }
        else if game.spec.has(.ghost) { teach("phased", "Out of phase. Wait till it's solid.") }
      case .beatPop: teach("beat", "On the beat: double points!")
      case .bossShielded: teach("shielded", "Shield! Hit it from the open side.")
      case .bossBlink: teach("blink", "It blinked! Hit it before it dashes.")
      case .regrow: teach("regrow", "It grew back. Don't leave pieces too long.")
      case .creaseClap: teach("clap", "Crease clap! It sweeps the whole line.")
      case .snapReady where game.foldPlay && game.players[0].claps == 0:
        teach("clap-hint", "Touch both pages beside the fold at once to clap it.")
      case .cameoArrived(let c, _, _):
        show("\(c.title)! Catch for \(c.gift)", seconds: 3)
      case .cameoCaught(let c, _, _, _, _):
        app.progress.caught(c)
        show("“\(c.quip)”", seconds: 3)
        if Cameo.allCases.allSatisfy(app.progress.hasCaught), !app.progress.found("full-cast") { reveal(Secrets.named("full-cast")!) }
      case .secretBubble(let n, _, _):
        let new = app.progress.find("nod-\(n)")
        show("✨ \(Secrets.nod(level: n))", seconds: 3.6)
        if new { Haptics.shared.good() }
      case .finished:
        endTimer = 0.7
      default: break
      }
      if game.players.contains(where: { $0.combo >= game.tuning.comboMax }), !app.progress.found("max-combo") { reveal(Secrets.named("max-combo")!) }
      if game.players.contains(where: { $0.score >= 1_000_000 }), !app.progress.found("million") { reveal(Secrets.named("million")!) }
      if case .creaseClap = e, game.players[0].claps >= 3, !app.progress.found("ovation") { reveal(Secrets.named("ovation")!) }
      if game.players.contains(where: { $0.combo >= 3 }) { teach("combo", "Combo building. Tap again within \(String(format: "%.1f", game.tuning.comboWindow)) seconds to keep it. A crossing resets it.") }
    }
  }

  private func finish() {
    run.close(game, startScore: startScore)
    switch mode {
    case .campaign(let n):
      if game.status == .won {
        let score = game.players[0].score
        let g = Par.grade(score: run.score, par: par)
        grade = g
        earned = Challenges.evaluate(challenges, run)
        news = app.progress.record(level: n, stars: game.stars, score: score, grade: g, earned: earned, difficulty: game.difficulty)
        resultWasBest = news.bestScore
        runScore = score
        if n == 42 { reveal(Secrets.named("answer")!) }
        Haptics.shared.good()
      } else {
        Haptics.shared.bad()
      }
    case .arcade:
      let score = game.players[0].score
      let before = app.progress.arcade.checkpoint
      resultWasBest = app.progress.recordArcade(score: score, wave: game.waves)
      arcadeNewCheckpoint = app.progress.arcade.checkpoint > before ? app.progress.arcade.checkpoint : nil
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
      body: "Full meter costs one. Lose the last and \(end) \(left) more \(left == 1 ? "tap" : "taps") with no crossing \(p.shields < game.tuning.shields ? "wins one back." : "clears the meter.")", seat: versus ? i : nil)
  }
  func tipMeter(_ i: Int) -> Tip {
    let p = game.players[i], left = game.meterMax - p.meter
    return Tip(title: "Overload meter", live: "\(p.meter) of \(game.meterMax) charged. \(left) to go.",
      body: "Big fills it. Medium adds \(game.crossingCost(size: 1)). Small adds 1. Tiny adds nothing, and neither do green gates. Full costs a shield.", seat: versus ? i : nil)
  }
  func tipScore(_ i: Int) -> Tip {
    let p = game.players[i]
    return Tip(title: "Score and combo", live: "\(p.score.formatted()) points at x\(p.combo.formatted()).",
      body: "Smaller pays more, times your combo. Keep tapping to build it. A crossing resets it.\(isCampaign ? " No crossings: +25%." : "")", seat: versus ? i : nil)
  }
  func tipBoss() -> Tip {
    Tip(title: "Boss", live: "\(max(1, game.spec.bossPhases)) phases, \(game.bossHitsPerPhase) hits each.", body: ActorKind.boss.detail)
  }
  func tipPower(_ p: PowerUp) -> Tip { Tip(title: p.title, body: p.detail) }

  // MARK: Debug helpers for screenshots

  #if DEBUG
  @ObservationIgnored private var demoClock = 0.0
  /// Live game state for UI tests, which touch the screen the way a person does.
  var probe = ""
  @ObservationIgnored var debugLeft = 0.0
  @ObservationIgnored var debugTop = 0.0
  private func demoTick(_ dt: Double) {
    let endCard = Debug.string("-endCard")
    if Debug.has("-win") || endCard == "win", game.status == .playing, game.time > 0.6 {
      // Two players: Player 1 (the bottom seat) edges it, so captures show a win and a loss.
      if versus { game.players[1].score += 50 }
      var guardCount = 0
      while let b = game.bubbles.first, game.status == .playing, guardCount < 800 { game.tap(b); guardCount += 1 }
    }
    // `-villain <kind>` (or `all`) keeps villains on stage for captures and tests; with `-endCard lose` it touches one.
    if let name = Debug.string("-villain"), game.status == .playing, game.time > 0.4 {
      let kinds = name == "all" ? VillainKind.allCases : VillainKind(rawValue: name).map { [$0] } ?? []
      for (i, k) in kinds.enumerated() where !game.villains.contains(where: { $0.kind == k }) {
        let u = kinds.count == 1 ? 0.5 : 0.12 + 0.76 * Double(i) / Double(kinds.count - 1)
        game.summonVillain(k, u: u, v: kinds.count == 1 ? 0.3 : (i % 2 == 0 ? 0.25 : 0.75), degrees: 70)
      }
      if Debug.has("-still") { game.villainsHeld = true }
      if endCard == "lose", game.time > 0.8, let v = game.villains.first(where: { $0.solid }) { game.strike(v) }
    }
    if Debug.string("-villain") == nil, Debug.has("-lose") || endCard == "lose", game.status == .playing, game.time > 0.6 {
      game.players[0].shields = 1; game.players[0].meter = game.meterMax - 1
      let pick = endCard == "lose" ? game.bubbles.first(where: { $0.size == 0 && $0.kind != .boss }) : nil
      if let b = pick ?? game.bubbles.first(where: { $0.size < 3 }) { if game.vertical { b.x = game.hinge - Double(b.side); b.vx = -Double(b.side) * 400 } else { b.y = game.hinge - Double(b.side); b.vy = -Double(b.side) * 400 }; b.grace = 0 }
    }
    if Debug.has("-still") {
      for b in game.bubbles { b.vx = 0; b.vy = 0 }
      game.visitorsHeld = true
      if let name = Debug.string("-cameo"), let c = Cameo(rawValue: name), game.visitors.isEmpty, game.players[0].cameos == 0, game.time > 0.3 { game.summon(c) }
    }
    if Debug.has("-probe") {
      let b = game.bubbles.first, v = game.visitors.first, p = game.players[0]
      let line = "bx=\(b?.x ?? -1);by=\(b?.y ?? -1);vx=\(v?.x ?? -1);vy=\(v?.y ?? -1);taps=\(p.taps);flicks=\(p.flicks);cameos=\(p.cameos);snaps=\(p.snaps);left=\(debugLeft);top=\(debugTop);hinge=\(game.hinge);vertical=\(game.vertical);w=\(game.w);h=\(game.h);secrets=\(app.progress.namedFound)"
      if line != probe { probe = line }
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
