import Foundation
import QuartzCore

/// The adaptive effects budget. Play starts at full juice; if frames keep missing their deadline the budget
/// steps down (fewer film shards and sparks, then 60 Hz instead of ProMotion's 120), and it steps back up once
/// play has run clean for a while. A hot device (thermal state serious or critical) or Low Power Mode caps it,
/// whatever the frame times say. It only ever changes how much decoration is drawn, never the rules, so the
/// simulation stays deterministic. `level` is read-only for telemetry.
@MainActor
final class FXBudget {
  static let shared = FXBudget()

  /// 3 is full juice, 0 the leanest. Telemetry reads this.
  private(set) var level = 3
  /// Why the cap is where it is (the device, not frame times): "thermal", "lowPower" or nil.
  private(set) var cappedBy: String?
  /// How many level changes since launch, for telemetry.
  private(set) var changes = 0

  /// Share of decorative debris (film shards, halos, glints) to throw: 1 at full juice.
  var debris: Double { [0.3, 0.5, 0.75, 1][level] }
  /// Share of emitter sparks.
  var sparks: Double { [0.35, 0.55, 0.8, 1][level] }
  /// Frames per second to ask for, given the screen's maximum. ProMotion's 120 Hz doubles every per-frame cost,
  /// so it's the first thing given up when frames run late, the device is hot or Low Power Mode is on.
  func frameRate(max: Int) -> Int { level >= 2 && cap >= 2 && !lowPower ? max : min(max, 60) }

  // MARK: Measuring

  private var window: [Bool] = []
  private var windowAt = 0
  private var late = 0
  private var cleanFor = 0.0
  private var sinceChange = 0.0
  private var checkIn = 0.0
  /// Clean seconds needed before stepping back up. It doubles each time a step up doesn't hold, so a device
  /// that can't quite keep up settles instead of flapping between rates.
  private var upAfter = 8.0
  private var lastUp = -100.0
  private var clock = 0.0
  private var cap = 3
  private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
  /// Two seconds of frames at up to 120 Hz.
  private static let windowSize = 240

  /// Debug: `-fx 0...3` pins the level, to see what each step looks like.
  private var pinned: Int?

  private init() {
    window = [Bool](repeating: false, count: Self.windowSize)
    refreshDevice()
    level = cap
    #if DEBUG
    if let n = Debug.int("-fx") { pinned = max(0, min(3, n)); level = pinned ?? level }
    #endif
  }

  /// One rendered frame: `dt` is the time since the last, `target` the interval asked for (1/fps).
  /// Steps down when more than a fifth of the last two seconds' frames ran late, up after eight clean seconds.
  func frame(dt: Double, target: Double) {
    // A pause, a hitch from leaving the app, or the first frame says nothing about steady play.
    guard pinned == nil, dt > 0, dt < 0.25, target > 0 else { return }
    checkIn -= dt
    if checkIn <= 0 { checkIn = 1; refreshDevice() }
    let isLate = dt > target * 1.5
    if window[windowAt] { late -= 1 }
    window[windowAt] = isLate
    if isLate { late += 1 }
    windowAt = (windowAt + 1) % window.count
    sinceChange += dt
    clock += dt
    cleanFor = isLate ? 0 : cleanFor + dt
    // Allow the odd late frame when "clean": a GC-free game still sees the occasional system hitch.
    if late * 5 > window.count, sinceChange > 2, level > 0 {
      if clock - lastUp < 20 { upAfter = min(64, upAfter * 2) }
      set(level - 1)
    } else if level < cap, sinceChange > upAfter, late * 50 < window.count, cleanFor > 1 {
      lastUp = clock
      set(level + 1)
    }
    if level > cap { set(cap) }
  }

  /// A new level starts at whatever the budget has learned, but never above the device's cap.
  func levelStarted() {
    guard pinned == nil else { return }
    refreshDevice()
    if level > cap { set(cap) }
  }

  private func set(_ l: Int) {
    let next = max(0, min(3, l))
    guard next != level else { return }
    level = next
    changes += 1
    sinceChange = 0
    cleanFor = 0
    window = [Bool](repeating: false, count: Self.windowSize)
    late = 0
  }

  private func refreshDevice() {
    lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    switch ProcessInfo.processInfo.thermalState {
    case .critical: cap = 0; cappedBy = "thermal"
    case .serious: cap = 1; cappedBy = "thermal"
    default: cap = lowPower ? 2 : 3; cappedBy = lowPower ? "lowPower" : nil
    }
  }
}
