import SwiftUI
import HingePopArt
import HingePopCore
import simd

extension Arena {
  /// The curtain colours for each biome and variant (0 is the original take; 1-3 follow the art's time of
  /// day and weather in HingePopArt). Three colours per take: the upper curtain, the lower one and the glow.
  /// Tuned against the art so the curtains tint the scene without outshining the bubbles.
  private var curtainHex: [[UInt32]] {
    switch self {
    case .classic: [[0x33D9FF, 0x6673FF, 0x40FFBF], [0xFF7AB0, 0x8A6CFF, 0xFFB070], [0x30E0C8, 0x2A90FF, 0x7AFFD0], [0xA8C8FF, 0x7A6CFF, 0xE0E8FF]]
    case .neon: [[0xE64DFF, 0x5980FF, 0xFF59B3], [0xFF8A40, 0xFF4FA0, 0xFFD060], [0x6A7AFF, 0xB05AFF, 0x50C8FF], [0x40F0FF, 0x8AA8FF, 0xC8F8FF]]
    case .forest: [[0x4DFF8C, 0x33D9CC, 0xBFFF59], [0xFFC050, 0x9AF060, 0xFF8A50], [0x5A8AFF, 0x7AF0C0, 0xA08AFF], [0x8AC8C0, 0x6AA0B0, 0xB8F0D0]]
    case .space: [[0x8C59FF, 0x33B3FF, 0xFF73BF], [0xFF8AD0, 0xFFB0E0, 0xB07AFF], [0x30E0C0, 0x3AA0FF, 0x8AFFD8], [0xFF6A3A, 0xFFB050, 0xFF4A7A]]
    case .frost: [[0x33F2B8, 0x4DC7FF, 0x9980FF], [0xE08AFF, 0xFF9AD0, 0x8AA8FF], [0xD8F0FF, 0x9AC0E0, 0xB8E0FF], [0xFFD080, 0x80F0C0, 0xFFA070]]
    case .reef: [[0x33E6E6, 0xFF739E, 0x66FFB3], [0x5AFFD8, 0xFFE07A, 0x7AF0FF], [0x3A8AFF, 0x5AE0FF, 0x8AA0FF], [0x30FFE0, 0x6A5AFF, 0x30C8FF]]
    case .magma: [[0xFF6B26, 0xFFBF4D, 0xFF4D80], [0xFFD040, 0xFFE890, 0xFF9A30], [0xC87A60, 0xFF6A40, 0xA08070], [0x4A9AFF, 0x8AE0FF, 0x7A6AFF]]
    case .candy: [[0xFF80CC, 0xFFD966, 0xB08AFF], [0xFFA060, 0xFF6A9A, 0xFFE080], [0xA090FF, 0xFF9AE0, 0x80E0FF], [0xFF5AD0, 0x9A6AFF, 0xFFB0E8]]
    case .dunes: [[0xFFB359, 0xFF734D, 0xFFD890], [0xFF7A40, 0xE04A8A, 0xFFC070], [0x5AD0E0, 0x6A8AFF, 0xC8E0FF], [0xFFB060, 0xD08A50, 0xFFD8A0]]
    case .storm: [[0x73A6FF, 0xD9E6FF, 0x9966FF], [0xE07AFF, 0xFFB8F0, 0x8A5AFF], [0xB8F0FF, 0x8AC8D0, 0xE8F8FF], [0xFFB060, 0xFF6A4A, 0xFFD890]]
    case .crystal: [[0x66FFF2, 0xBF80FF, 0x6699FF], [0xFFA040, 0xFF7A50, 0xFFD070], [0x5AF0B0, 0x80E0FF, 0xC0FF90], [0x7A9AFF, 0xFFE08A, 0xC08AFF]]
    case .haunted: [[0x8CFF80, 0x994DE6, 0xFF8C33], [0xFFA040, 0xC06AA0, 0xFFD080], [0xFF5A6A, 0xA03AC0, 0xFF9A8A], [0x9AC8FF, 0x6A80C0, 0xC8FFD8]]
    case .circuit: [[0x1AFFE6, 0xFF33BF, 0x6680FF], [0xFFE04A, 0xB05AFF, 0xFF7AD0], [0x5AFF9A, 0x3AE8C0, 0xA0FF5A], [0xFF3A3A, 0x5AA0FF, 0xFF8A5A]]
    case .jungle: [[0x66FF66, 0xFFCC4D, 0x33CC99], [0xFFC040, 0xFFE0A0, 0xA0D040], [0x8AE8D0, 0x6AA0B0, 0xC8F0E0], [0xE0FF6A, 0x5AA0FF, 0x7AFFC0]]
    case .clouds: [[0xFFBFD9, 0xFFF299, 0xB0A0FF], [0xFFC050, 0xFF8AA0, 0xFFE0A0], [0xFFE08A, 0x8AA0FF, 0xC8D8FF], [0xC0B0FF, 0xE0E0FF, 0x9A9AD0]]
    case .clockwork: [[0xFFB359, 0x99D9CC, 0xD98C4D], [0xE0A060, 0x7AE0D0, 0xFFE0B0], [0x7AE0FF, 0xC08AFF, 0xFF9AE0], [0xFFC060, 0x6A8AFF, 0xD0E0FF]]
    }
  }

  func curtain(_ variant: Int) -> [UInt32] {
    let all = curtainHex
    return all[((variant % all.count) + all.count) % all.count]
  }

  /// The curtain colours for the original take.
  var aurora: [Color] { aurora(variant: 0) }

  func aurora(variant: Int) -> [Color] {
    curtain(variant).map { Color(red: Double(($0 >> 16) & 255) / 255, green: Double(($0 >> 8) & 255) / 255, blue: Double($0 & 255) / 255) }
  }

  /// The same curtain colours, as numbers for the in-game sky shader.
  var skyColors: [vector_float3] { skyColors(variant: 0) }

  func skyColors(variant: Int) -> [vector_float3] {
    curtain(variant).map { vector_float3(Float(($0 >> 16) & 255) / 255, Float(($0 >> 8) & 255) / 255, Float($0 & 255) / 255) }
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
  var variant = 0
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
        let c = arena.aurora(variant: variant)
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
