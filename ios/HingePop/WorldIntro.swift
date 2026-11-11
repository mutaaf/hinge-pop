import SwiftUI
import HingePopArt
import HingePopCore

// MARK: - Words

extension Twist {
  var title: String {
    switch self {
    case .current: "Current"; case .wind: "Wind"; case .tide: "Tide"; case .fog: "Fog"
    case .ghost: "Ghosts"; case .wells: "Wells"; case .portals: "Portals"; case .bounce: "Springs"
    case .regrow: "Regrow"; case .triple: "Triple"; case .pulse: "Pulse"; case .blackout: "Lights out"
    }
  }
  /// A few words: what to watch for.
  var blurb: String {
    switch self {
    case .current: "Everything drifts along the line"
    case .wind: "Gusts shove bubbles across"
    case .tide: "The line rises and falls"
    case .fog: "Far bubbles hide. Wait till they're close"
    case .ghost: "Faded bubbles can't be hit, or cross"
    case .wells: "Wells swing bubbles round"
    case .portals: "Off one wall, out the other"
    case .bounce: "Every wall bounce speeds them up"
    case .regrow: "Leave a piece and it grows back"
    case .triple: "Every split makes three"
    case .pulse: "Pop on the beat for double"
    case .blackout: "Touch the dark to light it"
    }
  }
  /// The full rule, behind a tap.
  var detail: String {
    switch self {
    case .current: "A current carries every bubble along the hinge, then turns around every few seconds. Bosses are too heavy to care."
    case .wind: "Every few seconds a gust blows across the arena for a moment. Streaks gather just before it starts. Light pieces fly furthest; big ones barely move."
    case .tide: "The hinge slowly rises and falls. When it sweeps over a bubble, that counts as a crossing, so watch the bubbles the line is moving toward."
    case .fog: "Bubbles far from the line fade into fog, and you can't touch what you can't see. They come clear as they get close, so be ready near the line."
    case .ghost: "Now and then a bubble fades out of phase for a second. While it's faded you can't hit it, but it can't cross either: it glances off the line."
    case .wells: "Gravity wells pull nearby bubbles in and swing them round. Big bubbles feel it least. Pieces caught together make great chain pops."
    case .portals: "The two walls at the ends of the line are portals. A bubble that goes through one comes out of the other, a little faster."
    case .bounce: "The walls are springy. Each bounce adds speed, up to a limit, and it wears off slowly. Catch them before they've bounced a lot."
    case .regrow: "A small or tiny piece left alone slowly glows green and grows back one size. Medium pieces never grow back to big."
    case .triple: "Every split makes three pieces instead of two. A medium piece from a three-way split costs one less on the meter if it crosses."
    case .pulse: "The world beats on a rhythm and the line flashes on each beat. A pop on the beat scores double and adds an extra combo step. Bubbles surge a little on every beat."
    case .blackout: "Only the band along the line is lit. A bubble in the dark can't be touched until it's lit: touch near it and your light stays a moment. Swiping carries the light with you."
    }
  }
}

extension BossStyle {
  var title: String {
    switch self {
    case .crown: "The Crown"; case .twins: "The Twins"; case .shielded: "The Shield"
    case .splitter: "The Splitter"; case .blinker: "The Blinker"; case .summoner: "The Summoner"
    }
  }
  var blurb: String {
    switch self {
    case .crown: "Hit it when it glows red"
    case .twins: "Two bosses, one health bar"
    case .shielded: "Hit it from the open side"
    case .splitter: "Sheds a fast piece each phase"
    case .blinker: "Vanishes, then dashes from somewhere new"
    case .summoner: "Calls a wave at each phase"
    }
  }
}

// MARK: - Pictures

/// A twist, shown rather than told: a tiny looping scene with a real bubble and the line.
struct TwistPicture: View {
  let twist: Twist
  var arena: Arena = .classic
  @Environment(\.displayScale) private var scale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
      let t = reduceMotion ? 1.3 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
      Canvas { ctx, size in draw(&ctx, size: size, t: t) }
    }
    .accessibilityElement()
    .accessibilityLabel("\(twist.title): \(twist.blurb)")
  }

  private func bubble(_ ctx: inout GraphicsContext, _ kind: BubbleKind = .basic, at p: CGPoint, size: CGFloat, alpha: Double = 1) {
    let img = ctx.resolve(Image(decorative: Art.bubble(kind, size: 44, scale: scale), scale: scale))
    var c = ctx
    c.opacity = alpha
    c.translateBy(x: p.x, y: p.y)
    c.scaleBy(x: size / 44, y: size / 44)
    c.draw(img, at: .zero)
  }

  private func line(_ ctx: inout GraphicsContext, y: CGFloat, w: CGFloat, color: Color = .white, glow: Double = 1) {
    let rect = CGRect(x: 6, y: y - 1.5, width: w - 12, height: 3)
    ctx.drawLayer { l in
      l.addFilter(.shadow(color: Theme.cyan.opacity(0.9 * glow), radius: 8))
      l.fill(Capsule().path(in: rect), with: .color(color))
    }
  }

  private func draw(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
    let w = size.width, h = size.height, mid = h / 2
    let gold = Color(red: 1, green: 0.84, blue: 0.3)
    switch twist {
    case .current:
      for i in 0..<10 {
        let x = (CGFloat(i) * w / 10 + CGFloat(t * 40)).truncatingRemainder(dividingBy: w)
        ctx.fill(Capsule().path(in: CGRect(x: x, y: CGFloat(i % 2 == 0 ? 0.25 : 0.75) * h + CGFloat(i % 3) * 6, width: 14, height: 2)), with: .color(.white.opacity(0.35)))
      }
      line(&ctx, y: mid, w: w)
      let drift = CGFloat(sin(t * 0.9)) * w * 0.18
      bubble(&ctx, at: CGPoint(x: w * 0.35 + drift, y: mid - 26), size: 34)
      bubble(&ctx, at: CGPoint(x: w * 0.65 + drift, y: mid + 26), size: 26)
    case .wind:
      let phase = t.truncatingRemainder(dividingBy: 3) / 3
      let gust = phase > 0.4 ? sin((phase - 0.4) / 0.6 * .pi) : 0
      for i in 0..<9 {
        let x = w * (0.08 + 0.105 * CGFloat(i))
        let y0 = (CGFloat(i * 37) + CGFloat(t * 160)).truncatingRemainder(dividingBy: h)
        ctx.fill(Capsule().path(in: CGRect(x: x, y: y0, width: 2, height: 8 + 26 * gust)), with: .color(.white.opacity(0.15 + 0.55 * gust)))
      }
      line(&ctx, y: mid, w: w)
      bubble(&ctx, at: CGPoint(x: w * 0.3, y: h * 0.2 + CGFloat(gust) * 18), size: 22)
      bubble(&ctx, at: CGPoint(x: w * 0.66, y: h * 0.22 + CGFloat(gust) * 6), size: 40)
    case .tide:
      let reach = h * 0.18
      for y in [mid - reach, mid + reach] {
        ctx.stroke(Path { p in p.move(to: CGPoint(x: 10, y: y)); p.addLine(to: CGPoint(x: w - 10, y: y)) }, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5], dashPhase: CGFloat(t * 10)))
      }
      let y = mid + reach * CGFloat(sin(t * 1.3))
      line(&ctx, y: y, w: w)
      bubble(&ctx, at: CGPoint(x: w * 0.5, y: mid - reach - 22), size: 34)
      Image(systemName: "arrow.up.arrow.down").resolvedSymbol(&ctx, at: CGPoint(x: w * 0.85, y: y - 16), color: .white.opacity(0.8))
    case .fog:
      line(&ctx, y: mid, w: w)
      let u = (t * 0.45).truncatingRemainder(dividingBy: 1)
      let y = h * 0.08 + CGFloat(u) * (mid - 26 - h * 0.08)
      bubble(&ctx, at: CGPoint(x: w * 0.38, y: y), size: 32, alpha: min(1, max(0.05, Double(u) * 1.8 - 0.3)))
      bubble(&ctx, at: CGPoint(x: w * 0.68, y: h * 0.86), size: 28, alpha: 0.12)
      let fog = Gradient(colors: [Color(white: 0.85).opacity(0.75), .clear])
      ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: mid * 0.75)), with: .linearGradient(fog, startPoint: .zero, endPoint: CGPoint(x: 0, y: mid * 0.75)))
      ctx.fill(Path(CGRect(x: 0, y: h - mid * 0.75, width: w, height: mid * 0.75)), with: .linearGradient(fog, startPoint: CGPoint(x: 0, y: h), endPoint: CGPoint(x: 0, y: h - mid * 0.75)))
    case .ghost:
      line(&ctx, y: mid, w: w)
      let p = 0.5 + 0.5 * sin(t * 2.2)
      let x = w * 0.5 + CGFloat(sin(t * 0.7)) * w * 0.2
      bubble(&ctx, at: CGPoint(x: x, y: mid - 24), size: 36, alpha: 0.12 + 0.88 * p)
      if p < 0.5 {
        ctx.stroke(Circle().path(in: CGRect(x: x - 19, y: mid - 43, width: 38, height: 38)), with: .color(Theme.cyan.opacity(0.6 * (1 - p))), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
      }
      bubble(&ctx, at: CGPoint(x: w * 0.25, y: mid + 26), size: 24)
    case .wells:
      line(&ctx, y: h * 0.82, w: w)
      let c = CGPoint(x: w * 0.5, y: h * 0.4)
      for arm in 0..<3 {
        var path = Path()
        for k in 0..<24 {
          let r = 4 + CGFloat(k) * 1.8
          let a = Double(arm) * 2.094 + Double(k) * 0.22 - t * 2.2
          let p = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r * 0.8)
          if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        ctx.stroke(path, with: .color(Theme.violet.opacity(0.8)), lineWidth: 2.5)
      }
      ctx.fill(Circle().path(in: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10)), with: .color(.white))
      let a = t * 1.8
      bubble(&ctx, at: CGPoint(x: c.x + CGFloat(cos(a)) * 48, y: c.y + CGFloat(sin(a)) * 30), size: 24)
    case .portals:
      for x in [CGFloat(6), w - 6] {
        ctx.drawLayer { l in
          l.addFilter(.shadow(color: Theme.violet, radius: 8))
          l.fill(Capsule().path(in: CGRect(x: x - 3, y: 8, width: 6, height: h - 16)), with: .color(Theme.violet))
        }
      }
      line(&ctx, y: mid + 22, w: w)
      let x = (CGFloat(t * 70)).truncatingRemainder(dividingBy: w + 30) - 15
      bubble(&ctx, at: CGPoint(x: x, y: mid - 14), size: 32)
      if x > w - 18 { bubble(&ctx, at: CGPoint(x: x - w, y: mid - 14), size: 32) }
    case .bounce:
      line(&ctx, y: h * 0.85, w: w)
      let cycle = t.truncatingRemainder(dividingBy: 4)
      let speed = 1 + cycle * 0.5
      let pos = abs((cycle * speed * 0.5).truncatingRemainder(dividingBy: 2) - 1)
      let x = 20 + CGFloat(pos) * (w - 40)
      bubble(&ctx, at: CGPoint(x: x, y: mid - 8), size: 32)
      for wall in [CGFloat(4), w - 4] {
        let near = 1 - min(1, abs(x - wall) / 30)
        ctx.fill(Capsule().path(in: CGRect(x: wall - 2, y: 10, width: 4, height: h * 0.7)), with: .color(Color(red: 1, green: 0.45, blue: 0.78).opacity(0.3 + 0.7 * near)))
      }
    case .regrow:
      line(&ctx, y: mid + 30, w: w)
      let u = (t * 0.4).truncatingRemainder(dividingBy: 1)
      let s = 18 + CGFloat(u > 0.75 ? 1 : u / 0.75) * 14
      if u > 0.4 {
        ctx.fill(Circle().path(in: CGRect(x: w * 0.5 - s, y: mid - 8 - s, width: s * 2, height: s * 2)), with: .radialGradient(Gradient(colors: [Color.green.opacity(0.55 * (u - 0.4) / 0.6), .clear]), center: CGPoint(x: w * 0.5, y: mid - 8), startRadius: 0, endRadius: s))
      }
      bubble(&ctx, at: CGPoint(x: w * 0.5, y: mid - 8), size: s)
    case .triple:
      line(&ctx, y: h * 0.86, w: w)
      let u = (t * 0.5).truncatingRemainder(dividingBy: 1)
      let c = CGPoint(x: w * 0.5, y: h * 0.42)
      if u < 0.35 {
        bubble(&ctx, at: c, size: 40)
      } else {
        let k = CGFloat((u - 0.35) / 0.65)
        for a in [-2.2, -1.57, -0.94] {
          bubble(&ctx, at: CGPoint(x: c.x + CGFloat(cos(a)) * k * 50, y: c.y - CGFloat(sin(a)) * k * 22 + k * 14), size: 26)
        }
      }
    case .pulse:
      let beat = 0.9, ph = t.truncatingRemainder(dividingBy: beat) / beat
      for dir: CGFloat in [-1, 1] {
        let y = mid + dir * CGFloat(ph) * h * 0.45
        ctx.fill(Capsule().path(in: CGRect(x: 10, y: y - 1, width: w - 20, height: 2)), with: .color(gold.opacity(0.7 * (1 - ph))))
      }
      line(&ctx, y: mid, w: w, color: .white, glow: 1 + 2 * exp(-ph * 6))
      let s = 30 * (1 + 0.12 * CGFloat(exp(-ph * 6)))
      bubble(&ctx, .golden, at: CGPoint(x: w * 0.3, y: mid - 26), size: s)
      ctx.draw(Text("×2").font(.game(.headline, .black)).foregroundStyle(gold.opacity(ph < 0.3 ? 1 : 0.35)), at: CGPoint(x: w * 0.62, y: mid - 26))
    case .blackout:
      let finger = CGPoint(x: w * (0.5 + 0.32 * CGFloat(sin(t * 0.9))), y: h * 0.22)
      bubble(&ctx, at: CGPoint(x: w * 0.3, y: h * 0.22), size: 30)
      bubble(&ctx, at: CGPoint(x: w * 0.72, y: h * 0.24), size: 26)
      bubble(&ctx, at: CGPoint(x: w * 0.55, y: mid + 10), size: 24)
      ctx.drawLayer { l in
        l.fill(Path(CGRect(origin: .zero, size: CGSize(width: w, height: h))), with: .color(.black.opacity(0.86)))
        l.blendMode = .destinationOut
        l.fill(Path(CGRect(x: 0, y: mid - 18, width: w, height: 36)), with: .linearGradient(Gradient(colors: [.clear, .black, .black, .clear]), startPoint: CGPoint(x: 0, y: mid - 18), endPoint: CGPoint(x: 0, y: mid + 18)))
        l.fill(Circle().path(in: CGRect(x: finger.x - 30, y: finger.y - 30, width: 60, height: 60)), with: .radialGradient(Gradient(colors: [.black, .black, .clear]), center: finger, startRadius: 0, endRadius: 30))
      }
      line(&ctx, y: mid, w: w, glow: 0.7)
      Image(systemName: "hand.point.up.left.fill").resolvedSymbol(&ctx, at: CGPoint(x: finger.x + 10, y: finger.y + 18), color: .white.opacity(0.9))
    }
  }
}

private extension Image {
  func resolvedSymbol(_ ctx: inout GraphicsContext, at p: CGPoint, color: Color, size: CGFloat = 18) {
    var img = ctx.resolve(self)
    img.shading = GraphicsContext.Shading.color(color)
    ctx.draw(img, in: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size))
  }
}

// MARK: - The card

/// The first time you enter a world: its name, its realm, and its twist in a picture and a few words.
struct WorldIntroOverlay: View {
  let world: World
  let close: () -> Void
  @State private var more = false
  @State private var shown = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private var realm: Realm? { Worlds.realm(world.realm) }
  var body: some View {
    Centered {
      Sheet(maxWidth: 440) {
        VStack(alignment: .leading, spacing: 2) {
          Text("WORLD \(world.number) · \((realm?.name ?? "").uppercased())").font(.game(.caption, .heavy)).foregroundStyle(Theme.sun)
          Text(world.name).font(.game(.largeTitle, .black)).foregroundStyle(Theme.ink).minimumScaleFactor(0.7).lineLimit(2)
        }
        if world.twists.isEmpty {
          AuroraSpot(arena: world.biome) {
            Text(world.teaches).font(.game(.title3, .heavy)).foregroundStyle(.white).padding(16).frame(maxWidth: .infinity, alignment: .leading)
          }
        } else {
          ForEach(Array(world.twists.enumerated()), id: \.element) { i, twist in
            AuroraSpot(arena: world.biome) {
              VStack(alignment: .leading, spacing: 6) {
                TwistPicture(twist: twist, arena: world.biome).frame(height: world.twists.count > 1 ? 92 : 128)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Text(twist.title).font(.game(.title3, .black)).foregroundStyle(.white)
                  Text(twist.blurb).font(.game(.subheadline, .bold)).foregroundStyle(.white.opacity(0.92)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black.opacity(0.42)))
              }
              .padding(10)
            }
            .scaleEffect(shown || reduceMotion ? 1 : 0.9)
            .opacity(shown || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.35).delay(0.08 + Double(i) * 0.12), value: shown)
          }
        }
        if world.number > 1 {
          HStack(spacing: 10) {
            ArtImage(item: .bubble(.boss), size: 34)
            Text("\(world.boss.title): \(world.boss.blurb.lowercased())").font(.game(.subheadline, .bold)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
          }
          .accessibilityElement(children: .combine)
        }
        if !world.twists.isEmpty {
          Button(more ? "Less" : "More") { more.toggle() }.buttonStyle(.plain).font(.game(.subheadline, .bold)).foregroundStyle(Theme.cyan).frame(minHeight: Theme.target)
          if more {
            ForEach(world.twists, id: \.self) { Text($0.detail).font(.game(.subheadline, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
          }
        }
        Button("Let's go", action: close).buttonStyle(ChunkyStyle())
      }
    }
    .onAppear { shown = true }
  }
}

// MARK: - How to play

/// Every twist with its picture. Tap one for the whole rule.
struct TwistGuide: View {
  @State private var chosen: Twist?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    Text("Each world plays by one extra rule.").font(.game(.subheadline, .semibold)).foregroundStyle(Theme.muted)
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8, alignment: .top)], spacing: 8) {
      ForEach(Twist.allCases, id: \.self) { twist in
        let home = Worlds.all.first { $0.twists.first == twist }
        Button {
          withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { chosen = chosen == twist ? nil : twist }
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            AuroraSpot(arena: home?.biome ?? .classic, corner: 14) {
              TwistPicture(twist: twist, arena: home?.biome ?? .classic).frame(height: 76)
            }
            Text(twist.title).font(.game(.subheadline, .heavy)).foregroundStyle(Theme.ink)
            Text(twist.blurb).font(.game(.caption, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            if chosen == twist {
              Text(twist.detail).font(.game(.footnote, .medium)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            }
          }
          .frame(maxWidth: .infinity, minHeight: Theme.target, alignment: .leading)
          .padding(8)
          .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(chosen == twist ? Theme.cyan.opacity(0.14) : .white.opacity(0.04)))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the whole rule")
      }
    }
    Text("Bosses").font(.game(.subheadline, .heavy)).foregroundStyle(Theme.sun).padding(.top, 4)
    ForEach(BossStyle.allCases, id: \.self) { style in
      HStack(spacing: 10) {
        ArtImage(item: .bubble(.boss), size: 30)
        Text(style.title).font(.game(.subheadline, .heavy)).foregroundStyle(Theme.ink)
        Text(style.blurb).font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }
      .accessibilityElement(children: .combine)
    }
  }
}
