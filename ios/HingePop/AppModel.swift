import SwiftUI
import HingePopCore

enum Route: Equatable {
  case home, map, guide, settings
  case play(GameMode)
}

@MainActor @Observable
final class AppModel {
  var route = Route.home
  /// This version's update card, when there's one to show.
  var updateNotes: UpdateNotes?
  /// The card was forced with -whatsNew (debug only), so closing it doesn't record the version.
  @ObservationIgnored private var notesForced = false
  /// A How to play section to open on arrival, set when an update callout sends you there.
  var guideSection: String?
  var progress: GameProgress { didSet { save() } }
  @ObservationIgnored private let key = "hinge-pop-progress"

  init() {
    if let data = UserDefaults.standard.data(forKey: key), let p = try? JSONDecoder().decode(GameProgress.self, from: data) {
      progress = p
      // Saves from before realm gates keep every level they reached.
      progress.adoptGates()
    } else {
      progress = GameProgress()
    }
    #if DEBUG
    let args = ProcessInfo.processInfo.arguments
    if args.contains("-fresh") { progress = GameProgress() }
    if args.contains("-toured") { progress.seenTour = true; progress.seenVersusTour = true }
    // -endCard win|lose plays a level (-level N, default 12) to its end card by itself, for screenshots.
    let endCard = Debug.string("-endCard")
    if args.contains("-demo") || endCard != nil {
      // Screenshots show the game, not the first-time cards.
      for k in ActorKind.allCases { progress.taught.insert("meet-\(k.rawValue)") }
      progress.taught.formUnion(["snapped", "windup", "stagger", "gate", "cross", "small", "shield", "recharge", "combo", "chain", "drop", "slam", "phase", "nearfull", "gatepass", "rush", "crossfold", "clap", "clap-hint", "current"])
      PowerUp.allCases.forEach { progress.taught.insert("got-\($0.rawValue)") }
      for w in Worlds.all { progress.taught.insert("world-\(w.number)") }
      progress.taught.formUnion(["dark", "fogged", "phased", "beat", "shielded", "blink", "regrow"])
    }
    if let n = Debug.int("-unlock") {
      progress.unlocked = n
      // -starsEach k gives every cleared level k stars (1 shows a realm gate); otherwise a believable mix.
      let each = Debug.int("-starsEach")
      for l in 1..<max(1, n) { progress.stars[l] = each ?? [3, 2, 3, 1, 3, 2, 2, 3][l % 8] }
      // -mastery adds grades and challenges: a mix, with world 1 fully done for its medal.
      if args.contains("-mastery") {
        for l in 1..<max(1, n) {
          let all = l <= 10
          progress.record(level: l, stars: progress.stars[l] ?? 1, score: progress.bestScores[l] ?? 0,
                          grade: all ? .s : Grade(rawValue: [4, 3, 2, 3, 1, 2, 3, 0][l % 8]),
                          earned: all ? [true, true, true] : [l % 2 == 0, l % 3 == 0, l % 5 == 0])
        }
      }
      // Seeded saves skip the complete moments, unless -cheer asks for the latest one.
      progress.settleCheers(keepingLatest: args.contains("-cheer"))
    }
    switch Debug.string("-screen") {
    case "map": route = .map
    case "guide": route = .guide
    case "settings": route = .settings
    default: break
    }
    if let n = Debug.int("-level") { route = .play(.campaign(n)) }
    if endCard != nil {
      let n = Debug.int("-level") ?? 12
      progress.seenTour = true
      progress.unlocked = max(progress.unlocked, n)
      // A believable history: a C before, and the first challenge already done, so the card shows what's new.
      if endCard == "win" { progress.record(level: n, stars: 1, score: 1, grade: .c, earned: [true, false, false]) }
      route = .play(.campaign(n))
    }
    if args.contains("-versus") { route = .play(.versus) }
    if args.contains("-arcade") { route = .play(.arcade(seed: 7)) }
    if args.contains("-daily") { route = .play(today()) }
    #endif
    applySettings()
    checkUpdateNotes()
  }

  /// Shows the update card once per version. A fresh install marks the version seen without showing it.
  private func checkUpdateNotes() {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    var show = UpdateNotes.shouldShow(seen: progress.seenNotes, current: version, playedBefore: progress.playedBefore)
    #if DEBUG
    // Tests and store captures launch with flags and never see it, unless they ask with -whatsNew.
    let flagged = ProcessInfo.processInfo.arguments.dropFirst().contains { $0.hasPrefix("-") && !$0.hasPrefix("-NS") && !$0.hasPrefix("-Apple") }
    if Debug.has("-whatsNew") { show = true; notesForced = true } else if flagged { show = false }
    #endif
    guard show, route == .home else {
      if progress.seenNotes == nil && !progress.playedBefore { progress.seenNotes = version }
      return
    }
    guard let url = Bundle.main.url(forResource: version, withExtension: "md", subdirectory: "release-notes"),
          let text = try? String(contentsOf: url, encoding: .utf8),
          let notes = UpdateNotes.parse(text, version: version) else { return }
    updateNotes = notes
  }

  func dismissUpdateNotes() {
    if let v = updateNotes?.version {
      let seen = UpdateNotes.seenAfterClosing(seen: progress.seenNotes, shown: v, forced: notesForced)
      if seen != progress.seenNotes { progress.seenNotes = seen }
    }
    updateNotes = nil
  }

  /// A callout's tap: close the card, then open the place its news is about.
  func follow(_ destination: UpdateNotes.Destination) {
    dismissUpdateNotes()
    switch destination {
    case .map: route = .map
    case .settings: route = .settings
    case .guide(let section): guideSection = section; route = .guide
    case .play: route = .play(.campaign(progress.nextUp))
    case .arcade: route = .play(.arcade(seed: UInt64(Date().timeIntervalSince1970)))
    case .daily: route = .play(today())
    case .versus: route = .play(.versus)
    }
  }

  func applySettings() {
    Sound.shared.enabled = progress.sound
    Haptics.shared.enabled = progress.haptics
  }

  private func save() {
    if let data = try? JSONEncoder().encode(progress) { UserDefaults.standard.set(data, forKey: key) }
  }

  func today() -> GameMode {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    return .daily(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1)
  }

  var dailyKey: String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
  }
}

#if DEBUG
enum Debug {
  static func string(_ flag: String) -> String? {
    let a = ProcessInfo.processInfo.arguments
    return a.firstIndex(of: flag).flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
  }
  static func int(_ flag: String) -> Int? { string(flag).flatMap(Int.init) }
  static func has(_ flag: String) -> Bool { ProcessInfo.processInfo.arguments.contains(flag) }
  /// Screenshot scripts wait for this file instead of guessing with a sleep.
  static func ready(_ token: String) {
    guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
    let url = dir.appendingPathComponent("hingepop.ready")
    let text = ((try? String(contentsOf: url, encoding: .utf8)) ?? "") + token + "\n"
    try? text.write(to: url, atomically: true, encoding: .utf8)
  }
}
#endif
