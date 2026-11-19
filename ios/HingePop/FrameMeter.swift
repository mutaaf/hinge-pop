// The in-play frame meter (native only): per level, p50/p95/max frame time, dropped frames against the display's
// target, how long the level took to load, peak node count, the worst thermal state, Low Power Mode, memory warnings
// and the effects level. It's sent as `perf_level` beside `game_over` at the end card (or when a level is left), by
// `Usage`, under the same switch and batching as everything else.
//
// Cost: `frame` is one line in `GameScene.update(_:)`. It allocates nothing (a fixed histogram in
// `Telemetry.FrameStats`); every 120th frame it reads the thermal state and Low Power Mode and counts the scene's
// nodes, which is the only work that walks the tree.
import Foundation
import QuartzCore
import os
import SpriteKit
import UIKit
import HingePopCore

@MainActor
final class FrameMeter {
  static let shared = FrameMeter()

  /// The adaptive effects-quality level, if the scene has one (the perf pass's `FXBudget`): set by whoever owns it,
  /// e.g. `FrameMeter.shared.effectsLevel = { Double(FXBudget.shared.level.rawValue) }`. Nil leaves the prop out.
  var effectsLevel: (() -> Double?)?

  private var stats = Telemetry.FrameStats()
  private(set) var running = false
  private var last: TimeInterval = 0
  private var seen = 0
  private var began: CFTimeInterval = 0
  private var loadMs: Double?
  private var peakNodes = 0
  private var thermal = 0
  private var lowPower = false
  private var warnings = 0
  private var fxLow: Double?
  private var loadState: OSSignpostIntervalState?
  private var levelState: OSSignpostIntervalState?

  /// A level starts (Usage.gameStarted). The level's first two frames are its load (the scene builds and prewarms
  /// on the first), so they're timed as `load_ms` and kept out of the frame statistics.
  func begin() {
    if let s = levelState { Signposts.end("level", s) }
    if let s = loadState { Signposts.end("level_load", s) }
    stats.reset(targetFPS: 60)
    running = true
    last = 0; seen = 0; loadMs = nil; peakNodes = 0; warnings = 0; fxLow = nil
    thermal = Self.thermalIndex(); lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    began = CACurrentMediaTime()
    levelState = Signposts.begin("level")
    loadState = Signposts.begin("level_load")
  }

  /// Every frame, from `GameScene.update(_:)`. Allocation-free.
  func frame(_ time: TimeInterval, _ scene: SKScene) {
    guard running else { return }
    seen += 1
    defer { last = time }
    if seen <= 2 {
      if seen == 2 {
        loadMs = (CACurrentMediaTime() - began) * 1000
        if let s = loadState { Signposts.end("level_load", s); loadState = nil }
        // The target is whatever the view asks for, capped by what the screen can do (ProMotion: 120).
        let screen = Double(scene.view?.window?.windowScene?.screen.maximumFramesPerSecond ?? 60)
        let asked = Double(scene.view?.preferredFramesPerSecond ?? 60)
        stats.reset(targetFPS: min(screen, asked > 0 ? asked : screen))
      }
      return
    }
    stats.add(time - last)
    if seen % 120 == 0 { sample(scene) }
  }

  private func sample(_ scene: SKScene) {
    thermal = max(thermal, Self.thermalIndex())
    lowPower = lowPower || ProcessInfo.processInfo.isLowPowerModeEnabled
    peakNodes = max(peakNodes, Self.count(scene))
    if let fx = effectsLevel?() { fxLow = min(fxLow ?? fx, fx) }
  }

  func memoryWarning() { if running { warnings += 1 } }

  /// The level is over: the perf_level props (with the level's own mode/level/difficulty added by Usage), or nil if
  /// the meter wasn't running or saw too few frames to say anything.
  func finish(outcome: String) -> [String: Insights.Value]? {
    guard running else { return nil }
    running = false
    if let s = loadState { Signposts.end("level_load", s); loadState = nil }
    if let s = levelState { Signposts.end("level", s); levelState = nil }
    Signposts.event("level_end", outcome)
    guard stats.frames >= 30 else { return nil }
    var p: [String: Insights.Value] = [
      "outcome": .text(outcome), "frames": .num(Double(stats.frames)),
      "p50_ms": .num(Telemetry.round(stats.percentile(0.5), 2)), "p95_ms": .num(Telemetry.round(stats.percentile(0.95), 2)),
      "max_ms": .num(Telemetry.round(stats.maxMs, 1)), "dropped_pct": .num(Telemetry.round(stats.droppedPercent, 1)),
      "target_fps": .num(stats.targetFPS),
      "thermal": .text(Telemetry.THERMAL[min(Telemetry.THERMAL.count - 1, max(0, thermal))]),
      "low_power": .bool(lowPower), "memory_warnings": .num(Double(warnings)),
    ]
    if let loadMs { p["load_ms"] = .num(Telemetry.round(loadMs)) }
    if peakNodes > 0 { p["peak_nodes"] = .num(Double(peakNodes)) }
    // The lowest effects level the level dropped to (the budget lowers it under load).
    if let fx = fxLow ?? effectsLevel?() { p["fx_level"] = .num(fx) }
    return p
  }

  private static func thermalIndex() -> Int {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: return 0
    case .fair: return 1
    case .serious: return 2
    case .critical: return 3
    @unknown default: return 0
    }
  }

  /// Every node under the scene. Only on sampled frames.
  private static func count(_ node: SKNode) -> Int {
    var n = 0
    for c in node.children { n += 1 + count(c) }
    return n
  }
}
