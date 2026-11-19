import Foundation

/// Where saves live. The app's is UserDefaults (each `set` replaces the value whole, and the defaults store writes
/// its file atomically); tests use memory, and `FileSaveMedium` writes files atomically.
public protocol SaveMedium: AnyObject {
  func read(_ slot: String) -> Data?
  @discardableResult func write(_ data: Data, to slot: String) -> Bool
  func remove(_ slot: String)
}

/// The save, hardened: progress is never lost to a bad decode.
///
/// Three slots beside each other:
/// - `primary`: the save, plain `GameProgress` JSON (so an older build can still read it after a downgrade).
/// - `backup`: the last save that loaded cleanly, copied at each launch and when the app goes to the background.
/// - `kept`: bytes this build couldn't use as they were: unreadable (corrupt, truncated) or from a newer build. They
///   are never thrown away by a normal save, and each launch tries them again, so an update that can read them (or
///   a downgrade's return trip) gets its progress back.
///
/// Load order: the primary; if it won't decode, a salvage of it (dropping the one or two fields this build can't
/// read, such as a backdrop a newer build added); then the backup; then a fresh start. Writes are checked (the bytes
/// must decode back to the same progress) before they replace anything.
public final class SaveVault {
  /// Bump when the save's meaning changes in a way an older build would misread.
  public static let schema = 1
  public let medium: SaveMedium
  public let primary: String
  public var backup: String { primary + ".backup" }
  public var kept: String { primary + ".kept" }

  public enum Source: String, Equatable, Sendable {
    /// No save yet (a fresh install).
    case none
    /// The save loaded as it was.
    case primary
    /// The save was unreadable as a whole; most of it was recovered.
    case salvaged
    /// The save was unreadable; the backup loaded.
    case backup
    /// A kept copy (from an earlier unreadable or newer save) was further along, and now loads.
    case rescued
    /// Nothing could be read: a fresh start (the unreadable bytes are kept).
    case fresh
  }
  public struct Loaded: Equatable, Sendable {
    public var progress: GameProgress
    public var source: Source
    /// True when the save came from a newer build than this one.
    public var fromTheFuture = false
  }

  public init(medium: SaveMedium, key: String = "hinge-pop-progress") {
    self.medium = medium
    primary = key
  }

  static func decode(_ data: Data?) -> GameProgress? {
    guard let data, !data.isEmpty else { return nil }
    return try? JSONDecoder().decode(GameProgress.self, from: data)
  }

  /// The save as well as it can be read, and the slots tidied for this session.
  public func load() -> Loaded {
    let bytes = medium.read(primary)
    var out: Loaded
    if let p = Self.decode(bytes) {
      out = Loaded(progress: p, source: .primary)
      if (p.saveSchema ?? 0) > Self.schema, let bytes {
        // A newer build wrote it. Play on what this build understands, and keep the original whole.
        out.fromTheFuture = true
        medium.write(bytes, to: kept)
      } else if let bytes {
        medium.write(bytes, to: backup)
      }
    } else {
      if let bytes, !bytes.isEmpty { medium.write(bytes, to: kept) }
      if let s = Self.salvage(bytes) {
        out = Loaded(progress: s, source: .salvaged)
      } else if let b = Self.decode(medium.read(backup)) {
        out = Loaded(progress: b, source: .backup)
      } else {
        out = Loaded(progress: GameProgress(), source: bytes == nil ? .none : .fresh)
      }
      if out.source != .none && out.source != .fresh { save(out.progress) }
    }
    rescue(&out)
    return out
  }

  /// A kept copy that now reads wins when it's further along, or as far along and written by a newer build (so a
  /// downgrade's round trip keeps what only the newer build knew). Once the save itself loaded cleanly, a kept copy
  /// that lost (and isn't from a newer build) has done its job and goes.
  private func rescue(_ out: inout Loaded) {
    guard !out.fromTheFuture, let data = medium.read(kept), let k = Self.decode(data) ?? Self.salvage(data) else { return }
    let future = (k.saveSchema ?? 0) > Self.schema
    let newerWriter = (k.saveSchema ?? 0) > (out.progress.saveSchema ?? 0)
    if Self.ahead(k, of: out.progress) || (newerWriter && !Self.ahead(out.progress, of: k)) {
      let clean = out.source == .primary
      out = Loaded(progress: k, source: .rescued, fromTheFuture: future)
      if !future {
        save(k)
        if clean { medium.remove(kept) }
      }
      return
    }
    if out.source == .primary && !future { medium.remove(kept) }
  }

  /// True when `a` holds more play than `b`.
  public static func ahead(_ a: GameProgress, of b: GameProgress) -> Bool {
    (a.unlocked, a.totalStars, a.arcadeBest, a.dailyBest.count) > (b.unlocked, b.totalStars, b.arcadeBest, b.dailyBest.count)
  }

  /// Writes the save, stamped with this build's schema. The bytes must read back to the same progress before they
  /// replace the old ones; false if they didn't (or the medium refused).
  @discardableResult
  public func save(_ progress: GameProgress) -> Bool {
    var p = progress
    p.saveSchema = Self.schema
    guard let data = try? JSONEncoder().encode(p), Self.decode(data) == p else { return false }
    return medium.write(data, to: primary)
  }

  /// Copies the save to the backup, if it reads. The app calls this when it goes to the background.
  public func backupNow() {
    guard let data = medium.read(primary), let p = Self.decode(data), (p.saveSchema ?? 0) <= Self.schema else { return }
    medium.write(data, to: backup)
  }

  /// A save that won't decode as a whole: drop the top-level fields this build can't read (one, then any two) and
  /// keep the rest. Nil when it isn't a JSON object at all (corrupt, truncated) or the core of it is gone.
  static func salvage(_ data: Data?) -> GameProgress? {
    guard let data, !data.isEmpty,
          let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], !obj.isEmpty else { return nil }
    func attempt(_ d: [String: Any]) -> GameProgress? {
      guard let bytes = try? JSONSerialization.data(withJSONObject: d) else { return nil }
      return try? JSONDecoder().decode(GameProgress.self, from: bytes)
    }
    let keys = obj.keys.sorted()
    for k in keys {
      var d = obj; d[k] = nil
      if let p = attempt(d) { return p }
    }
    for (i, a) in keys.enumerated() {
      for b in keys[(i + 1)...] {
        var d = obj; d[a] = nil; d[b] = nil
        if let p = attempt(d) { return p }
      }
    }
    return nil
  }
}

/// Saves in memory, for tests and previews.
public final class MemorySaveMedium: SaveMedium {
  public var slots: [String: Data] = [:]
  public var failWrites = false
  public init() {}
  public func read(_ slot: String) -> Data? { slots[slot] }
  public func write(_ data: Data, to slot: String) -> Bool {
    guard !failWrites else { return false }
    slots[slot] = data; return true
  }
  public func remove(_ slot: String) { slots[slot] = nil }
}

/// Saves as files in one folder, each written atomically (to a temporary file, then renamed over the old one), so a
/// crash or a full disk mid-write leaves the previous save whole.
public final class FileSaveMedium: SaveMedium {
  public let folder: URL
  public init(folder: URL) {
    self.folder = folder
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }
  private func url(_ slot: String) -> URL { folder.appendingPathComponent(slot).appendingPathExtension("json") }
  public func read(_ slot: String) -> Data? { try? Data(contentsOf: url(slot)) }
  public func write(_ data: Data, to slot: String) -> Bool {
    (try? data.write(to: url(slot), options: [.atomic])) != nil
  }
  public func remove(_ slot: String) { try? FileManager.default.removeItem(at: url(slot)) }
}
