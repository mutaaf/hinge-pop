import SwiftUI
import HingePopArt
import HingePopCore

@main
struct HingePopApp: App {
  @State private var app = AppModel()
  @State private var duo = DuoModel()
  @Environment(\.scenePhase) private var phase
  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(app)
        .environment(duo)
        .modifier(TracksHinge(duo: duo))
        .preferredColorScheme(.dark)
    }
    // Usage events go in one batch on the way to the background; a long time away starts a new session.
    .onChange(of: phase) { old, new in
      if new == .background { Usage.shared.didEnterBackground() }
      if new == .active, old == .background { Usage.shared.willEnterForeground() }
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    ZStack {
      switch app.route {
      case .home: HomeView().transition(screen(home: true))
      case .map: JourneyView().transition(screen())
      case .guide: GuideView().transition(screen())
      case .settings: SettingsView().transition(screen())
      case .arcade: ArcadeView().transition(screen())
      case .play(let mode): PlayView(mode: mode, app: app).id(String(describing: mode)).transition(playing)
      }
    }
    .overlay {
      // A world's or realm's complete moment, once each, whenever you're out of a game.
      if !isPlaying, app.updateNotes == nil, let cheer = app.progress.pendingCheer {
        CheerView(cheer: cheer).transition(.opacity).id(cheer.id)
      }
    }
    .overlay {
      if let notes = app.updateNotes {
        WhatsNewView(notes: notes) { withAnimation(.easeOut(duration: 0.2)) { app.dismissUpdateNotes() } }
          go: { place in withAnimation(.easeOut(duration: 0.2)) { app.follow(place) } }
          .transition(.opacity)
      }
    }
    .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.42, bounce: 0.12), value: app.route)
    .statusBarHidden(isPlaying)
    .persistentSystemOverlays(isPlaying ? .hidden : .automatic)
    #if DEBUG
    .task {
      guard Debug.has("-landscape"), let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
      scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    }
    .task { await Debug.snapshotIfAsked(app) }
    #endif
  }
  private var isPlaying: Bool { if case .play = app.route { true } else { false } }

  /// Screens slide in a little and settle; Home sits underneath and steps back. Opacity only under Reduce Motion.
  private func screen(home: Bool = false) -> AnyTransition {
    if reduceMotion { return .opacity }
    return home ? .opacity.combined(with: .scale(scale: 0.96)) : .opacity.combined(with: .offset(x: 40))
  }
  /// Play zooms up out of the button that started it.
  private var playing: AnyTransition {
    reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.06)), removal: .opacity)
  }
}

// MARK: - Home

/// Home: the logo, one big card that says exactly what Play starts, Arcade and Daily as strong second
/// choices, and the rest as small tiles. Play is always one tap.
struct HomeView: View {
  @Environment(AppModel.self) private var app
  @Environment(DuoModel.self) private var duo
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// Swipes on the logo, listening for the old arcade code.
  @State private var swipes: [SecretSwipe] = []
  @State private var codeToast: String?
  @State private var arrived = false
  var body: some View {
    GeometryReader { proxy in
      let fold = foldRect(proxy, duo: duo)
      ZStack {
        ArenaBackground(arena: .neon)
        Floaters(size: proxy.size)
        if let fold, fold.height >= fold.width, proxy.size.width > 560 {
          // A book: the title on the leading page and the choices on the trailing page, with the fold between.
          HStack(spacing: 0) {
            VStack(spacing: 14) { statBar; title(width: fold.minX - 64) }
              .padding(.horizontal, 20).frame(width: fold.minX)
            Color.clear.frame(width: fold.width)
            ScrollView { buttons.padding(20).frame(maxWidth: 460).frame(maxWidth: .infinity, minHeight: proxy.size.height) }
              .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
          }
        } else if proxy.size.width > proxy.size.height {
          HStack(spacing: 24) {
            VStack(spacing: 10) { statBar; title(width: min(proxy.size.width * 0.38, 440, (proxy.size.height - 130) * 1.15)) }
              .frame(maxWidth: .infinity)
            ScrollView { buttons.padding(.vertical, 16).frame(minHeight: proxy.size.height) }
              .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
              .frame(maxWidth: 440)
          }
          .padding(.horizontal, 24)
        } else {
          ScrollView {
            VStack(spacing: 14) {
              statBar
              title(width: min(proxy.size.width * 0.62, 380))
              buttons.frame(maxWidth: 480)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: proxy.size.height)
          }
          .scrollBounceBehavior(.basedOnSize)
          .scrollIndicators(.hidden)
        }
      }
      #if DEBUG
      .task { Debug.ready("root") }
      #endif
    }
    .onAppear {
      if reduceMotion { arrived = true } else { withAnimation(.spring(duration: 0.6, bounce: 0.3)) { arrived = true } }
    }
  }

  // MARK: Top

  /// Stars, mastery and the daily streak at a glance, with Settings in reach.
  private var statBar: some View {
    let p = app.progress
    let streak = app.dailyStreak
    return HStack(spacing: 8) {
      StatPill(icon: AnyView(ArtImage(item: .glyph(.starOn), size: 18)), text: "\(p.totalStars)", color: Theme.sun)
        .accessibilityLabel("\(p.totalStars) stars")
      if p.mastery > 0 {
        StatPill(icon: AnyView(Image(systemName: "rosette").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.sun)), text: "\(p.mastery)", color: Theme.violet)
          .accessibilityLabel("\(p.mastery) challenges")
      }
      if streak > 0 {
        StatPill(icon: AnyView(FlameMark(size: 15, flicker: true)), text: "\(streak)", color: Theme.ember)
          .accessibilityLabel("Daily streak, \(streak) \(streak == 1 ? "day" : "days")")
      }
      Spacer(minLength: 4)
      RoundIcon(symbol: "gearshape.fill", label: "Settings") { app.go(.settings) }
    }
    .frame(maxWidth: 480)
    .opacity(arrived ? 1 : 0)
  }

  private func title(width: CGFloat) -> some View {
    VStack(spacing: 6) {
      AuroraAssemble(item: .logo, size: max(150, width), count: 1400)
        .modifier(Bob(amount: 5, period: 3.2))
        .accessibilityElement()
        .accessibilityLabel("Hinge Pop")
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 24).onEnded { g in
          let dx = g.translation.width, dy = g.translation.height
          swipes.append(abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up))
          swipes = Array(swipes.suffix(Secrets.code.count))
          guard Secrets.spells(swipes), let s = Secrets.named("cheat-code") else { return }
          swipes.removeAll()
          let new = app.progress.find(s.id)
          Haptics.shared.good()
          withAnimation(.spring(duration: 0.4)) { codeToast = new ? "\(s.emoji) Secret found: \(s.title). \(s.line)" : "\(s.emoji) \(s.line)" }
          Task { try? await Task.sleep(for: .seconds(4)); withAnimation { codeToast = nil } }
        })
        .overlay(alignment: .bottom) {
          if let codeToast {
            Text(codeToast).font(.game(.subheadline, .bold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
              .padding(12).background(Capsule().fill(Theme.panel)).overlay(Capsule().stroke(Theme.sun, lineWidth: 1.5))
              .transition(.scale.combined(with: .opacity))
          }
        }
      Text("POP · SPLIT · CHAIN · CLEAR").font(.game(.footnote, .heavy)).tracking(1.5).foregroundStyle(Theme.ink.opacity(0.9))
        .shadow(color: .black.opacity(0.5), radius: 3)
    }
  }

  // MARK: Choices

  private var buttons: some View {
    VStack(spacing: 12) {
      UpNextCard()
        .offset(y: arrived ? 0 : 30).opacity(arrived ? 1 : 0)
      DifficultySwitch()
        .offset(y: arrived ? 0 : 30).opacity(arrived ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.3).delay(0.06), value: arrived)
      HStack(spacing: 12) {
        ArcadeCard()
        DailyCard()
      }
      .fixedSize(horizontal: false, vertical: true)
      .offset(y: arrived ? 0 : 30).opacity(arrived ? 1 : 0)
      .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.3).delay(0.12), value: arrived)
      HStack(spacing: 10) {
        HomeTile(symbol: "map.fill", title: "Journey", tint: Theme.cyan) { app.go(.map) }
        HomeTile(symbol: "person.2.fill", title: "2 Players", tint: Theme.p2) { app.go(.play(.versus)) }
        HomeTile(symbol: "questionmark.bubble.fill", title: "How to play", tint: Theme.violet) { app.go(.guide) }
      }
      .offset(y: arrived ? 0 : 30).opacity(arrived ? 1 : 0)
      .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.3).delay(0.18), value: arrived)
    }
  }
}

/// What Play starts, shown before you press it: the world's own backdrop, realm and world, the level and its
/// stars, and a boss badge on a boss level. The whole card is the Play button.
struct UpNextCard: View {
  @Environment(AppModel.self) private var app
  @Environment(\.displayScale) private var scale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shine = false
  var body: some View {
    let p = app.progress
    let level = p.nextUp
    let hot = p.difficulty == .overdrive
    let world = Worlds.world(ofLevel: level)
    let realm = world.flatMap { Worlds.realm($0.realm) }
    let infinite = level > Campaign.finalAuthored
    let boss = !infinite && level % 10 == 0
    let stars = p.stars[level] ?? 0
    let biome = world?.biome ?? .space
    let c = biome.aurora
    Button { app.go(.play(.campaign(level))) } label: {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top, spacing: 10) {
          VStack(alignment: .leading, spacing: 3) {
            Text(kicker(realm: realm, world: world, infinite: infinite))
              .font(.game(.caption, .heavy)).tracking(1.5).foregroundStyle(.white.opacity(0.92))
              .lineLimit(1).minimumScaleFactor(0.8)
            Text(infinite ? "Infinity" : (world?.name ?? "Level \(level)"))
              .font(.game(.title2, .black)).foregroundStyle(.white)
              .lineLimit(1).minimumScaleFactor(0.7)
          }
          Spacer(minLength: 4)
          if boss {
            HStack(spacing: 4) {
              Image(systemName: world.map { Journey.bossIcon($0.boss) } ?? "crown.fill").font(.system(size: 13, weight: .black))
              Text("BOSS").font(.game(.caption, .black)).tracking(1)
            }
            .foregroundStyle(Color(red: 0.2, green: 0.05, blue: 0.08))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.6, blue: 0.6), Theme.red], startPoint: .top, endPoint: .bottom)))
          } else if level <= Campaign.finalAuthored, level > 1 {
            HStack(spacing: 2) {
              ForEach(0..<3, id: \.self) { i in ArtImage(item: .glyph(i < stars ? .starOn : .starOff), size: 18) }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(.black.opacity(0.4)))
          }
        }
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 0) {
            Text("LEVEL").font(.game(.caption2, .heavy)).tracking(2).foregroundStyle(.white.opacity(0.85))
            Text("\(level)").font(.system(size: 44, weight: .black, design: .rounded)).monospacedDigit()
              .foregroundStyle(LinearGradient(colors: [.white, Color(red: 1, green: 0.93, blue: 0.7)], startPoint: .top, endPoint: .bottom))
              .shadow(color: c[0].opacity(0.8), radius: 10)
              .lineLimit(1).minimumScaleFactor(0.6)
          }
          .fixedSize(horizontal: true, vertical: false)
          HStack(spacing: 8) {
            Image(systemName: hot ? "flame.fill" : "play.fill").font(.system(size: 20, weight: .black))
            Text(level > 1 ? "Play" : "Start").font(.game(.title3, .black))
          }
          .foregroundStyle(Color(red: 0.2, green: 0.08, blue: 0.1))
          .frame(maxWidth: .infinity, minHeight: 60)
          .background {
            ZStack {
              Capsule().fill(LinearGradient(colors: hot ? Theme.hot : [Color(red: 1, green: 0.88, blue: 0.36), Theme.orange], startPoint: .top, endPoint: .bottom))
              Capsule().fill(.white.opacity(0.28)).padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 30)
              // A glint that sweeps across now and then.
              if !reduceMotion {
                LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                  .frame(width: 50).rotationEffect(.degrees(18))
                  .offset(x: shine ? 220 : -220)
                  .clipShape(Capsule())
              }
            }
            .clipShape(Capsule())
          }
          .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
          .shadow(color: (hot ? Theme.ember : Theme.sun).opacity(0.6), radius: 14, y: 4)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        ZStack {
          GeometryReader { g in BackdropFill(biome: biome, variant: world?.variant ?? 0, size: g.size, scale: scale) }
          AuroraTint(arena: biome).opacity(0.35)
          LinearGradient(colors: [.black.opacity(0.62), .black.opacity(0.25), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
      }
      .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
        .stroke(LinearGradient(colors: [c[0], c[1].opacity(0.5), c[2]], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
      .shadow(color: c[0].opacity(0.45), radius: 20, y: 6)
      .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
    .buttonStyle(PressStyle(scale: 0.96))
    .accessibilityLabel(level > 1 ? "Play level \(level)\(hot ? ", Overdrive" : "")" : "Play\(hot ? ", Overdrive" : "")")
    .accessibilityHint(infinite ? "Infinity" : [realm?.name, world?.name].compactMap { $0 }.joined(separator: ", "))
    .accessibilityIdentifier("play")
    .task {
      // A glint every few seconds, so the card reads as the thing to press.
      guard !reduceMotion else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1.4))
        withAnimation(.easeInOut(duration: 0.9)) { shine = true }
        try? await Task.sleep(for: .seconds(2.6))
        shine = false
      }
    }
  }

  private func kicker(realm: Realm?, world: World?, infinite: Bool) -> String {
    if infinite { return "BEYOND LEVEL \(Campaign.finalAuthored)" }
    guard let realm, let world else { return "UP NEXT" }
    return "REALM \(realm.number) · WORLD \(world.number)"
  }
}

/// Arcade as a strong second choice: its high score and where a run picks up.
struct ArcadeCard: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let p = app.progress
    let from = p.arcade.checkpoint
    Button { app.go(.arcade) } label: {
      ModeCard(symbol: "gamecontroller.fill", title: "Arcade",
               line: p.arcadeBest > 0 ? "Best \(ResultOverlay.short(p.arcadeBest))" : "Endless waves",
               badge: from > 1 ? "Wave \(from)" : nil,
               colors: [Theme.cyan, Color(red: 0.36, green: 0.4, blue: 1)], arena: .circuit)
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel(from > 1 ? "Arcade · wave \(from)" : "Arcade")
    .accessibilityHint(p.arcadeBest > 0 ? "High score \(p.arcadeBest)" : "")
    .accessibilityIdentifier("arcade")
  }
}

/// Today's Daily: one shared level a day, with your streak and whether today's is done.
struct DailyCard: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let best = app.progress.dailyBest[app.dailyKey]
    let streak = app.dailyStreak
    Button { app.go(.play(app.today())) } label: {
      ModeCard(symbol: best == nil ? "calendar" : "calendar.badge.checkmark", title: "Daily",
               line: best.map { $0 > 0 ? "Today \(ResultOverlay.short($0))" : "Try again" } ?? "New today",
               badge: streak > 0 ? "\(streak)🔥" : nil,
               colors: [Color(red: 1, green: 0.62, blue: 0.82), Color(red: 0.86, green: 0.3, blue: 0.62)], arena: .candy,
               dot: best == nil)
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel("Daily")
    .accessibilityValue(best == nil ? "New level today" : "Played today\(streak > 0 ? ", \(streak) day streak" : "")")
    .accessibilityIdentifier("daily")
  }
}

/// A square-ish mode card: an icon on its own colour, a title and one short line.
struct ModeCard: View {
  let symbol: String
  let title: String
  let line: String
  var badge: String? = nil
  let colors: [Color]
  let arena: Arena
  var dot = false
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        Image(systemName: symbol).font(.system(size: 22, weight: .black)).foregroundStyle(.white)
          .frame(width: 46, height: 46)
          .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)))
          .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.45), lineWidth: 1))
          .shadow(color: colors[0].opacity(0.6), radius: 8)
          .overlay(alignment: .topTrailing) {
            if dot { Circle().fill(Theme.sun).frame(width: 12, height: 12).overlay(Circle().stroke(Theme.night, lineWidth: 2)).offset(x: 4, y: -4) }
          }
        Spacer(minLength: 4)
        if let badge {
          Text(badge).font(.game(.caption, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(.black.opacity(0.45)))
            .overlay(Capsule().stroke(colors[0].opacity(0.7), lineWidth: 1))
        }
      }
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.game(.title3, .black)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
        Text(line).font(.game(.footnote, .heavy)).monospacedDigit().foregroundStyle(Theme.ink.opacity(0.92)).lineLimit(1).minimumScaleFactor(0.75)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
    .background {
      ZStack {
        Theme.panel.opacity(0.94)
        AuroraTint(arena: arena).opacity(0.45)
        LinearGradient(colors: [.clear, Theme.night.opacity(0.55)], startPoint: .top, endPoint: .bottom)
      }
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(LinearGradient(colors: [colors[0].opacity(0.9), colors[1].opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }
}

/// A small tile with an icon over a word, for the places you visit less.
struct HomeTile: View {
  let symbol: String
  let title: String
  let tint: Color
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: symbol).font(.system(size: 20, weight: .bold)).foregroundStyle(tint)
        Text(title).font(.game(.footnote, .heavy)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.75)
      }
      .frame(maxWidth: .infinity, minHeight: 64)
      .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel.opacity(0.88)))
      .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.panelEdge, lineWidth: 1))
      .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel(title)
  }
}

/// A number with its icon in a dark pill.
struct StatPill: View {
  let icon: AnyView
  let text: String
  let color: Color
  var body: some View {
    HStack(spacing: 5) {
      icon
      Text(text).font(.game(.subheadline, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
    }
    .padding(.horizontal, 11).frame(minHeight: 36)
    .background(Capsule().fill(Theme.night.opacity(0.7)))
    .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
    .accessibilityElement(children: .ignore)
  }
}

/// A round icon button at the full touch target.
struct RoundIcon: View {
  let symbol: String
  let label: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: symbol).font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
        .frame(width: Theme.target, height: Theme.target)
        .background(Circle().fill(Theme.panel.opacity(0.9))).overlay(Circle().stroke(Theme.panelEdge))
        .contentShape(Circle())
    }
    .buttonStyle(PressStyle(scale: 0.9))
    .accessibilityLabel(label)
  }
}

/// A slow bob, for things that should feel alive. Still under Reduce Motion.
struct Bob: ViewModifier {
  var amount: CGFloat = 6
  var period: Double = 3
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var up = false
  func body(content: Content) -> some View {
    content
      .offset(y: up ? -amount : amount)
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true)) { up = true }
      }
  }
}

/// Bubbles drifting up behind the home screen in three depths: far ones small, soft and slow, near ones big
/// and quicker, so the screen has parallax. One timeline at 30 fps, and nothing moves under Reduce Motion.
struct Floaters: View {
  let size: CGSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var phase
  private struct Item { let kind: BubbleKind; let x: Double; let start: Double; let depth: Int }
  private let items: [Item] = [
    Item(kind: .basic, x: 0.12, start: 0.15, depth: 2), Item(kind: .golden, x: 0.88, start: 0.05, depth: 2),
    Item(kind: .fast, x: 0.08, start: 0.7, depth: 1), Item(kind: .magnetic, x: 0.92, start: 0.55, depth: 2),
    Item(kind: .frozen, x: 0.55, start: 0.9, depth: 1), Item(kind: .basic, x: 0.3, start: 0.45, depth: 0),
    Item(kind: .repel, x: 0.72, start: 0.3, depth: 0), Item(kind: .basic, x: 0.45, start: 0.1, depth: 0),
    Item(kind: .armored, x: 0.2, start: 0.92, depth: 1),
  ]
  private static let sizes: [CGFloat] = [26, 42, 64]
  private static let speeds: [Double] = [0.006, 0.011, 0.018]
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || phase != .active)) { ctx in
      let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)
      ZStack {
        ForEach(items.indices, id: \.self) { i in
          let it = items[i]
          let s = Self.sizes[it.depth]
          let span = size.height + s * 2
          let y = (it.start - t * Self.speeds[it.depth]).truncatingRemainder(dividingBy: 1)
          let yy = (y < 0 ? y + 1 : y) * span - s
          let sway = sin(t * (0.4 + Double(it.depth) * 0.15) + Double(i) * 1.7) * (8 + Double(it.depth) * 6)
          ArtImage(item: .bubble(it.kind), size: s)
            .opacity([0.45, 0.7, 0.9][it.depth])
            .position(x: size.width * it.x + sway, y: yy)
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct BackBar: View {
  @Environment(AppModel.self) private var app
  let title: String
  var body: some View {
    HStack(spacing: 10) {
      Button { app.go(.home) } label: {
        Image(systemName: "chevron.left").font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
          .frame(width: Theme.target, height: Theme.target)
          .background(Circle().fill(Theme.panel)).overlay(Circle().stroke(Theme.panelEdge))
          .contentShape(Circle())
      }
      .buttonStyle(PressStyle(scale: 0.9))
      .accessibilityLabel("Back")
      Text(title).font(.game(.title2, .black)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
  }
}

// MARK: - Guide

struct GuideView: View {
  @Environment(AppModel.self) private var app
  @State private var open: String? = nil
  @State private var arrived = false
  var body: some View {
    ZStack {
      ArenaBackground(arena: .space)
      VStack(spacing: 0) {
        BackBar(title: "How to play")
        ScrollViewReader { scroller in
          ScrollView {
            VStack(spacing: 10) {
              ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) { heroCards }
                VStack(spacing: 10) { heroCards }
              }
              Fold(title: "Bubbles", note: "\(ActorKind.allCases.count)", id: "bubbles", open: $open) {
                IconGrid(items: ActorKind.allCases.map { k in .init(id: k.rawValue, title: k.title, blurb: k.blurb, detail: k.detail, art: .bubble(k.artKind)) })
              }
              Fold(title: "World twists", note: "\(Twist.allCases.count)", id: "twists", open: $open) { TwistGuide() }
              Fold(title: "Villains", note: "\(VillainKind.allCases.count)", id: "villains", open: $open) { VillainGuide() }
              Fold(title: "Power-ups", note: "\(PowerUp.allCases.count)", id: "powers", open: $open) {
                IconGrid(items: PowerUp.allCases.map { p in .init(id: p.rawValue, title: p.title, blurb: p.blurb, detail: p.detail, art: .power(p.artKind)) })
              }
              Fold(title: "Guest stars", note: "\(caughtCount) of \(Cameo.allCases.count) caught", id: "guests", open: $open) {
                IconGrid(items: Cameo.allCases.map { c in .init(id: c.rawValue, title: c.title, blurb: "Gives \(c.gift)", detail: "\(c.moves). “\(c.quip)”", art: .cameo(c.artKind), dimmed: !app.progress.hasCaught(c)) })
              }
              Fold(title: "Shields and meter", id: "meter", open: $open) { meterFacts }
              Fold(title: "Scoring", id: "score", open: $open) { scoreFacts }
              Fold(title: "Secrets", note: "\(app.progress.namedFound) of \(Secrets.named.count) · \(app.progress.nodsFound) nods", id: "secrets", open: $open) {
              Text("Every world hides one. So does a bubble in every level.").font(.game(.subheadline, .semibold)).foregroundStyle(Theme.muted)
              ForEach(Secrets.named) { s in
                let got = app.progress.found(s.id)
                HStack(alignment: .top, spacing: 10) {
                  Text(got ? s.emoji : "❔").font(.system(size: 26)).frame(width: 36)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(got ? s.title : "???").font(.game(.headline, .heavy)).foregroundStyle(got ? Theme.sun : Theme.muted)
                    Text(got ? s.line : s.hint).font(.game(.subheadline, .semibold)).foregroundStyle(Theme.ink.opacity(got ? 1 : 0.7))
                  }
                }
                .accessibilityElement(children: .combine)
              }
            }
            Fold(title: "On iPhone Duo", id: "duo", open: $open) {
                FactRow(art: .bubble(.golden), text: "A page lights up: faster bubbles, double points.")
                FactRow(art: .glyph(.starOn), text: "Pop across the fold for a crossfold combo.")
                FactRow(art: .glyph(.shieldOn), text: "Touch both pages by the fold at once to clap it.")
              }
              Fold(title: "Two players", id: "two", open: $open) {
                FactRow(art: .glyph(.shieldOn), text: "Lay it flat, face to face. The half nearest you is yours.")
                FactRow(art: .bubble(.fast), text: "What you miss lands on your rival.")
                FactRow(art: .glyph(.starOn), text: "Last shield standing wins. Otherwise, top score.")
              }
              Fold(title: "Replay a tour", id: "tour", open: $open) {
                ViewThatFits(in: .horizontal) {
                  HStack(spacing: 10) { soloTour; duoTour }
                  VStack(spacing: 10) { soloTour; duoTour }
                }
              }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
          }
          .onChange(of: open) { _, section in
            // Arriving from an update callout: bring the opened section into view.
            guard let section, arrived else { return }
            arrived = false
            withAnimation(.easeOut(duration: 0.3)) { scroller.scrollTo(section, anchor: .top) }
          }
        }
      }
    }
    .task {
      #if DEBUG
      if let fold = Debug.string("-fold") { open = fold }
      Debug.ready("root")
      #endif
      // An update callout can send you straight to its section.
      if let section = app.guideSection { arrived = true; open = section; app.guideSection = nil }
    }
  }

  private var caughtCount: Int { Cameo.allCases.filter { app.progress.hasCaught($0) }.count }
  private var soloTour: some View {
    Button("The full tour") {
      app.progress.seenTour = false
      app.route = .play(.campaign(app.progress.unlocked))
    }.buttonStyle(QuietStyle())
  }
  private var duoTour: some View {
    Button("Two-player tour") {
      app.progress.seenVersusTour = false
      app.route = .play(.versus)
    }.buttonStyle(QuietStyle())
  }

  /// The whole game in three pictures.
  @ViewBuilder private var heroCards: some View {
    HeroCard(arena: .classic, title: "Tap or swipe", caption: "Split them all") {
      HStack(spacing: 6) {
        ArtImage(item: .bubble(.basic), size: 66)
        Image(systemName: "arrow.right").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
        VStack(spacing: -6) { ArtImage(item: .bubble(.basic), size: 44); ArtImage(item: .bubble(.basic), size: 44) }
      }
    }
    HeroCard(arena: .neon, title: "Guard the line", caption: "A big one costs a shield") {
      ZStack {
        HingeLine(color: Theme.red)
        ArtImage(item: .bubble(.basic), size: 70).offset(y: -18)
        ArtImage(item: .glyph(.shieldOff), size: 30).offset(x: 54, y: 24)
      }
    }
    HeroCard(arena: .space, title: "Snap the hinge", caption: "Drag off the line to fling them back") {
      ZStack {
        HingeLine(color: Theme.sun)
        ArtImage(item: .bubble(.basic), size: 46).offset(x: -40, y: -24)
        ArtImage(item: .bubble(.basic), size: 34).offset(x: 42, y: 24)
        Image(systemName: "hand.point.up.left.fill").font(.system(size: 28)).foregroundStyle(.white).offset(x: 6, y: 12)
      }
    }
    HeroCard(arena: .forest, title: "Tiny = free", caption: "The line pops them for you") {
      ZStack {
        HingeLine(color: Theme.cyan)
        HStack(spacing: 2) { ArtImage(item: .bubble(.basic), size: 36); ArtImage(item: .bubble(.basic), size: 30).offset(y: 9); ArtImage(item: .bubble(.basic), size: 36) }
      }
    }
  }

  @ViewBuilder private var meterFacts: some View {
    FactRow(art: .glyph(.shieldOn), text: "3 shields. Lose them all and the level restarts.")
    HStack(spacing: 12) {
      ForEach(Array(zip([40.0, 30, 22], ["Full", "+2", "+1"])), id: \.1) { pair in
        VStack(spacing: 3) {
          ArtImage(item: .bubble(.basic), size: pair.0).frame(height: 44)
          Text(pair.1).font(.game(.subheadline, .heavy)).foregroundStyle(Theme.sun)
        }
      }
      Text("What each size adds when it crosses").font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
    }
    FactRow(art: .glyph(.starOn), text: "8 taps with no crossing wins a shield back.")
  }

  @ViewBuilder private var scoreFacts: some View {
    HStack(alignment: .bottom, spacing: 12) {
      ForEach(Array(zip([56.0, 42, 30, 22], [100, 200, 300, 500])), id: \.1) { pair in
        VStack(spacing: 4) {
          ArtImage(item: .bubble(.basic), size: pair.0)
          Text("\(pair.1)").font(.game(.footnote, .heavy)).foregroundStyle(Theme.ink)
        }
      }
    }
    FactRow(art: .bubble(.golden), text: "Keep tapping: combo goes up to x10.")
    FactRow(art: .glyph(.starOn), text: "No crossings: +25%.")
  }
}

/// A bright card for one of the few things worth remembering. Picture first, then at most a few words.
private struct HeroCard<Art: View>: View {
  let arena: Arena
  let title: String
  let caption: String
  @ViewBuilder var art: Art
  @Environment(\.horizontalSizeClass) private var width
  var body: some View {
    AuroraSpot(arena: arena) {
      Group {
        if width == .compact {
          // On a phone each card is one short row, so the sections below stay on screen.
          HStack(spacing: 12) {
            art.frame(width: 118, height: 74).scaleEffect(0.74)
            words(alignment: .leading)
          }
        } else {
          VStack(spacing: 8) {
            art.frame(height: 104).frame(maxWidth: .infinity)
            words(alignment: .center)
          }
          .frame(minWidth: 165, maxWidth: .infinity)
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(title). \(caption).")
  }
  private func words(alignment: HorizontalAlignment) -> some View {
    VStack(alignment: alignment, spacing: 1) {
      Text(title).font(.game(.headline, .black)).foregroundStyle(.white)
      Text(caption).font(.game(.footnote, .semibold)).foregroundStyle(.white.opacity(0.95)).fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 10).padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black.opacity(0.45)))
  }
}

private struct HingeLine: View {
  let color: Color
  var body: some View {
    Capsule().fill(.white).frame(height: 3).shadow(color: color, radius: 9).shadow(color: color, radius: 16)
      .frame(maxWidth: 220)
  }
}

private struct FactRow: View {
  let art: ArtImage.Item
  let text: String
  var body: some View {
    HStack(spacing: 12) {
      ArtImage(item: art, size: 36)
      Text(text).font(.game(.subheadline, .semibold)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(.vertical, 3)
  }
}

/// Icons with a few words. Tapping one reveals the full explanation in place.
private struct IconGrid: View {
  struct Item: Identifiable {
    let id: String, title: String, blurb: String, detail: String
    let art: ArtImage.Item
    var dimmed = false
  }
  let items: [Item]
  @State private var chosen: String?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .top)], spacing: 8) {
      ForEach(items) { item in
        Button {
          withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { chosen = chosen == item.id ? nil : item.id }
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              ArtImage(item: item.art, size: 52).opacity(item.dimmed ? 0.55 : 1)
              VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.game(.subheadline, .heavy)).foregroundStyle(Theme.ink).lineLimit(2).minimumScaleFactor(0.85)
                Text(item.blurb).font(.game(.caption, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
              }
            }
            if chosen == item.id {
              Text(item.detail).font(.game(.footnote, .medium)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            }
          }
          .frame(maxWidth: .infinity, minHeight: Theme.target, alignment: .leading)
          .padding(8)
          .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(chosen == item.id ? Theme.cyan.opacity(0.14) : .white.opacity(0.04)))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows more")
      }
    }
  }
}

struct GuideBlock<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.game(.headline, .black)).foregroundStyle(Theme.sun)
      content
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel.opacity(0.92)))
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.panelEdge.opacity(0.7)))
  }
}

struct GuideRow<Art: View>: View {
  let title: String
  let detail: String
  @ViewBuilder var art: Art
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      art
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.game(.headline, .black)).foregroundStyle(Theme.ink)
        Text(detail).font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel.opacity(0.92)))
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.panelEdge.opacity(0.7)))
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Settings

struct SettingsRows: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    @Bindable var model = app
    VStack(spacing: 2) {
      Toggle("Swipe to slice", isOn: $model.progress.flick).toggleStyle(GameToggle(detail: "One swipe hits every bubble it crosses and aims the pieces. A plain tap then fires when you lift your finger. Off: every touch hits the moment you land."))
      Toggle("Hinge grace", isOn: $model.progress.hingeGrace).toggleStyle(GameToggle(detail: "Pieces from a hinge split get pushed clear of the line for 0.6 seconds."))
      Toggle("Sound", isOn: $model.progress.sound).toggleStyle(GameToggle(detail: "Short blips. The ring/silent switch also mutes them."))
      Toggle("Haptics", isOn: $model.progress.haptics).toggleStyle(GameToggle(detail: "Taps on pops, a crack on snaps, a thud for shields and a heartbeat on your last one."))
    }
    .onChange(of: app.progress.sound) { _, _ in app.applySettings() }
    .onChange(of: app.progress.haptics) { _, _ in app.applySettings() }
  }
}

/// 0.4.1: the usage counts the game sends, and the one switch that stops them (off deletes the queue and the id).
struct PrivacyRows: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    @Bindable var model = app
    VStack(alignment: .leading, spacing: 6) {
      Toggle("Share usage stats", isOn: $model.progress.usage)
        .toggleStyle(GameToggle(detail: "Counts like a level started or finished, with its level, score and time, and a random id made on this device. No name, location or advertising id. Off sends nothing and deletes the id."))
        .accessibilityIdentifier("usage")
      Link("Privacy policy", destination: URL(string: "https://mutaafaziz.com/hingepop/privacy/")!)
        .font(.game(.footnote, .bold)).foregroundStyle(Theme.cyan).frame(minHeight: Theme.target)
    }
    .onChange(of: app.progress.usage) { _, v in Usage.shared.setOn(v) }
  }
}

struct GameToggle: ToggleStyle {
  let detail: String
  func makeBody(configuration: Configuration) -> some View {
    Toggle(isOn: configuration.$isOn) {
      VStack(alignment: .leading, spacing: 1) {
        configuration.label.font(.game(.subheadline, .bold)).foregroundStyle(Theme.ink)
        Text(detail).font(.game(.caption, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
      }
    }
    .toggleStyle(.switch)
    .tint(Theme.cyan)
    .frame(minHeight: Theme.target)
  }
}

struct SettingsView: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    ZStack {
      ArenaBackground(arena: app.progress.arena ?? .classic)
      VStack(spacing: 0) {
        BackBar(title: "Settings")
        ScrollView {
          VStack(spacing: 12) {
            GuideBlock(title: "Difficulty") { DifficultySwitch() }
            GuideBlock(title: "Play") { SettingsRows() }
            GuideBlock(title: "Backdrop") {
              Text("Every world has its own. Pick one to use everywhere, or follow the world. New ones open as you travel.").font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10, alignment: .top)], spacing: 12) {
                ArenaChoice(arena: nil)
                ForEach(Arena.allCases, id: \.self) { ArenaChoice(arena: $0) }
              }
            }
            GuideBlock(title: "Trail") { TrailPicker() }
            GuideBlock(title: "Your records") {
              Text("Stars: \(app.progress.totalStars). Challenges: \(app.progress.mastery) of \(Challenges.total). S grades: \(app.progress.sGrades). Overdrive clears: \(app.progress.overdriveClears). Arcade best: \(app.progress.arcadeBest.formatted()). Today's daily best: \((app.progress.dailyBest[app.dailyKey] ?? 0).formatted()).")
                .font(.game(.subheadline, .medium)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
              Text("Your progress stays on this device. There is no account, and no ads.").font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
            GuideBlock(title: "Privacy") { PrivacyRows() }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 28)
          .frame(maxWidth: 620)
          .frame(maxWidth: .infinity)
        }
      }
    }
    #if DEBUG
    .task { Debug.ready("root") }
    #endif
  }
}

struct ArenaChoice: View {
  @Environment(AppModel.self) private var app
  @Environment(\.displayScale) private var scale
  let arena: Arena?
  var body: some View {
    let chosen = app.progress.arena == arena
    let open = arena.map { app.progress.arenaOpen($0) } ?? true
    let opensIn = arena.flatMap { app.progress.firstWorld(using: $0) }
    Button { app.progress.arena = arena } label: {
      VStack(spacing: 5) {
        ZStack {
          if let a = arena {
            GeometryReader { g in BackdropFill(biome: a, size: g.size, scale: scale) }
              .saturation(open ? 1 : 0.15)
              .overlay(open ? Color.clear : Color.black.opacity(0.45))
          } else {
            LinearGradient(colors: [Theme.violet.opacity(0.7), Theme.cyan.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text("Auto").font(.game(.headline, .black)).foregroundStyle(Theme.ink)
          }
          if !open { ArtImage(item: .glyph(.lock), size: 26) }
          if chosen {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(.white, Theme.cyan)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(5)
          }
        }
        .frame(height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(chosen ? Theme.cyan : .white.opacity(0.2), lineWidth: chosen ? 3 : 1))
        Text(arena?.backdropName ?? "Follow world").font(.game(.caption, .bold)).foregroundStyle(open ? Theme.ink : Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
        if !open, let w = opensIn {
          Text("World \(w.number)").font(.game(.caption2, .semibold)).foregroundStyle(Theme.muted).lineLimit(1)
        }
      }
      .frame(minHeight: Theme.target)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!open)
    .accessibilityLabel("\(arena?.backdropName ?? "Follow the world") backdrop\(open ? "" : ", locked, opens in world \(opensIn?.number ?? 0), \(opensIn?.name ?? "")")\(chosen ? ", selected" : "")")
  }
}

/// Swipe trails won with world medals. Cosmetic only: they never change play, and they're never sold.
struct TrailPicker: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let won = Trails.won(app.progress)
    if won.isEmpty {
      HStack(spacing: 10) {
        Image(systemName: "medal").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.sun)
        Text("Earn all 30 challenges in a world for its medal and a new swipe trail.").font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
      }
    } else {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10, alignment: .top)], spacing: 10) {
        swatch(nil)
        ForEach(won, id: \.self) { swatch($0) }
      }
    }
  }

  private func swatch(_ arena: Arena?) -> some View {
    let chosen = Trails.current(app.progress) == arena
    let colors = arena?.aurora ?? [Theme.violet, Theme.cyan, Theme.sun]
    return Button { app.progress.trail = arena?.rawValue } label: {
      VStack(spacing: 4) {
        Capsule().fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
          .frame(height: 16).shadow(color: colors[0].opacity(0.8), radius: 6)
          .padding(.horizontal, 6).frame(height: 36)
          .overlay(Capsule().stroke(chosen ? Theme.cyan : .clear, lineWidth: 2.5))
        Text(arena?.backdropName ?? "World").font(.game(.caption, .bold)).foregroundStyle(Theme.ink)
      }
      .frame(minHeight: Theme.target)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(arena?.backdropName ?? "World") trail\(chosen ? ", selected" : "")")
  }
}
