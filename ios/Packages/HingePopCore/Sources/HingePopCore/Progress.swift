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
  /// True once someone has played, so an update can tell them what changed.
  public var playedBefore: Bool { seenTour || unlocked > 1 || arcadeBest > 0 || !stars.isEmpty }
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

  public func isOpen(_ level: Int) -> Bool { level <= unlocked }

  /// A backdrop opens when its chapter's first level does.
  public func arenaOpen(_ arena: Arena) -> Bool {
    guard let chapter = Campaign.chapters.first(where: { $0.arena == arena }) else { return false }
    return unlocked >= chapter.levels.lowerBound
  }
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
    let vertical = fold.h >= fold.w
    if versus && !vertical { return nil }
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
