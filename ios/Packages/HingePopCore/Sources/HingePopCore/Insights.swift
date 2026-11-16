// Usage events (0.4.1, the owner's call 2026-11-16, "update the native apps too"; Box Office rule 6): the web game's
// Box Office vocabulary (`track()` in index.html), sent from the app to the same first-party relay. This is the pure
// half: the vocabulary and its check, the on-disk queue, the gates and the batch's bytes. The sender
// (HingePop/Usage.swift) only moves these bytes. Nothing else in the app names an event.
//
// Rules: props are numbers, flags and enums only (never names, free text or ids); the one id is a random install id
// made on this device (a reinstall or the Settings switch resets it); nothing joins the queue or leaves for the network
// while a level is being played (those events wait in a small hold and join the queue at the end card); the queue is
// capped, the oldest dropped first, and a batch is removed only once the relay has taken it.
import Foundation

public enum Insights {
  /// The relay (mutaaf/box-office: `/boxoffice/e/*` forwards PostHog's capture API, and admits an event only when its
  /// Referer is a general-audience Cast List page). The page is the game's own.
  public static let endpoint = "https://mutaafaziz.com/boxoffice/e/batch/"
  public static let referer = "https://mutaafaziz.com/hingepop/"
  /// PostHog's public ingest key, the one Box Office's loader serves to every page (write-only, made for clients).
  public static let token = "phc_pj2w4pWnPNUNK5hZK5TX35tNRFa9skJQrGmZNbHVHr9m"
  public static let QUEUE_CAP = 300
  public static let BATCH_MAX = 50

  // --- the vocabulary (the web's: index.html track()) -----------------------------------------------
  public enum Prop: Equatable, Sendable {
    case number(ClosedRange<Double>)
    case oneOf([String])
    /// true/false, as the web sends `won`, `draw` and `completed`.
    case flag
  }
  /// The web's modes are solo and versus; the app adds its own two (Arcade and the Daily) to the same prop.
  public static let MODES = ["solo", "versus", "arcade", "daily"]
  /// The web's tours: the first Play's and the first two-player match's.
  public static let TOURS = ["solo", "two"]
  public static let DIFFICULTIES = ["normal", "overdrive"]
  static let level = Prop.number(0...100_000)
  /// Every event the app may send and every prop it may carry. Same names and props as the web's, plus session_start
  /// (Cold Gas's) and `difficulty` (native only: the web has no Overdrive).
  public static let EVENTS: [String: [String: Prop]] = [
    "session_start": ["returning": .number(0...1), "days_since_last": .number(0...3650)],
    "game_start": ["mode": .oneOf(MODES), "level": level, "difficulty": .oneOf(DIFFICULTIES)],
    "game_over": ["mode": .oneOf(MODES), "level": level, "difficulty": .oneOf(DIFFICULTIES), "score": .number(0...1_000_000_000),
                  "duration_s": .number(0...86_400), "won": .flag, "crossings": .number(0...100_000), "draw": .flag],
    "tour_end": ["tour": .oneOf(TOURS), "completed": .flag],
  ]
  /// The props every event carries, as the web's loader registers them (Box Office: app, surface, platform).
  public static func base(release: String) -> [String: Value] {
    ["app": .text("hinge-pop"), "surface": .text("app"), "platform": .text("ios"), "audience": .text("general"),
     "site": .text("mutaafaziz.com"), "release": .text(release)]
  }

  public enum Value: Codable, Equatable, Sendable {
    case num(Double), text(String), bool(Bool)
    public init(from d: Decoder) throws {
      let c = try d.singleValueContainer()
      if let b = try? c.decode(Bool.self) { self = .bool(b) }
      else if let v = try? c.decode(Double.self) { self = .num(v) }
      else { self = .text(try c.decode(String.self)) }
    }
    public func encode(to e: Encoder) throws {
      var c = e.singleValueContainer()
      switch self {
      case let .num(v): try c.encode(v)
      case let .text(s): try c.encode(s)
      case let .bool(b): try c.encode(b)
      }
    }
    var any: Any { switch self { case let .num(v): return v; case let .text(s): return s; case let .bool(b): return b } }
  }

  /// The event if it's in the vocabulary, with only its known props, each inside its range or one of its values; nil for
  /// an unknown name. A prop that breaks its rule is dropped, never sent.
  public static func clean(_ name: String, _ props: [String: Value]) -> [String: Value]? {
    guard let spec = EVENTS[name] else { return nil }
    var out: [String: Value] = [:]
    for (k, v) in props {
      guard let rule = spec[k] else { continue }
      switch (rule, v) {
      case let (.number(r), .num(x)) where x.isFinite && r.contains(x): out[k] = .num(x)
      case let (.oneOf(vals), .text(s)) where vals.contains(s): out[k] = .text(s)
      case let (.flag, .bool(b)): out[k] = .bool(b)
      default: continue
      }
    }
    return out
  }

  /// A mode's name and level as the web counts them: the campaign is "solo" at its level; the rest have no level (0).
  public static func describe(_ mode: GameMode) -> (mode: String, level: Double)? {
    switch mode {
    case .campaign(let n): return ("solo", Double(max(0, n)))
    case .versus: return ("versus", 0)
    case .arcade: return ("arcade", 0)
    case .daily: return ("daily", 0)
    case .sandbox: return nil
    }
  }
  /// Seconds to a tenth, as the web rounds `duration_s`.
  public static func seconds(_ t: Double) -> Double { (max(0, t) * 10).rounded() / 10 }

  // --- events and the queue --------------------------------------------------------------------------
  public struct Event: Codable, Equatable, Sendable {
    public var name: String
    public var props: [String: Value]
    /// Milliseconds since 1970 (the device clock).
    public var at: Double
    public init(name: String, props: [String: Value], at: Double) { self.name = name; self.props = props; self.at = at }
  }

  /// Where the app is, as the gates read it.
  public enum Moment: Sendable { case menu, play, result }
  /// Nothing joins the queue (or leaves for the network) while a level is being played.
  public static func quiet(_ m: Moment) -> Bool { m == .play }

  /// The queue on disk and the hold for a level in progress. A value: the app keeps one, saves it, and hands the sender
  /// a batch to try.
  public struct Queue: Codable, Equatable, Sendable {
    public var events: [Event] = []
    /// Events made during play: they join `events` at the end card (or when the level is left).
    public var held: [Event] = []
    /// The install id: a random UUID made the first time an event is kept; nil once cleared.
    public var installId: String?
    public init() {}
    enum CodingKeys: String, CodingKey { case events, installId }
    public init(from d: Decoder) throws {
      let c = try d.container(keyedBy: CodingKeys.self)
      events = (try? c.decodeIfPresent([Event].self, forKey: .events)).flatMap { $0 } ?? []
      installId = (try? c.decodeIfPresent(String.self, forKey: .installId)).flatMap { $0 }
      if events.count > QUEUE_CAP { events.removeFirst(events.count - QUEUE_CAP) }
    }

    /// Add an event (checked against the vocabulary). `on` false: nothing is kept. During play it's held.
    @discardableResult
    public mutating func add(_ name: String, _ props: [String: Value] = [:], at: Double, moment: Moment, on: Bool) -> Bool {
      guard on, let p = Insights.clean(name, props) else { return false }
      if installId == nil { installId = UUID().uuidString.lowercased() }
      let e = Event(name: name, props: p, at: at)
      if Insights.quiet(moment) { held.append(e); if held.count > 32 { held.removeFirst() } }
      else { events.append(e); cap() }
      return true
    }
    /// The level is over: what it held joins the queue.
    public mutating func release() {
      guard !held.isEmpty else { return }
      events += held; held.removeAll(); cap()
    }
    mutating func cap() { if events.count > QUEUE_CAP { events.removeFirst(events.count - QUEUE_CAP) } }
    /// The next batch to send: the oldest events, at most BATCH_MAX. Empty during play or with nothing to send.
    public func next(moment: Moment, on: Bool) -> [Event] {
      guard on, !Insights.quiet(moment), installId != nil else { return [] }
      return Array(events.prefix(BATCH_MAX))
    }
    /// The relay took these: drop them (by value, so events added while the batch was in flight stay).
    public mutating func sent(_ batch: [Event]) {
      var drop = batch.count
      events.removeAll { e in
        guard drop > 0, batch.contains(e) else { return false }
        drop -= 1; return true
      }
    }
    /// Settings → off: nothing kept, and the id is gone (a new one is made if it's turned on again).
    public mutating func clear() { events.removeAll(); held.removeAll(); installId = nil }

    public static func decode(_ data: Data?) -> Queue {
      guard let data, let q = try? JSONDecoder().decode(Queue.self, from: data) else { return Queue() }
      return q
    }
    public func encoded() -> Data? { try? JSONEncoder().encode(self) }
  }

  // --- the batch's bytes (PostHog's /batch/ shape) ---------------------------------------------------
  /// The body of one POST. `$geoip_disable`: PostHog derives no location from these (the app's label has no location).
  public static func body(_ batch: [Event], installId: String, release: String) -> Data? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let shared = base(release: release)
    let items: [[String: Any]] = batch.map { e in
      var p: [String: Any] = ["distinct_id": installId, "$lib": "hingepop-ios", "$geoip_disable": true]
      for (k, v) in shared { p[k] = v.any }
      for (k, v) in e.props { p[k] = v.any }
      return ["event": e.name, "properties": p, "timestamp": iso.string(from: Date(timeIntervalSince1970: e.at / 1000))]
    }
    return try? JSONSerialization.data(withJSONObject: ["api_key": token, "batch": items], options: [.sortedKeys])
  }

  // --- the session's numbers -------------------------------------------------------------------------
  /// Days since 1970 (UTC).
  public static func day(_ ms: Double) -> Int { Int((ms / 86_400_000).rounded(.down)) }

  /// The visit counters on this device that session_start reads. Local only: nothing here is sent except as the
  /// event's two numbers.
  public struct Visits: Codable, Equatable, Sendable {
    public var sessions = 0
    public var lastDay: Int?
    public init() {}
    public static func decode(_ data: Data?) -> Visits {
      guard let data, let v = try? JSONDecoder().decode(Visits.self, from: data) else { return Visits() }
      return v
    }
    public func encoded() -> Data? { try? JSONEncoder().encode(self) }
    /// A new session: its event's props, and the counters moved on.
    public mutating func start(at ms: Double) -> [String: Value] {
      let today = Insights.day(ms)
      let before = sessions
      let since = lastDay.map { max(0, today - $0) } ?? 0
      sessions = before + 1; lastDay = today
      return ["returning": .num(before > 0 ? 1 : 0), "days_since_last": .num(Double(min(3650, since)))]
    }
  }
}
