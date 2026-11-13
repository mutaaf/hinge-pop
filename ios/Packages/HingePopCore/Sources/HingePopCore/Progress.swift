import Foundation

/// Everything the game remembers, kept on the device.
public struct GameProgress: Codable, Equatable, Sendable {
  public var unlocked = 1
  public var stars: [Int: Int] = [:]
  public var bestScores: [Int: Int] = [:]
  public var arcadeBest = 0
  public var dailyBest: [String: Int] = [:]
  public var seenTour = false
  public var seenVersusTour = false
  public var taught: Set<String> = []
  public var flick = true
  public var hingeGrace = true
  /// Silent until someone turns it on. Saves from when this defaulted to on stored that automatically, so the
  /// old key is ignored, and only a choice made in Settings counts.
  private var soundChoice: Bool? = nil
  public var sound: Bool {
    get { soundChoice ?? false }
    set { soundChoice = newValue }
  }
  public var haptics = true
  public var arena: Arena? = nil
  /// Optional so saves from before cameos existed still load.
  private var cameoLog: [String]? = nil
  /// The last version whose update notes were shown. Optional so older saves still load.
  public var seenNotes: String? = nil
  /// Normal or Overdrive. Optional so saves from before Overdrive load as Normal.
  private var difficultyChoice: Difficulty? = nil
  public var difficulty: Difficulty {
    get { difficultyChoice ?? .normal }
    set { difficultyChoice = newValue }
  }
  /// Levels cleared on Overdrive (the flame on the journey). Optional so older saves load.
  private var overdriveLog: Set<Int>? = nil
  public func clearedOnOverdrive(_ level: Int) -> Bool { overdriveLog?.contains(level) ?? false }
  public var overdriveClears: Int { overdriveLog?.count ?? 0 }
  /// True once someone has played, so an update can tell them what changed.
  public var playedBefore: Bool { seenTour || unlocked > 1 || arcadeBest > 0 || !stars.isEmpty }
  /// Arcade's long view: the furthest wave, runs played and the last run. Optional so older saves load.
  private var arcadeLog: ArcadeLog? = nil
  public var arcade: ArcadeLog {
    get { arcadeLog ?? ArcadeLog() }
    set { arcadeLog = newValue }
  }
  /// Files an arcade run. True when it set a new best score.
  @discardableResult public mutating func recordArcade(score: Int, wave: Int) -> Bool {
    var log = arcade
    log.runs += 1
    log.lastScore = score
    log.lastWave = wave
    log.bestWave = max(log.bestWave, wave)
    arcade = log
    let best = score > arcadeBest
    arcadeBest = max(arcadeBest, score)
    return best
  }
  public init() {}

  public func hasCaught(_ cameo: Cameo) -> Bool { cameoLog?.contains(cameo.rawValue) ?? false }
  /// Secrets found: named ids, and "nod-<level>" for a level's hidden bubble. Optional so older saves load.
  private var secretLog: [String]? = nil
  public func found(_ id: String) -> Bool { secretLog?.contains(id) ?? false }
  /// Records a secret. True the first time.
  @discardableResult public mutating func find(_ id: String) -> Bool {
    guard !found(id) else { return false }
    secretLog = (secretLog ?? []) + [id]
    return true
  }
  public var nodsFound: Int { secretLog?.filter { $0.hasPrefix("nod-") }.count ?? 0 }
  public var namedFound: Int { Secrets.named.filter { found($0.id) }.count }
  public mutating func caught(_ cameo: Cameo) {
    if !hasCaught(cameo) { cameoLog = (cameoLog ?? []) + [cameo.rawValue] }
  }

  public mutating func record(level: Int, stars newStars: Int, score: Int) {
    stars[level] = max(stars[level] ?? 0, newStars)
    bestScores[level] = max(bestScores[level] ?? 0, score)
    unlocked = max(unlocked, level + 1)
  }

  public var totalStars: Int { stars.values.reduce(0, +) }

  // MARK: Mastery: challenges, grades and medals

  /// Challenges earned, per level: bit i is `Challenges.for(level:)[i]`. Optional so older saves load.
  private var challengeLog: [Int: Int]? = nil
  /// The best grade per level (`Grade.rawValue`). Optional so older saves load.
  private var gradeLog: [Int: Int]? = nil
  /// The trail tint picked from the ones medals have won (`Trails`). Nil is the standard trail. Cosmetic only.
  public var trail: String? = nil

  public func challengesDone(_ level: Int) -> [Bool] {
    let mask = challengeLog?[level] ?? 0
    return (0..<Challenges.perLevel).map { mask & (1 << $0) != 0 }
  }
  public func challengeCount(_ level: Int) -> Int { challengesDone(level).filter { $0 }.count }
  public func grade(_ level: Int) -> Grade? { gradeLog?[level].flatMap(Grade.init(rawValue:)) }

  public func worldChallenges(_ world: Int) -> Int {
    guard let w = Worlds.world(world) else { return 0 }
    return w.levels.reduce(0) { $0 + challengeCount($1) }
  }
  public func realmChallenges(_ realm: Int) -> Int {
    guard let r = Worlds.realm(realm) else { return 0 }
    return r.worlds.reduce(0) { $0 + worldChallenges($1) }
  }
  /// Challenges earned across the campaign, out of `Challenges.total`.
  public var mastery: Int { challengeLog?.reduce(0) { $0 + ($1.key <= Campaign.finalAuthored ? challengeCount($1.key) : 0) } ?? 0 }
  public var sGrades: Int { gradeLog?.values.filter { $0 == Grade.s.rawValue }.count ?? 0 }

  /// A world's medal: every one of its 30 challenges done.
  public func hasMedal(_ world: Int) -> Bool { worldChallenges(world) == Challenges.perWorld }
  public var medals: [Int] { Worlds.all.map(\.number).filter(hasMedal) }

  /// What a finished run changed, for the end card's callouts.
  public struct RunNews: Equatable, Sendable {
    public var bestScore = false
    public var bestGrade = false
    /// Which of the level's challenges this run earned for the first time.
    public var newChallenges: [Bool] = Array(repeating: false, count: Challenges.perLevel)
    /// A world whose medal this run won.
    public var medal: Int? = nil
    /// The first Overdrive clear of this level.
    public var firstOverdrive = false
    public init() {}
    public var anyNewChallenge: Bool { newChallenges.contains(true) }
  }

  /// Records a clear: stars, best score, best grade and any challenges earned. Challenges stay earned.
  /// Both difficulties share one progression (stars, gates, best score and grade); an Overdrive clear also
  /// marks the level's flame.
  @discardableResult
  public mutating func record(level: Int, stars newStars: Int, score: Int, grade: Grade?, earned: [Bool], difficulty: Difficulty = .normal) -> RunNews {
    var news = RunNews()
    if difficulty == .overdrive, !clearedOnOverdrive(level) {
      overdriveLog = (overdriveLog ?? []).union([level])
      news.firstOverdrive = true
    }
    news.bestScore = score > (bestScores[level] ?? 0)
    let world = Worlds.world(ofLevel: level)?.number
    let hadMedal = world.map(hasMedal) ?? false
    record(level: level, stars: newStars, score: score)
    if let grade {
      let old = self.grade(level)
      if old == nil || grade > old! {
        var log = gradeLog ?? [:]
        log[level] = grade.rawValue
        gradeLog = log
        news.bestGrade = old != nil
      }
    }
    let before = challengesDone(level)
    var mask = challengeLog?[level] ?? 0
    for (i, got) in earned.prefix(Challenges.perLevel).enumerated() where got {
      if !before[i] { news.newChallenges[i] = true }
      mask |= 1 << i
    }
    if mask != 0 {
      var log = challengeLog ?? [:]
      log[level] = mask
      challengeLog = log
    }
    if let world, !hadMedal, hasMedal(world) { news.medal = world }
    return news
  }

  // MARK: Journey gates

  /// Every level up to here stays open whatever the gates say: the furthest level reached before realm gates
  /// existed. Nil in saves from before then, which `adoptGates()` fills in (and which already counts as `unlocked`).
  private var gateFloor: Int? = 1
  /// Worlds and realms whose complete moment has been shown ("world-12", "realm-2"). Optional so older saves load.
  private var cheered: [String]? = nil

  /// Run once after loading a save. A save from before the gates keeps every level it had reached, and worlds it
  /// had already finished don't throw a party on the first launch after the update.
  public mutating func adoptGates() {
    guard gateFloor == nil else { return }
    gateFloor = unlocked
    settleCheers()
  }

  /// Marks every finished world and realm as already celebrated. `keepingLatest` leaves the furthest one to show.
  public mutating func settleCheers(keepingLatest: Bool = false) {
    let last = keepingLatest ? Worlds.all.last(where: { worldComplete($0.number) }) : nil
    for w in Worlds.all where worldComplete(w.number) && w.number != last?.number { markCheered(.world(w.number)) }
    for r in Worlds.realms where realmComplete(r.number) && r.number != last?.realm { markCheered(.realm(r.number)) }
  }

  /// Stars earned in one realm's 80 levels.
  public func realmStars(_ realm: Int) -> Int {
    guard let r = Worlds.realm(realm) else { return 0 }
    let first = (r.worlds.lowerBound - 1) * 10 + 1, last = r.worlds.upperBound * 10
    return stars.reduce(0) { (first...last).contains($1.key) ? $0 + $1.value : $0 }
  }
  public func worldStars(_ world: Int) -> Int {
    guard let w = Worlds.world(world) else { return 0 }
    return w.levels.reduce(0) { $0 + (stars[$1] ?? 0) }
  }

  /// True when the realm's star gate is met. The first realm has none.
  public func realmOpen(_ realm: Int) -> Bool { starsShort(realm) == 0 }
  /// How many more stars from the realm before it would open this one. 0 when it's open.
  public func starsShort(_ realm: Int) -> Int {
    max(0, Gates.stars(toOpen: realm) - realmStars(realm - 1))
  }

  /// A level is open once you've reached it and its realm's gate is met, or if it was open before the gates came.
  public func isOpen(_ level: Int) -> Bool {
    guard level >= 1, level <= unlocked else { return false }
    if level <= (gateFloor ?? unlocked) { return true }
    guard let world = Worlds.world(ofLevel: level), level <= Campaign.finalAuthored else { return true }
    return realmOpen(world.realm)
  }
  /// Reached in order, but waiting on its realm's star gate.
  public func isGated(_ level: Int) -> Bool { level <= unlocked && !isOpen(level) }

  /// Infinity's generated levels open after the last authored one.
  public var infinityOpen: Bool { unlocked > Campaign.finalAuthored }

  /// The level a Play button should start: the furthest one reached, or, when that waits on a gate, the first
  /// level of the realm before it that still has stars to win.
  public var nextUp: Int {
    if isOpen(unlocked) { return unlocked }
    guard let world = Worlds.world(ofLevel: unlocked), let prev = Worlds.realm(world.realm - 1) else { return max(1, unlocked - 1) }
    let first = (prev.worlds.lowerBound - 1) * 10 + 1, last = prev.worlds.upperBound * 10
    return (first...last).first { isOpen($0) && (stars[$0] ?? 0) < 3 } ?? max(1, unlocked - 1)
  }

  public func worldComplete(_ world: Int) -> Bool {
    guard let w = Worlds.world(world) else { return false }
    return w.levels.allSatisfy { (stars[$0] ?? 0) > 0 }
  }
  public func realmComplete(_ realm: Int) -> Bool {
    guard let r = Worlds.realm(realm) else { return false }
    return r.worlds.allSatisfy(worldComplete)
  }

  public enum Cheer: Equatable, Sendable {
    case world(Int), realm(Int)
    public var id: String { switch self { case .world(let n): "world-\(n)"; case .realm(let n): "realm-\(n)" } }
  }
  /// The next complete moment still to show, once each. A realm's own moment covers its last world's.
  public var pendingCheer: Cheer? {
    let done = Set(cheered ?? [])
    for r in Worlds.realms where realmComplete(r.number) && !done.contains(Cheer.realm(r.number).id) { return .realm(r.number) }
    for w in Worlds.all where worldComplete(w.number) && !done.contains(Cheer.world(w.number).id) { return .world(w.number) }
    return nil
  }
  public mutating func markCheered(_ cheer: Cheer) {
    var ids = [cheer.id]
    if case .realm(let n) = cheer, let r = Worlds.realm(n) { ids += r.worlds.map { Cheer.world($0).id } }
    let have = Set(cheered ?? [])
    let new = ids.filter { !have.contains($0) }
    if !new.isEmpty { cheered = (cheered ?? []) + new }
  }

  /// A backdrop opens when the first level of a world that uses it does.
  public func arenaOpen(_ arena: Arena) -> Bool { firstWorld(using: arena).map { isOpen($0.levels.lowerBound) } ?? false }
  /// The first world drawn on this backdrop, which is where it unlocks.
  public func firstWorld(using arena: Arena) -> World? { Worlds.all.first { $0.biome == arena } }
}

/// How realms open. Generous on purpose: clearing every level of a realm gives 80 stars, so 100 asks for a
/// two-star run on about a quarter of them. Nobody who plays normally should stall.
public enum Gates {
  public static let starsPerRealm = 100
  /// Stars needed from the realm before `realm` (0 for the first).
  public static func stars(toOpen realm: Int) -> Int { realm <= 1 ? 0 : starsPerRealm }
}

public enum Pose: String, Sendable { case noHinge, closed, book, tabletop, flat }

/// A platform-free reading of the fold, which the app takes from SwiftUI's reserved regions.
public struct FoldLayout: Equatable, Sendable {
  public var vertical: Bool
  public var hinge: Double
  public init(vertical: Bool, hinge: Double) { self.vertical = vertical; self.hinge = hinge }

  /// Finds the game's hinge in the arena. A real fold wins, wherever it is. Otherwise it's the arena's middle.
  /// `fold` is the division region in arena coordinates: x, y, width, height.
  public static func resolve(width: Double, height: Double, top: Double, fold: (x: Double, y: Double, w: Double, h: Double)?, versus: Bool) -> FoldLayout? {
    guard let fold, fold.w > 0, fold.h > 0 else { return nil }
    // In versus each page is a player's half, whichever way the fold runs.
    let vertical = fold.h >= fold.w
    let at = vertical ? fold.x + fold.w / 2 : fold.y + fold.h / 2
    let low = vertical ? 0.2 * width : top + 0.2 * (height - top)
    let high = vertical ? 0.8 * width : top + 0.8 * (height - top)
    guard at > low, at < high else { return nil }
    return FoldLayout(vertical: vertical, hinge: at)
  }

  /// The glow of the hinge follows how far the device is folded: brightest half open. Effects only.
  public static func glow(degrees: Double?) -> Double {
    guard let d = degrees else { return 0 }
    let bend = 1 - min(1, abs(d - 90) / 90)
    return max(0, min(1, bend))
  }
}
