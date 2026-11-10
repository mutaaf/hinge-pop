import SwiftUI
import HingePopCore

enum Route: Equatable {
  case home, map, guide, settings
  case play(GameMode)
}

@MainActor @Observable
final class AppModel {
  var route = Route.home
  var progress: GameProgress { didSet { save() } }
  @ObservationIgnored private let key = "hinge-pop-progress"

  init() {
    if let data = UserDefaults.standard.data(forKey: key), let p = try? JSONDecoder().decode(GameProgress.self, from: data) {
      progress = p
    } else {
      progress = GameProgress()
    }
    #if DEBUG
    let args = ProcessInfo.processInfo.arguments
    if args.contains("-fresh") { progress = GameProgress() }
    if args.contains("-toured") { progress.seenTour = true; progress.seenVersusTour = true }
    if args.contains("-demo") {
      // Screenshots show the game, not the first-time cards.
      for k in ActorKind.allCases { progress.taught.insert("meet-\(k.rawValue)") }
      progress.taught.formUnion(["snapped", "windup", "stagger", "gate", "cross", "small", "shield", "recharge", "combo", "chain", "drop", "slam", "phase", "nearfull", "gatepass", "rush", "crossfold", "clap", "clap-hint"])
      PowerUp.allCases.forEach { progress.taught.insert("got-\($0.rawValue)") }
    }
    if let n = Debug.int("-unlock") {
      progress.unlocked = n
      for l in 1..<max(1, n) { progress.stars[l] = l % 4 == 0 ? 2 : 3 }
    }
    switch Debug.string("-screen") {
    case "map": route = .map
    case "guide": route = .guide
    case "settings": route = .settings
    default: break
    }
    if let n = Debug.int("-level") { route = .play(.campaign(n)) }
    if args.contains("-versus") { route = .play(.versus) }
    if args.contains("-arcade") { route = .play(.arcade(seed: 7)) }
    if args.contains("-daily") { route = .play(today()) }
    #endif
    applySettings()
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
