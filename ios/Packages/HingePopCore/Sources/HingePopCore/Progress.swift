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
  public var sound = true
  public var haptics = true
  public var arena: Arena? = nil
  public init() {}

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
