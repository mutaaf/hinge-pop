import SwiftUI
import HingePopArt
import HingePopCore
import simd

extension Arena {
  /// The curtain colours for each arena.
  var aurora: [Color] {
    switch self {
    case .classic: [Color(red: 0.2, green: 0.85, blue: 1), Color(red: 0.4, green: 0.45, blue: 1), Color(red: 0.25, green: 1, blue: 0.75)]
    case .neon: [Color(red: 0.9, green: 0.3, blue: 1), Color(red: 0.35, green: 0.5, blue: 1), Color(red: 1, green: 0.35, blue: 0.7)]
    case .forest: [Color(red: 0.3, green: 1, blue: 0.55), Color(red: 0.2, green: 0.85, blue: 0.8), Color(red: 0.75, green: 1, blue: 0.35)]
    case .space: [Color(red: 0.55, green: 0.35, blue: 1), Color(red: 0.2, green: 0.7, blue: 1), Color(red: 1, green: 0.45, blue: 0.75)]
    case .frost: [Color(red: 0.2, green: 0.95, blue: 0.72), Color(red: 0.3, green: 0.78, blue: 1), Color(red: 0.6, green: 0.5, blue: 1)]
    case .reef: [Color(red: 0.2, green: 0.9, blue: 0.9), Color(red: 1, green: 0.45, blue: 0.62), Color(red: 0.4, green: 1, blue: 0.7)]
    case .magma: [Color(red: 1, green: 0.42, blue: 0.15), Color(red: 1, green: 0.75, blue: 0.3), Color(red: 1, green: 0.3, blue: 0.5)]
    case .candy: [Color(red: 1, green: 0.5, blue: 0.8), Color(red: 0.6, green: 0.85, blue: 1), Color(red: 1, green: 0.85, blue: 0.4)]
    case .dunes: [Color(red: 1, green: 0.7, blue: 0.35), Color(red: 1, green: 0.45, blue: 0.3), Color(red: 0.5, green: 0.7, blue: 1)]
    case .storm: [Color(red: 0.45, green: 0.65, blue: 1), Color(red: 0.85, green: 0.9, blue: 1), Color(red: 0.6, green: 0.4, blue: 1)]
    case .crystal: [Color(red: 0.4, green: 1, blue: 0.95), Color(red: 0.75, green: 0.5, blue: 1), Color(red: 0.4, green: 0.6, blue: 1)]
    case .haunted: [Color(red: 0.55, green: 1, blue: 0.5), Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 1, green: 0.55, blue: 0.2)]
    case .circuit: [Color(red: 0.1, green: 1, blue: 0.9), Color(red: 1, green: 0.2, blue: 0.75), Color(red: 0.4, green: 0.5, blue: 1)]
    case .jungle: [Color(red: 0.4, green: 1, blue: 0.4), Color(red: 1, green: 0.8, blue: 0.3), Color(red: 0.2, green: 0.8, blue: 0.6)]
    case .clouds: [Color(red: 1, green: 0.75, blue: 0.85), Color(red: 0.6, green: 0.85, blue: 1), Color(red: 1, green: 0.95, blue: 0.6)]
    case .clockwork: [Color(red: 1, green: 0.7, blue: 0.35), Color(red: 0.6, green: 0.85, blue: 0.8), Color(red: 0.85, green: 0.55, blue: 0.3)]
    }
  }
}

extension Arena {
  /// The same curtain colours, as numbers for the in-game sky shader.
  var skyColors: [vector_float3] {
    switch self {
    case .classic: [.init(0.2, 0.85, 1), .init(0.4, 0.45, 1), .init(0.25, 1, 0.75)]
    case .neon: [.init(0.9, 0.3, 1), .init(0.35, 0.5, 1), .init(1, 0.35, 0.7)]
    case .forest: [.init(0.3, 1, 0.55), .init(0.2, 0.85, 0.8), .init(0.75, 1, 0.35)]
    case .space: [.init(0.55, 0.35, 1), .init(0.2, 0.7, 1), .init(1, 0.45, 0.75)]
    case .frost: [.init(0.2, 0.95, 0.72), .init(0.3, 0.78, 1), .init(0.6, 0.5, 1)]
    case .reef: [.init(0.2, 0.9, 0.9), .init(1, 0.45, 0.62), .init(0.4, 1, 0.7)]
    case .magma: [.init(1, 0.42, 0.15), .init(1, 0.75, 0.3), .init(1, 0.3, 0.5)]
    case .candy: [.init(1, 0.5, 0.8), .init(0.6, 0.85, 1), .init(1, 0.85, 0.4)]
    case .dunes: [.init(1, 0.7, 0.35), .init(1, 0.45, 0.3), .init(0.5, 0.7, 1)]
    case .storm: [.init(0.45, 0.65, 1), .init(0.85, 0.9, 1), .init(0.6, 0.4, 1)]
    case .crystal: [.init(0.4, 1, 0.95), .init(0.75, 0.5, 1), .init(0.4, 0.6, 1)]
    case .haunted: [.init(0.55, 1, 0.5), .init(0.6, 0.3, 0.9), .init(1, 0.55, 0.2)]
    case .circuit: [.init(0.1, 1, 0.9), .init(1, 0.2, 0.75), .init(0.4, 0.5, 1)]
    case .jungle: [.init(0.4, 1, 0.4), .init(1, 0.8, 0.3), .init(0.2, 0.8, 0.6)]
    case .clouds: [.init(1, 0.75, 0.85), .init(0.6, 0.85, 1), .init(1, 0.95, 0.6)]
    case .clockwork: [.init(1, 0.7, 0.35), .init(0.6, 0.85, 0.8), .init(0.85, 0.55, 0.3)]
    }
  }
}

/// A bright curtain behind the one thing a screen wants you to look at, with a soft scrim for text.
struct AuroraSpot<Content: View>: View {
  var arena: Arena = .classic
  var corner: CGFloat = 22
  @ViewBuilder var content: Content
  var body: some View {
    content
      .background {
        ZStack {
          Theme.panel
          AuroraField(arena: arena, strength: 1.2, alwaysOn: true, soft: 0.85)
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
      }
      .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
  }
}

/// A section that folds away. Only one is open at a time, wherever the state lives.
struct Fold<Content: View>: View {
  let title: String
  var note: String? = nil
  let id: String
  @Binding var open: String?
  var arena: Arena = .classic
  @ViewBuilder var content: Content
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private var isOpen: Bool { open == id }
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.26)) { open = isOpen ? nil : id }
      } label: {
        HStack(spacing: 10) {
          Text(title).font(.game(.headline, .heavy)).foregroundStyle(Theme.ink)
          if let note { Text(note).font(.game(.footnote, .semibold)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8) }
          Spacer(minLength: 4)
          Image(systemName: "chevron.down")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(isOpen ? Theme.sun : Theme.muted)
            .rotationEffect(.degrees(isOpen ? 180 : 0))
        }
        .frame(minHeight: Theme.target)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(isOpen ? [.isSelected] : [])
      .accessibilityHint(isOpen ? "Collapses this section" : "Expands this section")
      if isOpen {
        VStack(alignment: .leading, spacing: 8) { content }
          .padding(.horizontal, 16)
          .padding(.bottom, 16)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel.opacity(isOpen ? 0.96 : 0.82)))
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isOpen ? Theme.cyan.opacity(0.7) : Theme.panelEdge, lineWidth: isOpen ? 1.5 : 1))
    .id(id) // so a screen can scroll a section into view
  }
}

/// The aurora behind every screen: one full-screen Metal layer at no more than 30 fps. It pauses off
/// screen, in the background and in Low Power Mode, and shows a still frame under Reduce Motion. Menus
/// let it rest after a few seconds, while gameplay keeps it moving.
struct AuroraField: View {
  var arena: Arena
  var heat: Double = 0
  var strength: Double = 0.42
  var alwaysOn = false
  /// 0 keeps fine rays, 1 is a smooth glow, for small cards where rays read as stripes.
  var soft = 0.0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var phase
  @State private var visible = false
  @State private var resting = false
  @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

  var body: some View {
    let calm = reduceMotion || lowPower || phase != .active || !visible || (resting && !alwaysOn)
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: calm)) { ctx in
      let t = Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000))
      GeometryReader { geo in
        let c = arena.aurora
        Rectangle()
          .colorEffect(ShaderLibrary.auroraLight(.float2(geo.size), .float(t), .color(c[0]), .color(c[1]), .color(c[2]), .float(Float(strength)), .float(Float(heat)), .float(Float(soft))))
      }
    }
    .blendMode(.plusLighter)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .ignoresSafeArea()
    .task(id: "\(visible)|\(phase == .active)") {
      resting = false
      guard visible, phase == .active, !alwaysOn else { return }
      try? await Task.sleep(for: .seconds(8))
      if !Task.isCancelled { resting = true }
    }
    .onAppear { visible = true }
    .onDisappear { visible = false }
    .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
      lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
  }
}

/// Particles sampled from a piece of art. Each one is its own damped spring with its own stiffness, so the
/// field swirls into the shape instead of easing into it, the way the aurora-field library does. The crisp
/// art then fades up through the settled particles, which keep breathing around it as a halo.
struct AuroraAssemble: View {
  let item: ArtImage.Item
  let size: CGFloat
  var count = 900
  var delay = 0.0
  @Environment(\.displayScale) private var scale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var cloud: ParticleCloud?
  @State private var start = Date()

  var body: some View {
    let box = artSize
    ZStack {
      if reduceMotion {
        ArtImage(item: item, size: size)
      } else {
        TimelineView(.animation) { ctx in
          let t = ctx.date.timeIntervalSince(start) - delay
          ZStack {
            Canvas { g, canvas in cloud?.draw(in: &g, canvas: canvas, time: max(0, t)) }
              .frame(width: box.width * 1.5, height: box.height * 1.5)
              .allowsHitTesting(false)
            ArtImage(item: item, size: size)
              .opacity(min(1, max(0, (t - 0.85) / 0.45)))
              .scaleEffect(0.97 + 0.03 * min(1, max(0, (t - 0.85) / 0.45)))
          }
        }
      }
    }
    .frame(width: box.width, height: box.height)
    .task {
      start = Date()
      guard !reduceMotion, cloud == nil else { return }
      let source = cgImage
      let want = count
      cloud = await Task.detached(priority: .userInitiated) { ParticleCloud(image: source, count: want) }.value
    }
  }

  private var cgImage: CGImage {
    switch item {
    case .bubble(let k): Art.bubble(k, size: size, scale: 1)
    case .cameo(let k): Art.cameo(k, size: size, scale: 1)
    case .power(let k): Art.power(k, size: size, scale: 1)
    case .glyph(let g): Art.glyph(g, size: size, scale: 1)
    case .logo: Art.logo(width: size, scale: 1)
    }
  }
  private var artSize: CGSize {
    let img = cgImage
    return CGSize(width: img.width, height: img.height)
  }
}

/// The sampled points, plus a closed-form damped spring, so a frame costs no simulation state.
final class ParticleCloud: @unchecked Sendable {
  private struct Dot {
    var x, y: Float        // home, relative to the centre
    var sx, sy: Float      // where it starts
    var k: Float           // its own spring rate
    var phase: Float
    var size: Float
    var bucket: Int
  }
  private var dots: [Dot] = []
  private var colors: [Color] = []
  let width: Float
  let height: Float

  init(image: CGImage, count: Int) {
    let w = image.width, h = image.height
    width = Float(w); height = Float(h)
    var data = [UInt8](repeating: 0, count: w * h * 4)
    let made = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    made?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var rng = SplitMix(seed: UInt64(w * 31 + h))
    var buckets: [Int: Int] = [:]
    var tries = 0
    while dots.count < count, tries < count * 40 {
      tries += 1
      let px = rng.int(w), py = rng.int(h), i = (py * w + px) * 4
      guard data[i + 3] > 110 else { continue }
      let a = Double(data[i + 3]) / 255
      // Colours are quantised, so all the dots of one colour can be filled in a single draw.
      let qr = Int(Double(data[i]) / a) >> 5, qg = Int(Double(data[i + 1]) / a) >> 5, qb = Int(Double(data[i + 2]) / a) >> 5
      let key = (min(7, qr) << 6) | (min(7, qg) << 3) | min(7, qb)
      let bucket: Int
      if let b = buckets[key] { bucket = b } else {
        bucket = colors.count
        buckets[key] = bucket
        colors.append(Color(red: Double(min(7, qr)) / 7, green: Double(min(7, qg)) / 7, blue: Double(min(7, qb)) / 7))
      }
      let spin = Float(rng.unit()) * 6.283, reach = Float(max(w, h)) * (0.5 + Float(rng.unit()) * 0.45)
      dots.append(Dot(x: Float(px) - Float(w) / 2, y: Float(py) - Float(h) / 2, sx: cos(spin) * reach, sy: sin(spin) * reach,
                      k: 4.5 + Float(rng.unit()) * 5.5, phase: Float(rng.unit()) * 6.283, size: 1 + Float(rng.unit()) * 1.6, bucket: bucket))
    }
  }

  func draw(in g: inout GraphicsContext, canvas: CGSize, time: Double) {
    let t = Float(time)
    let cx = Float(canvas.width) / 2, cy = Float(canvas.height) / 2
    var paths = [Path](repeating: Path(), count: colors.count)
    // Particles fade back to a light halo once the crisp art is up.
    let settle = min(1, max(0, (t - 1) / 0.6))
    for d in dots {
      // Underdamped spring: overshoots once or twice, then settles, with a swirl that dies away.
      let fall = exp(-d.k * 0.72 * t) * cos(d.k * 1.25 * t)
      let swirl = exp(-d.k * 0.5 * t) * 1.4
      let dx = d.sx * fall, dy = d.sy * fall
      let breathe = settle * 1.6 * sin(t * 1.3 + d.phase)
      let x = cx + d.x + dx * cos(swirl) - dy * sin(swirl) + breathe
      let y = cy + d.y + dx * sin(swirl) + dy * cos(swirl) + breathe * 0.6
      let s = CGFloat(d.size)
      paths[d.bucket].addEllipse(in: CGRect(x: CGFloat(x) - s / 2, y: CGFloat(y) - s / 2, width: s, height: s))
    }
    g.blendMode = .plusLighter
    g.opacity = Double(1 - settle * 0.72)
    for (i, path) in paths.enumerated() { g.fill(path, with: .color(colors[i])) }
  }
}
