import CoreHaptics
import UIKit

/// One haptic vocabulary for the whole game. Each cue is a short Core Haptics pattern built once and replayed,
/// so a busy level never allocates on a pop. Devices without Core Haptics get the nearest UIKit feedback.
/// The Haptics toggle in Settings turns all of it off.
@MainActor
final class Haptics {
  static let shared = Haptics()
  var enabled = false { didSet { if enabled && !oldValue { prepare() } } }

  enum Cue: Int, CaseIterable {
    /// A tiny bubble popping, a bubble splitting, a big one splitting.
    case pop, split, bigSplit
    case chain, crossing, shieldLost, heartbeat
    /// Snap the Hinge: a whip crack. The crease clap is the same crack on both pages at once.
    case snap, clap
    case bossIntro, bossHit, bossStagger, bossPhase, bossDown, bossSlam, windup
    case combo, comboTop, win, lose, power, fever, overtime, lastOne
    /// Villains: one arriving (a low warning), one biting, and a Doom ending the run.
    case villain, villainHit, doom
  }

  private var engine: CHHapticEngine?
  private var players: [Cue: CHHapticPatternPlayer] = [:]
  private var lastPlayed = [Double](repeating: 0, count: Cue.allCases.count)
  private var lastAny = 0.0
  /// When the engine last failed to start. Building one blocks the main thread, so a refused engine isn't
  /// retried on every pop: that turned a busy screen into a freeze.
  private var failedAt = -Double.infinity
  private let supports = CHHapticEngine.capabilitiesForHardware().supportsHaptics
  private let light = UIImpactFeedbackGenerator(style: .light)
  private let soft = UIImpactFeedbackGenerator(style: .soft)
  private let rigid = UIImpactFeedbackGenerator(style: .rigid)
  private let heavy = UIImpactFeedbackGenerator(style: .heavy)
  private let notify = UINotificationFeedbackGenerator()

  // The old four words, still used by menus and cards.
  func tap() { play(.pop) }
  func hit() { play(.bossHit) }
  func good() { if enabled { notify.notificationOccurred(.success) } }
  func bad() { if enabled { notify.notificationOccurred(.error) } }

  /// Plays a cue. Small cues are throttled so a chain of thirty pops reads as a buzz, not a jam.
  func play(_ cue: Cue) {
    guard enabled else { return }
    let now = CACurrentMediaTime()
    let gap: Double
    switch cue {
    case .pop, .split, .chain: gap = 0.045
    case .bigSplit, .crossing, .bossHit: gap = 0.06
    default: gap = 0.02
    }
    guard now - lastPlayed[cue.rawValue] >= gap else { return }
    // Light cues give way right after a strong one, so the strong one stays clean.
    if Self.minor(cue), now - lastAny < 0.03 { return }
    lastPlayed[cue.rawValue] = now
    if !Self.minor(cue) { lastAny = now }
    if supports, let player = player(cue) {
      do { try player.start(atTime: CHHapticTimeImmediate); return } catch { players[cue] = nil }
    }
    fallback(cue)
  }

  private static func minor(_ cue: Cue) -> Bool { cue == .pop || cue == .split || cue == .chain }

  private func fallback(_ cue: Cue) {
    switch cue {
    case .pop, .chain: light.impactOccurred(intensity: 0.6)
    case .split: light.impactOccurred()
    case .bigSplit, .bossHit, .combo, .power, .lastOne: rigid.impactOccurred()
    case .crossing, .windup, .overtime, .villain: soft.impactOccurred()
    case .heartbeat: soft.impactOccurred(intensity: 0.7)
    case .snap, .clap, .bossStagger, .bossSlam, .bossIntro: heavy.impactOccurred()
    case .shieldLost, .lose, .villainHit, .doom: notify.notificationOccurred(.error)
    case .bossPhase, .bossDown, .win, .comboTop, .fever: notify.notificationOccurred(.success)
    }
  }

  private func prepare() {
    guard supports else { [light, rigid, heavy, soft].forEach { $0.prepare() }; return }
    guard engine == nil, CACurrentMediaTime() - failedAt > 5 else { return }
    do {
      let e = try CHHapticEngine()
      e.playsHapticsOnly = true
      e.isAutoShutdownEnabled = false
      e.resetHandler = { [weak self] in
        Task { @MainActor in
          guard let self else { return }
          self.players.removeAll()
          self.engine?.start { _ in }
        }
      }
      e.stoppedHandler = { [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          self.players.removeAll()
          self.engine?.start { _ in }
        }
      }
      try e.start()
      engine = e
    } catch {
      engine = nil
      failedAt = CACurrentMediaTime()
    }
  }

  private func player(_ cue: Cue) -> CHHapticPatternPlayer? {
    if let p = players[cue] { return p }
    if engine == nil { prepare() }
    guard let engine, let pattern = try? CHHapticPattern(events: Self.events(cue), parameters: []) else { return nil }
    let p = try? engine.makePlayer(with: pattern)
    players[cue] = p
    if p == nil { failedAt = CACurrentMediaTime() }
    return p
  }

  // MARK: Patterns

  private static func tick(_ t: Double, _ i: Float, _ s: Float) -> CHHapticEvent {
    CHHapticEvent(eventType: .hapticTransient, parameters: [
      CHHapticEventParameter(parameterID: .hapticIntensity, value: i),
      CHHapticEventParameter(parameterID: .hapticSharpness, value: s),
    ], relativeTime: t)
  }
  private static func hum(_ t: Double, _ d: Double, _ i: Float, _ s: Float, decay: Bool = true) -> CHHapticEvent {
    var p = [CHHapticEventParameter(parameterID: .hapticIntensity, value: i), CHHapticEventParameter(parameterID: .hapticSharpness, value: s)]
    if decay {
      p.append(CHHapticEventParameter(parameterID: .attackTime, value: 0))
      p.append(CHHapticEventParameter(parameterID: .decayTime, value: Float(d)))
      p.append(CHHapticEventParameter(parameterID: .sustained, value: 0))
    }
    return CHHapticEvent(eventType: .hapticContinuous, parameters: p, relativeTime: t, duration: d)
  }

  /// The vocabulary: sharp means crisp and small, round means heavy. Bigger moments last longer, never louder
  /// than the shield loss, which is the one hit the player must not miss.
  static func events(_ cue: Cue) -> [CHHapticEvent] {
    switch cue {
    case .pop: return [tick(0, 0.42, 0.9)]
    case .split: return [tick(0, 0.6, 0.65)]
    case .bigSplit: return [tick(0, 0.95, 0.45), hum(0.01, 0.09, 0.45, 0.2)]
    case .chain: return [tick(0, 0.5, 1)]
    case .crossing: return [tick(0, 0.7, 0.15), hum(0, 0.14, 0.4, 0.05)]
    case .shieldLost: return [tick(0, 1, 0.3), hum(0, 0.32, 0.9, 0.08), tick(0.11, 0.85, 0.2)]
    case .heartbeat: return [tick(0, 0.75, 0.05), tick(0.17, 0.5, 0.05)]
    case .snap: return [tick(0, 1, 1), tick(0.035, 0.6, 0.8), hum(0.01, 0.12, 0.5, 0.6)]
    case .clap: return [tick(0, 1, 1), tick(0.03, 1, 0.7), hum(0.02, 0.2, 0.7, 0.4)]
    case .bossIntro: return [hum(0, 0.18, 0.4, 0.05, decay: false), tick(0.18, 1, 0.25), hum(0.18, 0.4, 0.8, 0.1)]
    case .bossHit: return [tick(0, 0.85, 0.55)]
    case .bossStagger: return [tick(0, 1, 0.8), tick(0.06, 0.8, 0.5), hum(0.03, 0.15, 0.5, 0.3)]
    case .bossPhase: return [tick(0, 1, 0.4), hum(0, 0.45, 0.85, 0.15), tick(0.22, 0.7, 0.3)]
    case .bossDown: return [tick(0, 1, 0.6), hum(0, 0.9, 1, 0.2), tick(0.25, 0.9, 0.5), tick(0.5, 0.8, 0.5), tick(0.75, 0.7, 0.6)]
    case .bossSlam: return [tick(0, 0.9, 0.2), hum(0, 0.18, 0.6, 0.05)]
    case .windup: return [hum(0, 0.35, 0.35, 0.1, decay: false), tick(0.35, 0.6, 0.6)]
    case .combo: return [tick(0, 0.7, 0.8), tick(0.07, 0.9, 0.9)]
    case .comboTop: return [tick(0, 0.7, 0.8), tick(0.07, 0.85, 0.9), tick(0.14, 1, 1)]
    case .win: return [tick(0, 0.6, 0.6), tick(0.1, 0.8, 0.7), tick(0.2, 1, 0.85), hum(0.2, 0.35, 0.5, 0.5)]
    case .lose: return [hum(0, 0.5, 0.8, 0.05)]
    case .power: return [tick(0, 0.6, 0.9), tick(0.06, 0.8, 1)]
    case .fever: return [tick(0, 0.8, 0.9), tick(0.08, 0.9, 0.9), tick(0.16, 1, 1), hum(0.16, 0.4, 0.6, 0.7)]
    case .overtime: return [tick(0, 0.7, 0.4), tick(0.14, 0.7, 0.4)]
    case .lastOne: return [tick(0, 0.5, 0.9)]
    case .villain: return [tick(0, 0.55, 0.1), tick(0.16, 0.7, 0.1)]
    case .villainHit: return [tick(0, 1, 0.5), hum(0, 0.3, 0.9, 0.3), tick(0.09, 0.9, 0.7)]
    case .doom: return [tick(0, 1, 0.2), hum(0, 0.9, 1, 0.05), tick(0.3, 0.9, 0.1), tick(0.6, 0.7, 0.1)]
    }
  }
}
