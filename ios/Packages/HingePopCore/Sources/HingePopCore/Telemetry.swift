// Observability's pure half (native only, from the hardening pass): the in-play frame meter's statistics and the
// arithmetic that turns MetricKit's histograms into a handful of numbers. The app's `FrameMeter.swift` and
// `Diagnostics.swift` read the platform; everything here is plain values so `make core` tests it. What these produce
// still goes through `Insights.clean`, so only the vocabulary's numbers, flags and enums ever leave.
import Foundation

public enum Telemetry {
  // --- frames ---------------------------------------------------------------------------------------
  /// Frame times for one level, in a fixed histogram: adding a frame never allocates (the bins are made once).
  public struct FrameStats: Sendable {
    /// 0.25 ms bins up to 100 ms; slower frames land in the last bin (and in `maxMs`).
    public static let binMs = 0.25
    public static let bins = 400
    /// A gap this long is a pause or the app in the background, not a slow frame: it isn't counted.
    public static let gap = 0.25
    private var hist: [UInt32]
    public private(set) var frames = 0
    /// Frames the display wanted but didn't get: a 25 ms frame at 60 Hz missed one.
    public private(set) var dropped = 0
    public private(set) var maxMs = 0.0
    /// The display's target frame time, in seconds.
    public private(set) var interval = 1.0 / 60

    public init(targetFPS: Double = 60) {
      hist = [UInt32](repeating: 0, count: Self.bins)
      reset(targetFPS: targetFPS)
    }
    public mutating func reset(targetFPS: Double) {
      for i in hist.indices { hist[i] = 0 }
      frames = 0; dropped = 0; maxMs = 0
      interval = 1 / min(240, max(1, targetFPS.isFinite ? targetFPS : 60))
    }
    public var targetFPS: Double { (1 / interval).rounded() }

    /// One frame's time (seconds since the last). Non-finite, zero, negative and pause-length gaps are ignored.
    public mutating func add(_ dt: Double) {
      guard dt.isFinite, dt > 0, dt < Self.gap else { return }
      let ms = dt * 1000
      hist[min(Self.bins - 1, Int(ms / Self.binMs))] &+= 1
      frames += 1
      maxMs = max(maxMs, ms)
      // Half a frame of slack: vsync jitter isn't a drop.
      let missed = Int((dt / interval - 0.5).rounded(.down))
      if missed > 0 { dropped += missed }
    }

    /// The frame time at quantile q (0...1), in ms: the upper edge of the bin it falls in. 0 with no frames.
    public func percentile(_ q: Double) -> Double {
      guard frames > 0 else { return 0 }
      let want = max(1, Int((Double(frames) * min(1, max(0, q))).rounded(.up)))
      var seen = 0
      for (i, n) in hist.enumerated() {
        seen += Int(n)
        if seen >= want { return i == Self.bins - 1 ? maxMs : min(maxMs, Double(i + 1) * Self.binMs) }
      }
      return maxMs
    }
    /// Missed frames as a share of the frames the display wanted, 0–100.
    public var droppedPercent: Double {
      let wanted = frames + dropped
      return wanted == 0 ? 0 : Double(dropped) / Double(wanted) * 100
    }
  }

  // --- MetricKit's histograms ------------------------------------------------------------------------
  /// One bucket of a MetricKit histogram, in milliseconds.
  public struct Bucket: Equatable, Sendable {
    public var startMs: Double, endMs: Double, count: Int
    public init(startMs: Double, endMs: Double, count: Int) { self.startMs = startMs; self.endMs = endMs; self.count = count }
  }
  public struct Summary: Equatable, Sendable {
    public var count = 0
    /// Bucket midpoints, so an estimate.
    public var p50Ms = 0.0
    public var p90Ms = 0.0
    /// The top edge of the highest non-empty bucket.
    public var maxMs = 0.0
    /// Counts in fixed bands (`bands` edges, ms): a bucket counts where its midpoint falls.
    public var banded: [Int] = []
  }
  /// The launch bands the dashboard shows: under 1 s, 1–2 s, 2–4 s, over 4 s.
  public static let launchBands: [Double] = [1000, 2000, 4000]

  public static func summarize(_ buckets: [Bucket], bands: [Double] = []) -> Summary {
    var s = Summary(banded: Array(repeating: 0, count: bands.count + 1))
    let clean = buckets.filter { $0.count > 0 && $0.startMs.isFinite && $0.endMs.isFinite && $0.endMs >= $0.startMs && $0.startMs >= 0 }
      .sorted { $0.startMs < $1.startMs }
    s.count = clean.reduce(0) { $0 + $1.count }
    guard s.count > 0 else { return s }
    func at(_ q: Double) -> Double {
      let want = Double(s.count) * q
      var seen = 0.0
      for b in clean {
        seen += Double(b.count)
        if seen >= want { return (b.startMs + b.endMs) / 2 }
      }
      return clean.last.map { ($0.startMs + $0.endMs) / 2 } ?? 0
    }
    s.p50Ms = at(0.5); s.p90Ms = at(0.9)
    s.maxMs = clean.map(\.endMs).max() ?? 0
    for b in clean {
      let mid = (b.startMs + b.endMs) / 2
      let band = bands.firstIndex { mid < $0 } ?? bands.count
      s.banded[band] += b.count
    }
    return s
  }

  // --- small conversions ------------------------------------------------------------------------------
  /// "iPhone OS 17.1 (21B74)" or "Version 18.0 (Build 22A3354)" → 17 / 18. Nil when there's no number.
  public static func osMajor(_ s: String) -> Double? {
    guard let r = s.range(of: #"[0-9]+(?=\.)"#, options: .regularExpression) ?? s.range(of: #"[0-9]+"#, options: .regularExpression),
          let n = Int(s[r]), n > 0, n < 100 else { return nil }
    return Double(n)
  }
  /// Rounds to `places` decimals, so numbers carry no more precision than a dashboard needs.
  public static func round(_ v: Double, _ places: Int = 0) -> Double {
    guard v.isFinite else { return v }
    let m = pow(10, Double(places))
    return (v * m).rounded() / m
  }

  /// The thermal states, as `ProcessInfo.ThermalState` orders them.
  public static let THERMAL = ["nominal", "fair", "serious", "critical"]
  /// MetricKit's diagnostics, by kind.
  public static let DIAGNOSTICS = ["crash", "hang", "cpu_exception", "disk_write_exception", "launch"]
  /// How a level's frame meter ended.
  public static let OUTCOMES = ["won", "lost", "ended", "left"]
  /// How the save loaded (`SaveVault.Source`, the ones worth knowing about).
  public static let SAVE_SOURCES = ["salvaged", "backup", "rescued", "fresh"]
}
