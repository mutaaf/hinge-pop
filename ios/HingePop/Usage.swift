// Usage events (0.4.1; Box Office rule 6): the thin sender around HingePopCore's Insights (the vocabulary, the queue,
// the gates and the bytes). Events are added at a level's start and end and at the tour's end, never from the frame
// loop's steps; they are sent in one batch at launch, at the end card, when a level is left and when the app goes to
// the background, over an ephemeral session with no cookies, to Box Office's first-party relay on mutaafaziz.com.
// From the hardening pass it also carries the health events (`perf_level` from FrameMeter.swift, `app_metrics`,
// `app_diagnostic` and `save_recovered` from Diagnostics.swift) under the same switch and the same never-in-play rule.
// A failed send keeps its events for next time. Settings > Privacy > Share usage stats turns it off: nothing is kept or
// sent, and the queue and the install id are cleared.
import Foundation
import UIKit
import HingePopCore

@MainActor
final class Usage {
  static let shared = Usage()
  static let KEY = "hinge-pop-insights.v1"
  static let VISITS = "hinge-pop-visits.v1"

  private let defaults = UserDefaults.standard
  private var queue: Insights.Queue
  private var sending = false
  private var backgroundAt: Date?
  /// Where the app is: play holds events and sends nothing.
  private(set) var moment = Insights.Moment.menu
  /// The switch, mirrored from the save by AppModel (`GameProgress.usage`).
  var enabled = true

  /// Our own runs never count as players: a Debug build (tests, captures, Xcode runs) sends nothing unless launched
  /// with `-insights`; `-insights-dry` prints each batch instead of sending it. Release builds always may.
  private let allowed: Bool
  private let dry: Bool

  init() {
    queue = Insights.Queue.decode(defaults.data(forKey: Usage.KEY))
    #if DEBUG
    let args = ProcessInfo.processInfo.arguments
    dry = args.contains("-insights-dry")
    allowed = args.contains("-insights") || dry
    #else
    allowed = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    dry = false
    #endif
  }

  var on: Bool { allowed && enabled }

  /// Name an event (it must be in the vocabulary, or it's dropped).
  func track(_ name: String, _ props: [String: Insights.Value] = [:]) {
    guard queue.add(name, props, at: Date().timeIntervalSince1970 * 1000, moment: moment, on: on) else { return }
    if !Insights.quiet(moment) { save() }
  }

  /// A level starts: game_start, then play holds everything until it's over.
  func gameStarted(_ props: [String: Insights.Value]) {
    // A level that ends without an end card (a restart from pause) still files its frames.
    if FrameMeter.shared.running { perf("left") }
    moment = .menu
    queue.release()
    track("game_start", props)
    level = props.filter { ["mode", "level", "difficulty"].contains($0.key) }
    moment = .play
    FrameMeter.shared.begin()
  }
  /// The end card is up: perf_level and game_over join the queue with what the level held, and the batch goes.
  func gameOver(_ props: [String: Insights.Value]) {
    moment = .result
    queue.release()
    let outcome: String
    if case .bool(let won)? = props["won"] { outcome = won ? "won" : "lost" } else { outcome = "ended" }
    perf(outcome)
    track("game_over", props)
    save()
    flush()
  }
  /// The level was left (Home from pause, or the end card): back to the menus.
  func left() {
    moment = .menu
    queue.release()
    if FrameMeter.shared.running { perf("left") }
    save()
    flush()
  }
  /// The playing level's mode, level and difficulty, for its perf_level.
  private var level: [String: Insights.Value] = [:]
  /// The frame meter's numbers for the level that just ended (nothing if it saw too little to say).
  private func perf(_ outcome: String) {
    guard let p = FrameMeter.shared.finish(outcome: outcome) else { return }
    track("perf_level", p.merging(level) { a, _ in a })
  }

  /// A session: at launch, and on coming back after half an hour away.
  func sessionStart() {
    guard on else { return }
    var v = Insights.Visits.decode(defaults.data(forKey: Usage.VISITS))
    let props = v.start(at: Date().timeIntervalSince1970 * 1000)
    if let d = v.encoded() { defaults.set(d, forKey: Usage.VISITS) }
    track("session_start", props)
    flush()
  }
  func didEnterBackground() {
    backgroundAt = Date()
    // A level left in the background is still in play: its held events wait for its end.
    let id = UIApplication.shared.beginBackgroundTask(withName: "usage") {}
    flush { UIApplication.shared.endBackgroundTask(id) }
  }
  func willEnterForeground() {
    if let t = backgroundAt, Date().timeIntervalSince(t) > 30 * 60 { sessionStart() }
    backgroundAt = nil
  }

  /// Settings > Privacy.
  func setOn(_ v: Bool) {
    enabled = v
    if !v { queue.clear(); save() }
  }

  /// Send one batch, off the main thread. Nothing during play, nothing when off, one send at a time.
  func flush(done: (() -> Void)? = nil) {
    let batch = queue.next(moment: moment, on: on)
    guard !sending, !batch.isEmpty, let id = queue.installId,
          let body = Insights.body(batch, installId: id, release: Usage.release) else { done?(); return }
    if dry {
      for e in batch { print("INSIGHTS \(e.name) \(e.props.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))") }
      queue.sent(batch); save(); done?(); return
    }
    sending = true
    Task.detached(priority: .utility) {
      let ok = await Usage.post(body)
      await MainActor.run {
        self.sending = false
        if ok { self.queue.sent(batch); self.save() }
        done?()
      }
    }
  }

  /// No cookies, no cache, no shared session state: one plain POST.
  nonisolated private static let session: URLSession = {
    let c = URLSessionConfiguration.ephemeral
    c.httpShouldSetCookies = false
    c.httpCookieAcceptPolicy = .never
    c.requestCachePolicy = .reloadIgnoringLocalCacheData
    c.timeoutIntervalForRequest = 10
    c.timeoutIntervalForResource = 15
    c.waitsForConnectivity = false
    return URLSession(configuration: c)
  }()

  nonisolated private static func post(_ body: Data) async -> Bool {
    guard let url = URL(string: Insights.endpoint) else { return false }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.httpBody = body
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // The relay admits an event by its Referer: the game's own page, a general-audience app in Cast List.
    req.setValue(Insights.referer, forHTTPHeaderField: "Referer")
    guard let (_, r) = try? await session.data(for: req), let http = r as? HTTPURLResponse else { return false }
    return (200..<300).contains(http.statusCode)
  }

  private func save() { if let d = queue.encoded() { defaults.set(d, forKey: Usage.KEY) } }

  static let release = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
}
