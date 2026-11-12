import AVFoundation
import UIKit

/// Short synthesised blips, with nothing bundled. Uses the ambient session, so the silent switch mutes it
/// and the player's own music keeps playing. Off by default: scripts and tests never turn it on.
@MainActor
final class Sound {
  static let shared = Sound()
  var enabled = false
  enum Wave { case sine, triangle, square, saw, noise }
  private let engine = AVAudioEngine()
  private var players: [AVAudioPlayerNode] = []
  private var nextPlayer = 0
  private var buffers: [String: AVAudioPCMBuffer] = [:]
  private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
  private var started = false
  /// A cheap fixed sequence for pitch variety, so no two pops in a row sound identical and the buffer
  /// cache stays small (each pitch is drawn once, then replayed).
  private static let jitter: [Double] = [1, 1.03, 0.97, 1.015, 0.985, 1.045, 0.96, 1.008]
  private var jitterIndex = 0

  private func start() {
    guard !started else { return }
    try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    for _ in 0..<14 {
      let p = AVAudioPlayerNode()
      engine.attach(p)
      engine.connect(p, to: engine.mainMixerNode, format: format)
      players.append(p)
    }
    engine.prepare()
    started = (try? engine.start()) != nil
    if started { players.forEach { $0.play() } }
  }

  func blip(_ freq: Double, _ duration: Double, _ wave: Wave = .triangle, gain: Float = 0.2, fall: Double = 0.5) {
    guard enabled else { return }
    start()
    guard started else { return }
    let key = "\(Int(freq))-\(Int(duration * 1000))-\(wave)-\(Int(gain * 100))-\(Int(fall * 10))"
    let buffer = buffers[key] ?? make(freq, duration, wave, gain, fall)
    if buffers.count > 600 { buffers.removeAll(keepingCapacity: true) }
    buffers[key] = buffer
    let p = players[nextPlayer]
    nextPlayer = (nextPlayer + 1) % players.count
    p.scheduleBuffer(buffer, at: nil, options: [.interrupts])
    if !p.isPlaying { p.play() }
  }

  /// The next step of the pitch wobble.
  private func vary(_ f: Double) -> Double {
    jitterIndex = (jitterIndex + 1) % Self.jitter.count
    return (f * Self.jitter[jitterIndex]).rounded()
  }

  /// The combo ladder: a major pentatonic run, so a rising combo always sounds like a tune and never a siren.
  static func ladder(_ combo: Double) -> Double {
    let steps = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31]
    let i = max(0, min(steps.count - 1, Int(((combo - 1) / 0.5).rounded())))
    return pow(2, Double(steps[i]) / 12)
  }

  /// A pop: a click of noise for the snap of the skin, then a falling tone that climbs with the combo.
  /// Bigger bubbles sit lower and add a body thump.
  func pop(size: Int, combo: Double) {
    guard enabled else { return }
    let base = [330.0, 440, 587, 784][max(0, min(3, size))]
    let f = vary(base * Self.ladder(combo))
    blip(4200, 0.018, .noise, gain: 0.07, fall: 0)
    blip(f, size >= 3 ? 0.08 : 0.1, .triangle, gain: 0.17)
    if size <= 1 { blip(vary(f / 2), 0.14, .sine, gain: 0.16) }
    if size == 0 { blip(70, 0.18, .sine, gain: 0.2, fall: 0.3) }
  }

  /// A whip crack: a hard noise burst, a bright edge and a low snap under it.
  func crack(big: Bool = false) {
    guard enabled else { return }
    blip(6000, 0.03, .noise, gain: 0.16, fall: 0)
    blip(vary(1900), 0.06, .square, gain: 0.07, fall: 0.8)
    blip(vary(big ? 120 : 170), big ? 0.3 : 0.2, .saw, gain: 0.16)
    if big { blip(2600, 0.12, .noise, gain: 0.06, fall: 0) }
  }

  /// A body blow: a low thump with grit on top, for shields and boss slams.
  func thump(_ freq: Double = 70, gain: Float = 0.24) {
    guard enabled else { return }
    blip(freq, 0.3, .sine, gain: gain, fall: 0.4)
    blip(900, 0.05, .noise, gain: 0.1, fall: 0)
  }

  /// A short rising arpeggio for good news, tuned to the combo ladder.
  func sting(_ notes: [Double], root: Double = 523, gap: Double = 0.06) {
    guard enabled else { return }
    for (i, n) in notes.enumerated() {
      let f = root * pow(2, n / 12)
      if i == 0 { blip(f, 0.14, .triangle, gain: 0.14) } else {
        Task { @MainActor [weak self] in
          try? await Task.sleep(for: .milliseconds(Int(Double(i) * gap * 1000)))
          self?.blip(f, 0.16, .triangle, gain: 0.13)
        }
      }
    }
  }

  private func make(_ freq: Double, _ duration: Double, _ wave: Wave, _ gain: Float, _ fall: Double) -> AVAudioPCMBuffer {
    let frames = AVAudioFrameCount(max(1, duration * format.sampleRate))
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    let data = buffer.floatChannelData![0]
    var phase = 0.0
    var seed: UInt32 = 0x9E37_79B9
    var held = 0.0
    for i in 0..<Int(frames) {
      let t = Double(i) / Double(frames)
      // The pitch falls (an octave by default) and the level fades, which reads as a pop instead of a beep.
      phase += freq * (1 - fall * t) / format.sampleRate
      let x = phase - floor(phase)
      let s: Double
      switch wave {
      case .sine: s = sin(2 * .pi * x)
      case .triangle: s = 4 * abs(x - 0.5) - 1
      case .square: s = x < 0.5 ? 1 : -1
      case .saw: s = 2 * x - 1
      case .noise:
        // Sample-and-hold noise: `freq` sets how bright it is.
        if x < freq / format.sampleRate || i == 0 {
          seed = seed &* 1_664_525 &+ 1_013_904_223
          held = Double(seed >> 8) / Double(1 << 24) * 2 - 1
        }
        s = held
      }
      // A 2 ms attack keeps the start from clicking; the tail is a squared fade.
      let attack = min(1, Double(i) / 88)
      data[i] = Float(s * attack) * gain * Float(pow(1 - t, 2))
    }
    return buffer
  }
}
