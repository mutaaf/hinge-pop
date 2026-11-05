import AVFoundation
import UIKit

/// Short synthesised blips, with nothing bundled. Uses the ambient session, so the silent switch mutes it
/// and the player's own music keeps playing.
@MainActor
final class Sound {
  static let shared = Sound()
  var enabled = false
  enum Wave { case sine, triangle, square, saw }
  private let engine = AVAudioEngine()
  private var players: [AVAudioPlayerNode] = []
  private var nextPlayer = 0
  private var buffers: [String: AVAudioPCMBuffer] = [:]
  private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
  private var started = false

  private func start() {
    guard !started else { return }
    try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    for _ in 0..<8 {
      let p = AVAudioPlayerNode()
      engine.attach(p)
      engine.connect(p, to: engine.mainMixerNode, format: format)
      players.append(p)
    }
    engine.prepare()
    started = (try? engine.start()) != nil
    if started { players.forEach { $0.play() } }
  }

  func blip(_ freq: Double, _ duration: Double, _ wave: Wave = .triangle, gain: Float = 0.2) {
    guard enabled else { return }
    start()
    guard started else { return }
    let key = "\(Int(freq))-\(Int(duration * 1000))-\(wave)-\(Int(gain * 100))"
    let buffer = buffers[key] ?? make(freq, duration, wave, gain)
    buffers[key] = buffer
    let p = players[nextPlayer]
    nextPlayer = (nextPlayer + 1) % players.count
    p.scheduleBuffer(buffer, at: nil, options: [.interrupts])
    if !p.isPlaying { p.play() }
  }

  private func make(_ freq: Double, _ duration: Double, _ wave: Wave, _ gain: Float) -> AVAudioPCMBuffer {
    let frames = AVAudioFrameCount(duration * format.sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    let data = buffer.floatChannelData![0]
    var phase = 0.0
    for i in 0..<Int(frames) {
      let t = Double(i) / Double(frames)
      // The pitch falls an octave and the level fades, which reads as a pop instead of a beep.
      phase += freq * (1 - 0.5 * t) / format.sampleRate
      let x = phase - floor(phase)
      let s: Double
      switch wave {
      case .sine: s = sin(2 * .pi * x)
      case .triangle: s = 4 * abs(x - 0.5) - 1
      case .square: s = x < 0.5 ? 1 : -1
      case .saw: s = 2 * x - 1
      }
      data[i] = Float(s) * gain * Float(pow(1 - t, 2))
    }
    return buffer
  }
}

@MainActor
final class Haptics {
  static let shared = Haptics()
  var enabled = false
  private let light = UIImpactFeedbackGenerator(style: .light)
  private let rigid = UIImpactFeedbackGenerator(style: .rigid)
  private let notify = UINotificationFeedbackGenerator()
  func tap() { if enabled { light.impactOccurred() } }
  func hit() { if enabled { rigid.impactOccurred() } }
  func good() { if enabled { notify.notificationOccurred(.success) } }
  func bad() { if enabled { notify.notificationOccurred(.error) } }
}
