import Foundation

/// Arcade's record, kept in `GameProgress`.
public struct ArcadeLog: Codable, Equatable, Sendable {
  public var bestWave = 0
  public var runs = 0
  public var lastScore = 0
  public var lastWave = 0
  public init() {}
  /// The furthest checkpoint reached, the wave a run can continue from (1 before any).
  public var checkpoint: Int { Arcade.checkpoint(reaching: bestWave) }
}

/// Arcade's checkpoints: every five waves is a stage you can start a later run from.
public enum Arcade {
  public static let every = 5
  public struct Stage: Equatable, Sendable {
    public let wave: Int
    public let name: String
    public let nod: String
  }
  /// Named stops on the endless ladder, each a wink at arcade lore. Past the last one, they repeat as "Loop N".
  static let named: [(String, String)] = [
    ("Insert Coin", "Every legend starts with a quarter"),
    ("Level Up", "The music gets faster"),
    ("Boss Rush", "Everything at once"),
    ("Bonus Stage", "Smash the car, keep the points"),
    ("Turbo", "Hold B to go faster"),
    ("Night Shift", "The cabinet glows after closing"),
    ("Hi-Score Hall", "Three letters and glory"),
    ("Warp Zone", "A pipe nobody told you about"),
    ("Final Loop", "The game starts over, meaner"),
    ("Kill Screen", "Where the counter runs out"),
  ]
  /// The stage at a checkpoint wave: 1, 5, 10, 15...
  public static func stage(_ wave: Int) -> Stage {
    let i = wave < every ? 0 : wave / every
    if i < named.count { return Stage(wave: max(1, i * every), name: named[i].0, nod: named[i].1) }
    return Stage(wave: i * every, name: "Loop \(i - named.count + 2)", nod: "Still going")
  }
  /// The checkpoint a best wave of `best` unlocks: the last multiple of five reached, or 1.
  public static func checkpoint(reaching best: Int) -> Int { best >= every ? (best / every) * every : 1 }
  /// The stages to show: everything reached, plus the next two to aim for.
  public static func ladder(best: Int) -> [Stage] {
    let top = checkpoint(reaching: best) / every + 2
    return (0...max(2, top)).map { stage($0 * every) }
  }
}

extension GameMode {
  public var isArcade: Bool { if case .arcade = self { true } else { false } }
}
