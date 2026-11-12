import SwiftUI
import HingePopArt
import HingePopCore

// The journey: 800 levels as one winding path, realm by realm, over each world's own backdrop.
// Every level is its own lazy row, so only what's on screen is built, and scrolling to a level is exact.

/// One row of the journey, top to bottom: a realm's title card, then each world's banner and its ten levels.
enum JourneyRow: Hashable {
  case realm(Int), world(Int), level(Int), infinity
  var id: String {
    switch self {
    case .realm(let n): "realm-\(n)"
    case .world(let n): "world-\(n)"
    case .level(let n): "level-\(n)"
    case .infinity: "infinity"
    }
  }
}

enum Journey {
  static let rows: [JourneyRow] = {
    var out: [JourneyRow] = []
    for r in Worlds.realms {
      out.append(.realm(r.number))
      for w in r.worlds {
        out.append(.world(w))
        for l in Worlds.all[w - 1].levels { out.append(.level(l)) }
      }
    }
    out.append(.infinity)
    return out
  }()
  /// Each row's place along the path. The path's swing is a function of it, so rows join up seamlessly.
  static let slot: [JourneyRow: Int] = Dictionary(uniqueKeysWithValues: rows.enumerated().map { ($1, $0) })

  /// The path's sideways swing at a point along it, -1...1.
  static func swing(_ t: Double) -> Double { sin(t * 0.74) * 0.94 }

  static func firstLevel(ofRealm r: Int) -> Int { (r - 1) * 80 + 1 }
  static func levels(ofRealm r: Int) -> ClosedRange<Int> { firstLevel(ofRealm: r)...(r * 80) }

  static func twistIcon(_ t: Twist) -> String {
    switch t {
    case .current: "water.waves"
    case .wind: "wind"
    case .tide: "arrow.up.arrow.down"
    case .fog: "cloud.fog.fill"
    case .ghost: "eye.slash.fill"
    case .wells: "hurricane"
    case .portals: "arrow.left.arrow.right"
    case .bounce: "arrow.up.right.and.arrow.down.left"
    case .regrow: "leaf.fill"
    case .triple: "circle.grid.2x1.fill"
    case .pulse: "metronome.fill"
    case .blackout: "moon.fill"
    }
  }
  static func twistName(_ t: Twist) -> String {
    switch t {
    case .current: "Current"; case .wind: "Gusts"; case .tide: "Tide"; case .fog: "Fog"
    case .ghost: "Phasing"; case .wells: "Wells"; case .portals: "Portals"; case .bounce: "Springs"
    case .regrow: "Regrow"; case .triple: "Triple split"; case .pulse: "Beat"; case .blackout: "Lights out"
    }
  }
  static func bossIcon(_ b: BossStyle) -> String {
    switch b {
    case .crown: "crown.fill"; case .twins: "person.2.fill"; case .shielded: "shield.lefthalf.filled"
    case .splitter: "scissors"; case .blinker: "sparkles"; case .summoner: "wand.and.stars"
    }
  }
  static func bossName(_ b: BossStyle) -> String {
    switch b {
    case .crown: "Crown boss"; case .twins: "Twin bosses"; case .shielded: "Shielded boss"
    case .splitter: "Splitter boss"; case .blinker: "Blinker boss"; case .summoner: "Summoner boss"
    }
  }
}

extension Arena {
  /// A backdrop's name in the picker.
  var backdropName: String {
    switch self {
    case .classic: "Classic"; case .neon: "Neon"; case .forest: "Forest"; case .space: "Space"
    case .frost: "Frost"; case .reef: "Reef"; case .magma: "Magma"; case .candy: "Candy"
    case .dunes: "Dunes"; case .storm: "Storm"; case .crystal: "Crystal"; case .haunted: "Haunted"
    case .circuit: "Circuit"; case .jungle: "Jungle"; case .clouds: "Clouds"; case .clockwork: "Clockwork"
    }
  }
}

/// Backdrop art for the journey and the pickers. Rendered once per size by the art library's cache, at a light
/// scale: it sits under a scrim, and 80 worlds share 16 biomes.
enum Backdrop {
  static func image(_ biome: Arena, variant: Int, size: CGSize, scale: CGFloat = 1) -> CGImage? {
    guard let kind = ArenaKind(rawValue: biome.rawValue), size.width >= 1, size.height >= 1 else { return nil }
    let s = CGSize(width: size.width.rounded(), height: size.height.rounded())
    return Art.arena(kind, variant: variant, size: s, scale: scale)
  }
  /// Renders the backdrops off the main thread, nearest first, so scrolling never waits on art.
  static func prewarm(_ biomes: [(Arena, Int)], size: CGSize) async {
    await Task.detached(priority: .utility) {
      for (b, v) in biomes { _ = image(b, variant: v, size: size) }
    }.value
  }
}

/// A biome's backdrop, or a gradient in its colours while its art isn't there yet.
struct BackdropFill: View {
  let biome: Arena
  var variant = 0
  let size: CGSize
  /// Shows one horizontal band of a taller image: its top edge, in points.
  var band: CGFloat = 0
  /// How tall a window onto it to show; the whole image when nil.
  var visible: CGFloat? = nil
  var scale: CGFloat = 1
  var body: some View {
    ZStack(alignment: .top) {
      if let img = Backdrop.image(biome, variant: variant, size: size, scale: scale) {
        Image(decorative: img, scale: scale).resizable().frame(width: size.width, height: size.height)
          .offset(y: -band)
      } else {
        let c = biome.aurora
        ZStack {
          LinearGradient(colors: [c[1].opacity(0.5), Theme.night, c[0].opacity(0.35), Theme.night, c[2].opacity(0.3)], startPoint: .top, endPoint: .bottom)
          // Soft hills of the biome's colours, so a world without its art yet still feels like a place.
          ForEach(0..<5, id: \.self) { i in
            RadialGradient(colors: [c[i % 3].opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: size.width * 0.5)
              .frame(width: size.width * 1.2, height: size.width * 1.2)
              .scaleEffect(x: 1, y: 0.45)
              .position(x: size.width * (i % 2 == 0 ? 0.2 : 0.85), y: size.height * (0.12 + Double(i) * 0.2))
          }
        }
        .frame(width: size.width, height: size.height)
        .offset(y: -band)
      }
    }
    .frame(width: size.width, height: visible ?? size.height, alignment: .top)
    .clipped()
    .accessibilityHidden(true)
  }
}

// MARK: - The journey screen

struct JourneyView: View {
  @Environment(AppModel.self) private var app
  @Environment(DuoModel.self) private var duo
  @State private var showRealms = false
  /// A row to bring to the middle of the screen, and whether to glide there.
  @State private var jump: (id: String, animated: Bool)? = nil
  @State private var jumpCount = 0
  @ScaledMetric(relativeTo: .headline) private var rowScaled: CGFloat = 96

  var body: some View {
    GeometryReader { proxy in
      let fold = foldRect(proxy, duo: duo)
      ZStack {
        Theme.night.ignoresSafeArea()
        if let fold, fold.height >= fold.width, proxy.size.width > 560 {
          // A book: the realms on the leading page, the path on the trailing one, the fold between.
          HStack(spacing: 0) {
            VStack(spacing: 0) {
              topBar(realmsButton: false)
              RealmOverview(columns: 1) { go(to: $0) }
            }
            .frame(width: fold.minX)
            Color.black.frame(width: fold.width).ignoresSafeArea()
            path.frame(maxWidth: .infinity)
          }
        } else if let fold, fold.width > fold.height {
          // Tabletop: the path above the fold, the realms below it.
          VStack(spacing: 0) {
            VStack(spacing: 0) { topBar(realmsButton: false); path }.frame(height: fold.minY)
            Color.black.frame(height: fold.height)
            RealmOverview(columns: 2, compact: true) { go(to: $0) }
          }
        } else if proxy.size.width >= 900 {
          // Wide screens keep the realms beside the path.
          HStack(spacing: 0) {
            VStack(spacing: 0) {
              topBar(realmsButton: false)
              RealmOverview(columns: 1) { go(to: $0) }
            }
            .frame(width: 340)
            .background(Theme.night)
            Rectangle().fill(Theme.panelEdge.opacity(0.5)).frame(width: 1).ignoresSafeArea()
            path
          }
        } else {
          VStack(spacing: 0) {
            topBar(realmsButton: true)
            path
          }
          if showRealms {
            RealmSheet { go(to: $0) } close: { withAnimation(.snappy(duration: 0.28)) { showRealms = false } }
              .transition(.move(edge: .bottom).combined(with: .opacity))
              .zIndex(2)
          }
        }
      }
    }
    #if DEBUG
    .task {
      if Debug.has("-realms") { showRealms = true }
      if let r = Debug.int("-realm") { go(to: r) }
      try? await Task.sleep(for: .milliseconds(300))
      Debug.ready("root")
    }
    #endif
  }

  private var rowHeight: CGFloat { min(150, max(84, rowScaled)) }

  /// Jumps to a realm: to where you are in it, or its title card.
  private func go(to realm: Int) {
    let p = app.progress
    let here = p.nextUp
    let id: String
    if Journey.levels(ofRealm: realm).contains(here) { id = JourneyRow.level(here).id }
    else if p.unlocked >= Journey.firstLevel(ofRealm: realm) && p.realmOpen(realm) {
      // A realm you've finished: its first level that still has stars to win.
      let spare = Journey.levels(ofRealm: realm).first { (p.stars[$0] ?? 0) < 3 && p.isOpen($0) }
      id = spare.map { JourneyRow.level($0).id } ?? JourneyRow.realm(realm).id
    } else { id = JourneyRow.realm(realm).id }
    withAnimation(.snappy(duration: 0.28)) { showRealms = false }
    jump = (id, false)
    jumpCount += 1
  }

  private func topBar(realmsButton: Bool) -> some View {
    HStack(spacing: 10) {
      Button { app.route = .home } label: {
        Image(systemName: "chevron.left").font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
          .frame(width: Theme.target, height: Theme.target)
          .background(Circle().fill(Theme.panel)).overlay(Circle().stroke(Theme.panelEdge))
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Back")
      Text("Journey").font(.game(.title2, .black)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: 4)
      HStack(spacing: 4) {
        ArtImage(item: .glyph(.starOn), size: 20)
        Text("\(app.progress.totalStars)").font(.game(.headline, .heavy)).monospacedDigit().foregroundStyle(Theme.sun)
      }
      .padding(.horizontal, 12).frame(minHeight: 40)
      .background(Capsule().fill(Theme.panel.opacity(0.9))).overlay(Capsule().stroke(Theme.sun.opacity(0.5)))
      .accessibilityElement().accessibilityLabel("\(app.progress.totalStars) stars")
      OverdriveFlip()
      if realmsButton {
        Button { withAnimation(.snappy(duration: 0.3)) { showRealms = true } } label: {
          Image(systemName: "square.grid.2x2.fill").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            .frame(width: Theme.target, height: Theme.target)
            .background(Circle().fill(Theme.panel)).overlay(Circle().stroke(Theme.panelEdge))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("All realms")
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
    .background(LinearGradient(colors: [Theme.night, Theme.night.opacity(0.0)], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
  }

  private var path: some View {
    GeometryReader { geo in
      let width = geo.size.width
      ScrollViewReader { reader in
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(Journey.rows, id: \.self) { row in
              JourneyRowView(row: row, width: width, rowHeight: rowHeight) { jumpTo in
                jump = (jumpTo, true); jumpCount += 1
              }
              .id(row.id)
            }
          }
          .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottomTrailing) {
          Button {
            jump = (JourneyRow.level(app.progress.nextUp).id, true); jumpCount += 1
          } label: {
            Image(systemName: "location.fill").font(.title3.weight(.heavy)).foregroundStyle(Color(red: 0.2, green: 0.08, blue: 0.1))
              .frame(width: 56, height: 56)
              .background(Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0.3), Theme.orange], startPoint: .top, endPoint: .bottom)))
              .overlay(Circle().stroke(.black.opacity(0.25)))
              .shadow(color: Theme.sun.opacity(0.5), radius: 12)
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .padding(18)
          .accessibilityLabel("Go to level \(app.progress.nextUp)")
        }
        .task {
          // Lazy rows settle their sizes as they're built, so land, let it settle, then land again exactly.
          // Waiting on a gate: open on the gate's card, where the nudge is.
          let p = app.progress
          let gate = p.isGated(p.unlocked) ? Worlds.world(ofLevel: p.unlocked).map { JourneyRow.realm($0.realm).id } : nil
          let here = gate ?? JourneyRow.level(p.nextUp).id
          let anchor: UnitPoint = gate == nil ? .center : .top
          reader.scrollTo(here, anchor: anchor)
          for _ in 0..<2 {
            try? await Task.sleep(for: .milliseconds(80))
            reader.scrollTo(here, anchor: anchor)
          }
        }
        .onChange(of: jumpCount) { _, _ in
          guard let jump else { return }
          if jump.animated { withAnimation(.smooth(duration: 0.6)) { reader.scrollTo(jump.id, anchor: .center) } }
          else { reader.scrollTo(jump.id, anchor: jump.id.hasPrefix("realm") ? .top : .center) }
        }
        .task(id: width) {
          // Backdrops for where you are first, then the rest of the realms.
          let here = Worlds.world(ofLevel: app.progress.nextUp)?.number ?? 1
          let order = Worlds.all.sorted { abs($0.number - here) < abs($1.number - here) }
          var seen = Set<String>(), list: [(Arena, Int)] = []
          for w in order where seen.insert("\(w.biome.rawValue)-\(w.variant)").inserted { list.append((w.biome, w.variant)) }
          await Backdrop.prewarm(list, size: CGSize(width: width, height: rowHeight * 10))
        }
      }
    }
  }
}

/// One row of the journey. Reads progress itself, so a row only redraws when what it shows changes.
struct JourneyRowView: View {
  @Environment(AppModel.self) private var app
  let row: JourneyRow
  let width: CGFloat
  let rowHeight: CGFloat
  let jump: (String) -> Void

  private var slot: Int { Journey.slot[row] ?? 0 }
  private var mid: CGFloat { width / 2 }
  private var amp: CGFloat { min(width * 0.27, 150) }

  var body: some View {
    switch row {
    case .realm(let n): realmRow(n)
    case .world(let n): worldRow(n)
    case .level(let n): levelRow(n)
    case .infinity: infinityRow
    }
  }

  // MARK: Levels

  private func levelRow(_ level: Int) -> some View {
    let p = app.progress
    let world = Worlds.world(ofLevel: level)!
    let k = (level - 1) % 10
    let realmLocked = !p.realmOpen(world.realm) && level > p.unlocked
    let x = mid + amp * Journey.swing(Double(slot))
    return ZStack(alignment: .topLeading) {
      BackdropFill(biome: world.biome, variant: world.variant, size: CGSize(width: width, height: rowHeight * 10), band: CGFloat(k) * rowHeight, visible: rowHeight)
        .overlay(Color.black.opacity(0.32))
        .overlay(alignment: .bottom) {
          if k == 9 { LinearGradient(colors: [.clear, Theme.night], startPoint: .top, endPoint: .bottom).frame(height: rowHeight * 0.6) }
        }
        .overlay(alignment: .top) {
          if k == 0 { LinearGradient(colors: [Theme.night, .clear], startPoint: .top, endPoint: .bottom).frame(height: rowHeight * 0.7) }
        }
      PathPiece(slot: slot, litTop: level <= p.unlocked, litBottom: level < p.unlocked, mid: mid, amp: amp, tint: world.biome.aurora[0])
      LevelStop(level: level, world: world, jump: jump)
        .position(x: x, y: rowHeight / 2)
    }
    .frame(width: width, height: rowHeight)
    .saturation(realmLocked ? 0.35 : 1)
  }

  // MARK: World banners

  private func worldRow(_ n: Int) -> some View {
    let w = Worlds.all[n - 1]
    let p = app.progress
    let reached = p.unlocked >= w.levels.lowerBound
    return ZStack {
      PathPiece(slot: slot, litTop: reached, litBottom: reached, mid: mid, amp: amp, tint: w.biome.aurora[0])
      WorldBanner(world: w)
        .padding(.horizontal, 20)
        .padding(.vertical, 26)
    }
    .frame(width: width)
    .background(alignment: .top) {
      BackdropFill(biome: w.biome, variant: w.variant, size: CGSize(width: width, height: rowHeight * 10))
        .overlay(LinearGradient(colors: [Theme.night, Theme.night.opacity(0.55), Theme.night], startPoint: .top, endPoint: .bottom))
    }
    .clipped()
    .saturation(!p.realmOpen(w.realm) && !reached ? 0.35 : 1)
  }

  // MARK: Realm title cards

  private func realmRow(_ n: Int) -> some View {
    let r = Worlds.realms[n - 1]
    let p = app.progress
    let reached = p.unlocked >= Journey.firstLevel(ofRealm: n)
    return ZStack {
      AuroraTint(arena: r.home)
      PathPiece(slot: slot, litTop: reached, litBottom: reached && n > 1, mid: mid, amp: amp, tint: r.home.aurora[0], hideTop: n == 1)
      RealmCard(realm: r) { jump(JourneyRow.level(p.nextUp).id) }
        .padding(.horizontal, 18)
        .padding(.vertical, 40)
    }
    .frame(width: width)
    .background(alignment: .top) {
      BackdropFill(biome: r.home, size: CGSize(width: width, height: rowHeight * 10), band: rowHeight * 3)
        .overlay(Color.black.opacity(0.5))
    }
    .clipped()
  }

  private var infinityRow: some View {
    let p = app.progress
    let open = p.infinityOpen
    return ZStack {
      AuroraTint(arena: .space)
      PathPiece(slot: slot, litTop: open, litBottom: false, mid: mid, amp: amp, tint: Theme.cyan, hideBottom: true)
      Button { app.route = .play(.campaign(max(Campaign.finalAuthored + 1, p.unlocked))) } label: {
        HStack(spacing: 14) {
          Text("∞").font(.system(size: 46, weight: .black, design: .rounded)).foregroundStyle(Theme.cyan)
            .shadow(color: Theme.cyan, radius: 10)
          VStack(alignment: .leading, spacing: 2) {
            Text("Infinity").font(.game(.title2, .black)).foregroundStyle(Theme.ink)
            Text(open ? "Generated levels that keep climbing. You're on level \(max(Campaign.finalAuthored + 1, p.unlocked))." : "Generated levels that never end. Clear level \(Campaign.finalAuthored) to open it.")
              .font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
          }
          Spacer(minLength: 0)
          if !open { ArtImage(item: .glyph(.lock), size: 28) }
        }
        .padding(18)
        .frame(maxWidth: 520, minHeight: Theme.target)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.panel.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(open ? Theme.cyan : Theme.panelEdge, lineWidth: open ? 2 : 1))
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(!open)
      .padding(.horizontal, 18)
      .padding(.vertical, 40)
      .accessibilityLabel(open ? "Infinity, level \(max(Campaign.finalAuthored + 1, p.unlocked))" : "Infinity, locked. Clear level \(Campaign.finalAuthored) to open it.")
    }
    .frame(width: width)
  }
}

/// A still wash of a biome's aurora colours: the house glow, without a Metal layer per row.
struct AuroraTint: View {
  let arena: Arena
  var body: some View {
    let c = arena.aurora
    ZStack {
      RadialGradient(colors: [c[0].opacity(0.45), .clear], center: UnitPoint(x: 0.15, y: 0.2), startRadius: 0, endRadius: 360)
      RadialGradient(colors: [c[1].opacity(0.4), .clear], center: UnitPoint(x: 0.9, y: 0.55), startRadius: 0, endRadius: 320)
      RadialGradient(colors: [c[2].opacity(0.3), .clear], center: UnitPoint(x: 0.4, y: 1), startRadius: 0, endRadius: 300)
    }
    .blendMode(.plusLighter)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

/// The path through one row: from halfway to the row above, through this row's stop, to halfway to the next.
struct PathPiece: View {
  let slot: Int
  let litTop: Bool
  let litBottom: Bool
  let mid: CGFloat
  let amp: CGFloat
  var tint: Color = Theme.sun
  var hideTop = false
  var hideBottom = false
  var body: some View {
    Canvas { g, size in
      let s = Double(slot)
      func point(_ t: Double) -> CGPoint {
        CGPoint(x: mid + amp * Journey.swing(t), y: (t - s + 0.5) * size.height)
      }
      func piece(_ a: Double, _ b: Double) -> Path {
        var p = Path()
        p.move(to: point(a))
        for i in 1...12 { p.addLine(to: point(a + (b - a) * Double(i) / 12)) }
        return p
      }
      let parts: [(Path, Bool, Bool)] = [(piece(s - 0.5, s), litTop, hideTop), (piece(s, s + 0.5), litBottom, hideBottom)]
      for (path, lit, hidden) in parts where !hidden {
        if lit {
          g.stroke(path, with: .color(tint.opacity(0.35)), style: StrokeStyle(lineWidth: 18, lineCap: .round))
          g.stroke(path, with: .color(Theme.sun), style: StrokeStyle(lineWidth: 7, lineCap: .round))
          g.stroke(path, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        } else {
          g.stroke(path, with: .color(.black.opacity(0.35)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
          g.stroke(path, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [0.1, 13]))
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

/// One level on the path: its stop, its stars, and a pulse where you are.
struct LevelStop: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let level: Int
  let world: World
  let jump: (String) -> Void
  @ScaledMetric(relativeTo: .headline) private var node: CGFloat = 58
  @State private var pulse = false

  var body: some View {
    let p = app.progress
    let open = p.isOpen(level)
    let gated = p.isGated(level)
    let stars = p.stars[level] ?? 0
    let boss = level % 10 == 0
    let current = level == p.nextUp
    let size = min(84, boss ? node * 1.25 : node)
    let c = world.biome.aurora
    Button {
      if open { app.route = .play(.campaign(level)) }
      else if gated { jump(JourneyRow.level(p.nextUp).id) }
    } label: {
      VStack(spacing: 3) {
        ZStack {
          if current && !reduceMotion {
            Circle().stroke(Theme.cyan, lineWidth: 3).frame(width: size, height: size)
              .scaleEffect(pulse ? 1.55 : 1).opacity(pulse ? 0 : 0.9)
            Circle().fill(Theme.cyan.opacity(0.3)).frame(width: size, height: size)
              .scaleEffect(pulse ? 1.3 : 1.05).opacity(pulse ? 0 : 0.7)
          }
          if boss {
            ArtImage(item: .bubble(.boss), size: size)
              .saturation(open ? 1 : 0.1).opacity(open ? 1 : 0.65)
            Image(systemName: Journey.bossIcon(world.boss)).font(.system(size: size * 0.24, weight: .black))
              .foregroundStyle(Theme.sun).shadow(color: .black, radius: 2)
              .offset(y: -size * 0.56)
          } else {
            Circle()
              .fill(open
                ? AnyShapeStyle(LinearGradient(colors: stars > 0 ? [c[0], c[1]] : [Color.white, c[0]], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(Theme.night.opacity(0.82)))
              .frame(width: size, height: size)
            Circle().fill(.white.opacity(open ? 0.32 : 0.08)).frame(width: size * 0.6, height: size * 0.28).offset(y: -size * 0.24)
            Circle().stroke(current ? Theme.cyan : .white.opacity(open ? 0.9 : 0.3), lineWidth: current ? 4 : 2).frame(width: size, height: size)
          }
          if gated {
            ArtImage(item: .glyph(.lock), size: size * 0.46)
          } else {
            Text("\(level)")
              .font(.game(level >= 100 ? .subheadline : .headline, .black)).monospacedDigit()
              .minimumScaleFactor(0.5).lineLimit(1)
              .foregroundStyle(open ? (boss ? Color.white : Color(red: 0.12, green: 0.05, blue: 0.22)) : Theme.muted.opacity(0.7))
              .shadow(color: boss ? .black.opacity(0.8) : .white.opacity(0.4), radius: 1.5)
              .frame(width: size * 0.8)
              .padding(.vertical, boss ? 1 : 0)
              .background { if boss { Capsule().fill(.black.opacity(0.7)).frame(width: size * 0.62) } }
              .offset(y: boss ? size * 0.4 : 0)
          }
        }
        .frame(width: size, height: size)
        .shadow(color: open ? c[0].opacity(0.55) : .clear, radius: 10)
        .overlay(alignment: .topTrailing) {
          if let grade = p.grade(level), !gated {
            GradeStamp(grade: grade, size: 26).offset(x: 8, y: -6).allowsHitTesting(false)
          }
        }
        .overlay(alignment: .topLeading) {
          // Cleared on Overdrive: a flame on the stop.
          if p.clearedOnOverdrive(level), !gated {
            FlameMark(size: 17).offset(x: -6, y: -8).allowsHitTesting(false)
          }
        }
        if level <= p.unlocked && !gated {
          HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { i in ArtImage(item: .glyph(i < stars ? .starOn : .starOff), size: 15) }
            if stars > 0 {
              Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 10).padding(.horizontal, 3)
              ChallengePips(done: p.challengesDone(level), size: 6)
            }
          }
          .padding(.horizontal, 5).padding(.vertical, 1)
          .background(Capsule().fill(.black.opacity(0.45)))
        }
      }
      .frame(minWidth: Theme.target, minHeight: Theme.target)
      .contentShape(Rectangle())
    }
    .buttonStyle(StopStyle())
    .disabled(!open && !gated)
    .overlay(alignment: Journey.swing(Double(Journey.slot[.level(level)] ?? 0)) > 0 ? .leading : .trailing) {
      if current { hereTag(open: open).fixedSize().offset(x: Journey.swing(Double(Journey.slot[.level(level)] ?? 0)) > 0 ? -118 : 118, y: -10) }
      else if gated { gateTag.fixedSize().offset(x: Journey.swing(Double(Journey.slot[.level(level)] ?? 0)) > 0 ? -150 : 150, y: -10) }
    }
    .accessibilityLabel(label)
    .accessibilityHint(open ? "Plays it" : gated ? "Shows a level with stars to win" : "")
    .onAppear {
      guard current, !reduceMotion else { return }
      withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
    }
  }

  private var label: String {
    let p = app.progress
    let stars = p.stars[level] ?? 0
    let boss = level % 10 == 0 ? ", \(Journey.bossName(world.boss))" : ""
    let mastery = (p.grade(level).map { ", grade \($0.letter), \(p.challengeCount(level)) of \(Challenges.perLevel) challenges" } ?? "") + (p.clearedOnOverdrive(level) ? ", cleared on Overdrive" : "")
    if p.isOpen(level) { return "Level \(level)\(boss), \(world.name), \(stars) of 3 stars\(mastery)\(level == p.nextUp ? ", you are here" : "")" }
    if p.isGated(level) {
      let r = Worlds.realms[world.realm - 1]
      return "Level \(level), locked. Win \(p.starsShort(world.realm)) more stars to open \(r.name)."
    }
    return "Level \(level)\(boss), locked"
  }

  private func hereTag(open: Bool) -> some View {
    HStack(spacing: 5) {
      Image(systemName: "play.fill").font(.system(size: 12, weight: .black))
      Text(level % 10 == 0 ? "Boss!" : "Play").font(.game(.subheadline, .black))
    }
    .foregroundStyle(Color(red: 0.2, green: 0.08, blue: 0.1))
    .padding(.horizontal, 14).frame(minHeight: 34)
    .background(Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.4), Theme.orange], startPoint: .top, endPoint: .bottom)))
    .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1))
    .shadow(color: Theme.sun.opacity(0.6), radius: 10)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private var gateTag: some View {
    let p = app.progress
    return HStack(spacing: 5) {
      ArtImage(item: .glyph(.starOn), size: 16)
      Text("\(p.starsShort(world.realm)) more to open").font(.game(.footnote, .heavy)).foregroundStyle(Theme.ink)
    }
    .padding(.horizontal, 12).frame(minHeight: 32)
    .background(Capsule().fill(Theme.panel.opacity(0.95)))
    .overlay(Capsule().stroke(Theme.sun, lineWidth: 1.5))
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private struct StopStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.9 : 1)
      .animation(.spring(duration: 0.2), value: configuration.isPressed)
  }
}

/// A world's banner: its name and number, what it teaches, its twists, its boss and its stars.
struct WorldBanner: View {
  @Environment(AppModel.self) private var app
  let world: World
  var body: some View {
    let p = app.progress
    let stars = p.worldStars(world.number)
    let reached = p.unlocked >= world.levels.lowerBound
    let c = world.biome.aurora
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Text("WORLD \(world.number)").font(.game(.caption, .heavy)).tracking(1.2).foregroundStyle(c[0])
        Spacer(minLength: 6)
        if p.hasMedal(world.number) {
          Label("Medal", systemImage: "medal.fill").font(.game(.caption, .heavy)).foregroundStyle(Theme.sun)
        } else if p.worldComplete(world.number) {
          Label("Complete", systemImage: "checkmark.seal.fill").font(.game(.caption, .heavy)).foregroundStyle(Theme.sun)
        }
        HStack(spacing: 3) {
          ArtImage(item: .glyph(.starOn), size: 15)
          Text("\(stars)/30").font(.game(.caption, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
        }
        HStack(spacing: 3) {
          Image(systemName: "rosette").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.sun)
          Text("\(p.worldChallenges(world.number))/\(Challenges.perWorld)").font(.game(.caption, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
        }
      }
      Text(world.name).font(.game(.title2, .black)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
      Text(world.teaches).font(.game(.footnote, .semibold)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 6) { chips }
        VStack(alignment: .leading, spacing: 6) { chips }
      }
    }
    .padding(16)
    .frame(maxWidth: 520, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.panel.opacity(0.96))
        .overlay(alignment: .topTrailing) {
          RadialGradient(colors: [c[1].opacity(0.45), .clear], center: .topTrailing, startRadius: 0, endRadius: 220)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .blendMode(.plusLighter)
        }
    }
    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(LinearGradient(colors: [c[0], c[1].opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
    .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    .opacity(reached ? 1 : 0.82)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(a11y)
  }

  @ViewBuilder private var chips: some View {
    ForEach(world.twists, id: \.self) { t in Chip(icon: Journey.twistIcon(t), text: Journey.twistName(t), color: Theme.cyan) }
    Chip(icon: Journey.bossIcon(world.boss), text: Journey.bossName(world.boss), color: Theme.red)
  }

  private var a11y: String {
    let p = app.progress
    let twists = world.twists.isEmpty ? "" : " Twist: \(world.twists.map(Journey.twistName).joined(separator: " and "))."
    return "World \(world.number), \(world.name). \(world.teaches)\(twists) \(Journey.bossName(world.boss)). \(p.worldStars(world.number)) of 30 stars. \(p.worldChallenges(world.number)) of \(Challenges.perWorld) challenges\(p.hasMedal(world.number) ? ", medal won" : "")."
  }
}

struct Chip: View {
  let icon: String
  let text: String
  let color: Color
  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
      Text(text).font(.game(.caption, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
    }
    .padding(.horizontal, 9).padding(.vertical, 5)
    .background(Capsule().fill(color.opacity(0.16)))
    .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
  }
}

/// A ring that fills with a realm's stars, in its aurora colours.
struct ProgressRing: View {
  let fraction: Double
  let colors: [Color]
  var line: CGFloat = 8
  var body: some View {
    ZStack {
      Circle().stroke(.white.opacity(0.14), lineWidth: line)
      Circle().trim(from: 0, to: max(0.001, min(1, fraction)))
        .stroke(AngularGradient(colors: colors + [colors[0]], center: .center), style: StrokeStyle(lineWidth: line, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .shadow(color: colors[0].opacity(0.7), radius: 5)
    }
    .accessibilityHidden(true)
  }
}

/// A realm's title card: its name, the genre it winks at, its progress, and what opens it.
struct RealmCard: View {
  @Environment(AppModel.self) private var app
  let realm: Realm
  let findStars: () -> Void
  var body: some View {
    let p = app.progress
    let stars = p.realmStars(realm.number)
    let cleared = Journey.levels(ofRealm: realm.number).filter { (p.stars[$0] ?? 0) > 0 }.count
    let open = p.realmOpen(realm.number)
    let short = p.starsShort(realm.number)
    let c = realm.home.aurora
    VStack(spacing: 12) {
      Text("REALM \(realm.number) OF \(Worlds.realms.count)").font(.game(.caption, .heavy)).tracking(2).foregroundStyle(c[0])
      Text(realm.name).font(.game(.largeTitle, .black)).foregroundStyle(.white)
        .multilineTextAlignment(.center).shadow(color: c[0].opacity(0.8), radius: 14)
        .accessibilityAddTraits(.isHeader)
      Text(realm.nod).font(.game(.subheadline, .semibold)).italic().foregroundStyle(Theme.ink.opacity(0.85)).multilineTextAlignment(.center)
      HStack(spacing: 16) {
        ZStack {
          ProgressRing(fraction: Double(stars) / 240, colors: c)
          VStack(spacing: 0) {
            ArtImage(item: .glyph(.starOn), size: 18)
            Text("\(stars)").font(.game(.headline, .black)).monospacedDigit().foregroundStyle(Theme.ink).minimumScaleFactor(0.6)
          }
        }
        .frame(width: 74, height: 74)
        VStack(alignment: .leading, spacing: 3) {
          Text("\(cleared) of 80 levels").font(.game(.subheadline, .heavy)).foregroundStyle(Theme.ink)
          Text("\(stars) of 240 stars").font(.game(.footnote, .semibold)).foregroundStyle(Theme.muted)
          Text("\(realm.worlds.filter { p.worldComplete($0) }.count) of 8 worlds").font(.game(.footnote, .semibold)).foregroundStyle(Theme.muted)
          Text("\(p.realmChallenges(realm.number)) of \(Challenges.perWorld * 8) challenges").font(.game(.footnote, .semibold)).foregroundStyle(Theme.sun.opacity(0.9))
        }
      }
      if !open {
        let prev = Worlds.realms[realm.number - 2]
        VStack(spacing: 8) {
          HStack(spacing: 8) {
            ArtImage(item: .glyph(.lock), size: 24)
            Text("Win \(short) more \(short == 1 ? "star" : "stars") in \(prev.name) to open").font(.game(.subheadline, .heavy)).foregroundStyle(Theme.ink)
              .fixedSize(horizontal: false, vertical: true)
          }
          GateBar(have: p.realmStars(prev.number), need: Gates.stars(toOpen: realm.number))
          if p.unlocked >= Journey.firstLevel(ofRealm: prev.number) {
            Button("Find stars to win", action: findStars).buttonStyle(ChunkyStyle()).frame(maxWidth: 280)
          }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black.opacity(0.4)))
      }
    }
    .padding(.horizontal, 20).padding(.vertical, 22)
    .frame(maxWidth: 560)
    .background {
      ZStack {
        RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.panel.opacity(0.86))
        AuroraTint(arena: realm.home).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.black.opacity(0.25))
      }
    }
    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(LinearGradient(colors: [c[0], c[1], c[2]], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
    .shadow(color: c[0].opacity(0.35), radius: 24)
    .accessibilityElement(children: .contain)
  }
}

/// Stars toward a gate.
struct GateBar: View {
  let have: Int
  let need: Int
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.14))
        Capsule().fill(LinearGradient(colors: [Theme.sun, Theme.orange], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(10, g.size.width * min(1, Double(have) / Double(max(1, need)))))
      }
    }
    .frame(height: 10)
    .overlay(alignment: .trailing) {
      Text("\(have)/\(need)").font(.game(.caption2, .heavy)).monospacedDigit().foregroundStyle(Theme.ink).offset(y: 14)
    }
    .padding(.bottom, 12)
    .accessibilityElement().accessibilityLabel("\(have) of \(need) stars")
  }
}

// MARK: - Realm overview

/// All ten realms at a glance, with a ring of stars each. Picking one jumps into the path.
struct RealmOverview: View {
  @Environment(AppModel.self) private var app
  var columns = 2
  var compact = false
  let pick: (Int) -> Void
  var body: some View {
    ScrollView {
      MasteryBar()
        .padding(.horizontal, 16).padding(.top, 12)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columns), spacing: 12) {
        ForEach(Worlds.realms, id: \.number) { r in RealmTile(realm: r, compact: compact) { pick(r.number) } }
      }
      .padding(16)
    }
    .scrollIndicators(.hidden)
  }
}

struct RealmTile: View {
  @Environment(AppModel.self) private var app
  @Environment(\.displayScale) private var scale
  let realm: Realm
  var compact = false
  let action: () -> Void
  var body: some View {
    let p = app.progress
    let stars = p.realmStars(realm.number)
    let open = p.realmOpen(realm.number)
    let reached = p.unlocked >= Journey.firstLevel(ofRealm: realm.number)
    let here = Journey.levels(ofRealm: realm.number).contains(p.nextUp)
    let c = realm.home.aurora
    Button(action: action) {
      HStack(spacing: 12) {
        ZStack {
          ProgressRing(fraction: Double(stars) / 240, colors: c, line: 6)
          if open || reached {
            Text("\(realm.number)").font(.game(.title2, .black)).foregroundStyle(.white).shadow(color: c[0], radius: 6)
          } else {
            ArtImage(item: .glyph(.lock), size: 24)
          }
        }
        .frame(width: 58, height: 58)
        VStack(alignment: .leading, spacing: 2) {
          Text(realm.name).font(.game(.headline, .black)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.75)
          if !compact {
            Text(realm.nod).font(.game(.caption, .semibold)).italic().foregroundStyle(Theme.muted).lineLimit(2).fixedSize(horizontal: false, vertical: true)
          }
          if !open {
            Text("\(p.starsShort(realm.number)) more ★ to open").font(.game(.caption, .heavy)).foregroundStyle(Theme.sun)
          } else if here {
            Text("You're here").font(.game(.caption, .heavy)).foregroundStyle(Theme.cyan)
          } else {
            Text("★ \(stars) of 240 · \(p.realmChallenges(realm.number)) challenges").font(.game(.caption, .heavy)).monospacedDigit().foregroundStyle(Theme.ink.opacity(0.9))
              .lineLimit(1).minimumScaleFactor(0.8)
          }
        }
        Spacer(minLength: 0)
      }
      .padding(10)
      .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
      .background {
        ZStack {
          GeometryReader { g in
            BackdropFill(biome: realm.home, size: g.size, band: 0, scale: scale)
          }
          LinearGradient(colors: [Theme.night.opacity(0.92), Theme.night.opacity(0.45)], startPoint: .leading, endPoint: .trailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(here ? Theme.cyan : c[0].opacity(open ? 0.6 : 0.25), lineWidth: here ? 2.5 : 1))
      .saturation(open || reached ? 1 : 0.4)
      .contentShape(RoundedRectangle(cornerRadius: 18))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Realm \(realm.number), \(realm.name). \(realm.nod). \(stars) of 240 stars.\(open ? "" : " Locked, \(p.starsShort(realm.number)) more stars to open.")\(here ? " You are here." : "")")
    .accessibilityHint("Shows it on the journey")
  }
}

/// Mastery at a glance: challenges earned across the campaign, S grades and medals.
struct MasteryBar: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let p = app.progress
    let done = p.mastery, total = Challenges.total
    HStack(spacing: 12) {
      ZStack {
        ProgressRing(fraction: Double(done) / Double(total), colors: [Theme.sun, Theme.orange, Theme.cyan], line: 6)
        Image(systemName: "rosette").font(.system(size: 20, weight: .black)).foregroundStyle(Theme.sun)
      }
      .frame(width: 50, height: 50)
      VStack(alignment: .leading, spacing: 2) {
        Text("Mastery").font(.game(.caption, .heavy)).tracking(1.5).foregroundStyle(Theme.sun)
        Text("\(done) of \(total)").font(.game(.headline, .black)).monospacedDigit().foregroundStyle(Theme.ink)
      }
      Spacer(minLength: 4)
      VStack(alignment: .trailing, spacing: 3) {
        HStack(spacing: 4) {
          GradeStamp(grade: .s, size: 22)
          Text("\(p.sGrades)").font(.game(.subheadline, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
        }
        HStack(spacing: 4) {
          Image(systemName: "medal.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.sun)
          Text("\(p.medals.count)").font(.game(.subheadline, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
        }
      }
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel.opacity(0.92)))
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.sun.opacity(0.55), lineWidth: 1.5))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Mastery: \(done) of \(total) challenges. \(p.sGrades) S grades. \(p.medals.count) medals.")
    .accessibilityIdentifier("mastery")
  }
}

/// The realm overview on a phone: a sheet over the path.
struct RealmSheet: View {
  let pick: (Int) -> Void
  let close: () -> Void
  var body: some View {
    ZStack(alignment: .bottom) {
      Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: close).accessibilityHidden(true)
      VStack(spacing: 0) {
        HStack {
          Text("Realms").font(.game(.title2, .black)).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
          Spacer()
          Button(action: close) {
            Image(systemName: "xmark").font(.headline.weight(.heavy)).foregroundStyle(Theme.ink)
              .frame(width: Theme.target, height: Theme.target).background(Circle().fill(Theme.panelEdge.opacity(0.4)))
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Close")
        }
        .padding(.horizontal, 18).padding(.top, 14)
        RealmOverview(columns: 1, pick: pick)
      }
      .frame(maxHeight: 640)
      .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.panel).ignoresSafeArea(edges: .bottom))
      .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Theme.panelEdge, lineWidth: 1.5).ignoresSafeArea(edges: .bottom))
    }
    .accessibilityAddTraits(.isModal)
  }
}

// MARK: - Celebrations

/// A world's or a realm's complete moment: aurora, confetti and the stars counted up. Shown once each.
struct CheerView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let cheer: GameProgress.Cheer
  @State private var shown = 0
  @State private var arrived = false

  private var info: (kicker: String, title: String, line: String, stars: Int, of: Int, arena: Arena) {
    let p = app.progress
    switch cheer {
    case .world(let n):
      let w = Worlds.all[n - 1]
      let next = Worlds.world(n + 1)
      return ("WORLD \(n) COMPLETE", w.name, next.map { "Next up: \($0.name)." } ?? "Every world, done.", p.worldStars(n), 30, w.biome)
    case .realm(let n):
      let r = Worlds.realms[n - 1]
      let line: String
      if let next = Worlds.realm(n + 1) {
        line = p.realmOpen(n + 1) ? "\(next.name) is open: \(next.nod.lowercased())." : "\(next.name) opens at \(Gates.stars(toOpen: n + 1)) stars. \(p.starsShort(n + 1)) to go."
      } else { line = "All ten realms. Infinity is open." }
      return ("REALM COMPLETE", r.name, line, p.realmStars(n), 240, r.home)
    }
  }

  var body: some View {
    let i = info
    ZStack {
      Color.black.opacity(0.6).ignoresSafeArea()
      AuroraField(arena: i.arena, strength: 0.75, alwaysOn: true)
      if !reduceMotion { Confetti(colors: i.arena.aurora + [Theme.sun]).ignoresSafeArea().allowsHitTesting(false) }
      VStack(spacing: 14) {
        Text(i.kicker).font(.game(.subheadline, .heavy)).tracking(2.5).foregroundStyle(Theme.sun)
        Text(i.title).font(.game(.largeTitle, .black)).foregroundStyle(.white).multilineTextAlignment(.center)
          .shadow(color: i.arena.aurora[0], radius: 16)
        HStack(spacing: 6) {
          ArtImage(item: .glyph(.starOn), size: 40)
            .scaleEffect(arrived ? 1 : 0.2).rotationEffect(.degrees(arrived ? 0 : -90))
          Text("\(shown)").font(.system(size: 52, weight: .black, design: .rounded)).monospacedDigit().foregroundStyle(Theme.sun)
            .contentTransition(.numericText())
          Text("/ \(i.of)").font(.game(.title2, .heavy)).foregroundStyle(Theme.muted)
        }
        .accessibilityElement().accessibilityLabel("\(i.stars) of \(i.of) stars")
        Text(i.line).font(.game(.headline, .semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        VStack(spacing: 10) {
          Button("Onward") { done(play: true) }.buttonStyle(ChunkyStyle())
          Button("See the journey") { done(play: false) }.buttonStyle(QuietStyle())
        }
        .padding(.top, 6)
      }
      .padding(26)
      .frame(maxWidth: 440)
      .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.panel.opacity(0.98)))
      .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(LinearGradient(colors: i.arena.aurora, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
      .shadow(color: i.arena.aurora[0].opacity(0.5), radius: 30)
      .padding(20)
      .scaleEffect(arrived || reduceMotion ? 1 : 0.85).opacity(arrived || reduceMotion ? 1 : 0)
    }
    .accessibilityAddTraits(.isModal)
    .task {
      Haptics.shared.good()
      withAnimation(.spring(duration: 0.5, bounce: 0.35)) { arrived = true }
      let target = i.stars
      if reduceMotion { shown = target; return }
      try? await Task.sleep(for: .milliseconds(350))
      let steps = min(target, 30)
      for s in 0...steps {
        try? await Task.sleep(for: .milliseconds(steps > 0 ? 900 / steps : 0))
        withAnimation(.snappy(duration: 0.12)) { shown = steps == 0 ? target : target * s / steps }
      }
      #if DEBUG
      Debug.ready("cheer")
      #endif
    }
  }

  private func done(play: Bool) {
    app.progress.markCheered(cheer)
    if play { app.route = .play(.campaign(app.progress.nextUp)) } else { app.route = .map }
  }
}

/// Falling confetti, drawn in one canvas.
struct Confetti: View {
  let colors: [Color]
  @State private var start = Date()
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
      let t = ctx.date.timeIntervalSince(start)
      Canvas { g, size in
        var rng = SplitMix(seed: 42)
        for i in 0..<90 {
          let x0 = rng.unit() * size.width, speed = 90 + rng.unit() * 140, sway = 10 + rng.unit() * 30
          let delay = rng.unit() * 2.5, spin = (rng.unit() - 0.5) * 8, w = 6 + rng.unit() * 6
          let life = max(0, t - delay)
          let y = -20 + (life * speed).truncatingRemainder(dividingBy: size.height + 40)
          let x = x0 + sin(life * 2 + Double(i)) * sway
          var p = Path(roundedRect: CGRect(x: -w / 2, y: -w, width: w, height: w * 2), cornerRadius: 2)
          p = p.applying(CGAffineTransform(rotationAngle: life * spin)).applying(CGAffineTransform(translationX: x, y: y))
          let fade = min(1, life * 3) * max(0.15, 1 - max(0, t - 6) / 3)
          g.fill(p, with: .color(colors[i % colors.count].opacity(fade)))
        }
      }
    }
    .accessibilityHidden(true)
  }
}
