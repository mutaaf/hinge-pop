import SwiftUI
import HingePopArt
import HingePopCore

@main
struct HingePopApp: App {
  @State private var app = AppModel()
  @State private var duo = DuoModel()
  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(app)
        .environment(duo)
        .modifier(TracksHinge(duo: duo))
        .preferredColorScheme(.dark)
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    Group {
      switch app.route {
      case .home: HomeView()
      case .map: MapView()
      case .guide: GuideView()
      case .settings: SettingsView()
      case .play(let mode): PlayView(mode: mode, app: app).id(String(describing: mode))
      }
    }
    .animation(.easeInOut(duration: 0.2), value: app.route)
    .statusBarHidden(isPlaying)
    .persistentSystemOverlays(isPlaying ? .hidden : .automatic)
    #if DEBUG
    .task {
      guard Debug.has("-landscape"), let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
      scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    }
    #endif
  }
  private var isPlaying: Bool { if case .play = app.route { true } else { false } }
}

// MARK: - Home

struct HomeView: View {
  @Environment(AppModel.self) private var app
  @Environment(DuoModel.self) private var duo
  var body: some View {
    GeometryReader { proxy in
      let fold = foldRect(proxy, duo: duo)
      ZStack {
        ArenaBackground(arena: .neon)
        Floaters(size: proxy.size)
        if let fold, fold.height >= fold.width, proxy.size.width > 560 {
          // A book: the title on the leading page and the buttons on the trailing page, with the fold between.
          HStack(spacing: 0) {
            title(width: fold.minX - 48).frame(width: fold.minX)
            Color.clear.frame(width: fold.width)
            buttons(wide: false).padding(.horizontal, 20).frame(maxWidth: .infinity)
          }
        } else if proxy.size.width > proxy.size.height {
          HStack(spacing: 24) {
            title(width: min(proxy.size.width * 0.42, 460))
            buttons(wide: false).frame(maxWidth: 420)
          }
          .padding(.horizontal, 24)
        } else {
          ScrollView {
            VStack(spacing: 18) {
              title(width: min(proxy.size.width - 64, 460))
              buttons(wide: false).frame(maxWidth: 460)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: proxy.size.height)
          }
          .scrollBounceBehavior(.basedOnSize)
        }
      }
      #if DEBUG
      .task { Debug.ready("root") }
      #endif
    }
  }

  private func title(width: CGFloat) -> some View {
    VStack(spacing: 8) {
      AuroraAssemble(item: .logo, size: max(160, width), count: 1600)
        .accessibilityElement()
        .accessibilityLabel("Hinge Pop")
      Text("POP · SPLIT · CHAIN · CLEAR").font(.game(.subheadline, .heavy)).foregroundStyle(Theme.ink)
      if app.progress.totalStars > 0 {
        HStack(spacing: 4) {
          ArtImage(item: .glyph(.starOn), size: 20)
          Text("\(app.progress.totalStars)").font(.game(.subheadline, .heavy)).monospacedDigit().foregroundStyle(Theme.sun)
        }
        .accessibilityElement().accessibilityLabel("\(app.progress.totalStars) stars")
      }
    }
  }

  private func buttons(wide: Bool) -> some View {
    VStack(spacing: 10) {
      Button(app.progress.unlocked > 1 ? "Play level \(app.progress.unlocked)" : "Play") {
        app.route = .play(.campaign(app.progress.unlocked))
      }
      .buttonStyle(ChunkyStyle())
      Button("Level map") { app.route = .map }.buttonStyle(QuietStyle())
      HStack(spacing: 10) {
        Button("Arcade") { app.route = .play(.arcade(seed: UInt64(Date().timeIntervalSince1970))) }.buttonStyle(QuietStyle())
        Button("Daily") { app.route = .play(app.today()) }.buttonStyle(QuietStyle())
      }
      Button("2 Players") { app.route = .play(.versus) }.buttonStyle(QuietStyle())
      HStack(spacing: 10) {
        Button("How to play") { app.route = .guide }.buttonStyle(QuietStyle())
        Button("Settings") { app.route = .settings }.buttonStyle(QuietStyle())
      }
    }
  }
}

/// A few bubbles bobbing behind the home screen.
struct Floaters: View {
  let size: CGSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var up = false
  private let items: [(BubbleKind, CGFloat, CGFloat, CGFloat)] = [(.basic, 0.14, 0.14, 70), (.golden, 0.86, 0.1, 60), (.fast, 0.1, 0.86, 54), (.magnetic, 0.88, 0.84, 76), (.frozen, 0.5, 0.94, 44)]
  var body: some View {
    ZStack {
      ForEach(items.indices, id: \.self) { i in
        let it = items[i]
        ArtImage(item: .bubble(it.0), size: it.3)
          .position(x: size.width * it.1, y: size.height * it.2)
          .offset(y: up ? -10 - CGFloat(i) * 2 : 10 + CGFloat(i) * 2)
          .opacity(0.86)
      }
    }
    .accessibilityHidden(true)
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { up = true }
    }
  }
}

struct BackBar: View {
  @Environment(AppModel.self) private var app
  let title: String
  var body: some View {
    HStack(spacing: 10) {
      Button { app.route = .home } label: {
        Image(systemName: "chevron.left").font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
          .frame(width: Theme.target, height: Theme.target)
          .background(Circle().fill(Theme.panel)).overlay(Circle().stroke(Theme.panelEdge))
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Back")
      Text(title).font(.game(.title2, .black)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
  }
}

// MARK: - Map

struct MapView: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    ZStack {
      ArenaBackground(arena: .classic)
      VStack(spacing: 0) {
        BackBar(title: "Level map")
        ScrollViewReader { reader in
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
              ForEach(Campaign.chapters, id: \.number) { ChapterView(chapter: $0).id($0.number) }
              InfinityRow()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
          }
          .onAppear { reader.scrollTo(Campaign.chapter(of: min(50, app.progress.unlocked)).number, anchor: .top) }
        }
      }
    }
    #if DEBUG
    .task { Debug.ready("root") }
    #endif
  }
}

struct ChapterView: View {
  @Environment(AppModel.self) private var app
  let chapter: Chapter
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text("CHAPTER \(chapter.number)").font(.game(.caption, .heavy)).foregroundStyle(Theme.sun)
        Text(chapter.title).font(.game(.title3, .black)).foregroundStyle(Theme.ink)
        Text(chapter.teaches).font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 8)], spacing: 10) {
        ForEach(Array(chapter.levels), id: \.self) { LevelNode(level: $0) }
      }
    }
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.panel.opacity(0.88)))
    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.panelEdge.opacity(0.7), lineWidth: 1))
  }
}

struct LevelNode: View {
  @Environment(AppModel.self) private var app
  let level: Int
  var body: some View {
    let open = app.progress.isOpen(level)
    let stars = app.progress.stars[level] ?? 0
    let boss = Campaign.level(level).isBoss
    let current = level == app.progress.unlocked
    Button { app.route = .play(.campaign(level)) } label: {
      VStack(spacing: 2) {
        ZStack {
          Circle().fill(LinearGradient(colors: boss ? [Theme.red, Color(red: 0.45, green: 0.1, blue: 0.5)] : [Theme.panelEdge, Theme.panel], startPoint: .top, endPoint: .bottom))
          Circle().stroke(current ? Theme.cyan : .white.opacity(0.25), lineWidth: current ? 3 : 1)
          if open {
            Text("\(level)").font(.game(.headline, .black)).monospacedDigit().foregroundStyle(Theme.ink)
          } else {
            ArtImage(item: .glyph(.lock), size: 24)
          }
        }
        .frame(width: 50, height: 50)
        HStack(spacing: 1) {
          ForEach(0..<3, id: \.self) { i in ArtImage(item: .glyph(i < stars ? .starOn : .starOff), size: 13) }
        }
        .opacity(open ? 1 : 0.35)
      }
      .frame(minWidth: 60, minHeight: 72)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!open)
    .accessibilityLabel(open ? "Level \(level)\(boss ? ", boss" : ""), \(stars) of 3 stars" : "Level \(level), locked")
  }
}

struct InfinityRow: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let open = app.progress.unlocked > Campaign.finalAuthored
    Button { app.route = .play(.campaign(max(51, app.progress.unlocked))) } label: {
      HStack(spacing: 12) {
        Text("∞").font(.system(.largeTitle, design: .rounded, weight: .black)).foregroundStyle(Theme.cyan)
        VStack(alignment: .leading, spacing: 2) {
          Text("Infinity").font(.game(.title3, .black)).foregroundStyle(Theme.ink)
          Text(open ? "Generated levels that keep climbing. You are on level \(max(51, app.progress.unlocked))." : "Generated levels that keep climbing. Clear level 50 to open it.")
            .font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
        }
        Spacer()
        if !open { ArtImage(item: .glyph(.lock), size: 26) }
      }
      .padding(14)
      .frame(maxWidth: .infinity, minHeight: Theme.target)
      .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.panel.opacity(0.88)))
      .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.panelEdge.opacity(0.7), lineWidth: 1))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!open)
  }
}

// MARK: - Guide

struct GuideView: View {
  @Environment(AppModel.self) private var app
  @State private var open: String? = nil
  var body: some View {
    ZStack {
      ArenaBackground(arena: .space)
      VStack(spacing: 0) {
        BackBar(title: "How to play")
        ScrollView {
          VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
              HStack(alignment: .top, spacing: 10) { heroCards }
              VStack(spacing: 10) { heroCards }
            }
            Fold(title: "Bubbles", note: "\(ActorKind.allCases.count)", id: "bubbles", open: $open) {
              IconGrid(items: ActorKind.allCases.map { k in .init(id: k.rawValue, title: k.title, blurb: k.blurb, detail: k.detail, art: .bubble(k.artKind)) })
            }
            Fold(title: "Power-ups", note: "\(PowerUp.allCases.count)", id: "powers", open: $open) {
              IconGrid(items: PowerUp.allCases.map { p in .init(id: p.rawValue, title: p.title, blurb: p.blurb, detail: p.detail, art: .power(p.artKind)) })
            }
            Fold(title: "Guest stars", note: "\(caughtCount) of \(Cameo.allCases.count) caught", id: "guests", open: $open) {
              IconGrid(items: Cameo.allCases.map { c in .init(id: c.rawValue, title: c.title, blurb: "Gives \(c.gift)", detail: "\(c.moves). “\(c.quip)”", art: .cameo(c.artKind), dimmed: !app.progress.hasCaught(c)) })
            }
            Fold(title: "Shields and meter", id: "meter", open: $open) { meterFacts }
            Fold(title: "Scoring", id: "score", open: $open) { scoreFacts }
            Fold(title: "Two players", id: "two", open: $open) {
              FactRow(art: .glyph(.shieldOn), text: "One side each. Touches stay on your side.")
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
      }
    }
    #if DEBUG
    .task {
      open = Debug.string("-fold")
      Debug.ready("root")
    }
    #endif
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
          .frame(minWidth: 210, maxWidth: .infinity)
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
      Toggle("Haptics", isOn: $model.progress.haptics).toggleStyle(GameToggle(detail: "Light taps on pops and a firm one on crossings."))
    }
    .onChange(of: app.progress.sound) { _, _ in app.applySettings() }
    .onChange(of: app.progress.haptics) { _, _ in app.applySettings() }
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
            GuideBlock(title: "Play") { SettingsRows() }
            GuideBlock(title: "Backdrop") {
              Text("Each chapter has its own arena. Pick one to use everywhere, or follow the chapter.").font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                ArenaChoice(arena: nil)
                ForEach(Arena.allCases, id: \.self) { ArenaChoice(arena: $0) }
              }
            }
            GuideBlock(title: "Your records") {
              Text("Stars: \(app.progress.totalStars). Arcade best: \(app.progress.arcadeBest.formatted()). Today's daily best: \((app.progress.dailyBest[app.dailyKey] ?? 0).formatted()).")
                .font(.game(.subheadline, .medium)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
              Text("Everything stays on this device. There is no account, and no ads.").font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
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
    Button { app.progress.arena = arena } label: {
      VStack(spacing: 4) {
        ZStack {
          if let a = arena, let art = ArenaKind(rawValue: a.rawValue) {
            Image(decorative: Art.arena(art, size: CGSize(width: 130, height: 70), scale: scale), scale: scale)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          } else {
            RoundedRectangle(cornerRadius: 12).fill(Theme.panelEdge.opacity(0.4)).frame(height: 70)
            Text("Auto").font(.game(.headline, .black)).foregroundStyle(Theme.ink)
          }
          if !open { ArtImage(item: .glyph(.lock), size: 28) }
          RoundedRectangle(cornerRadius: 12).stroke(chosen ? Theme.cyan : .white.opacity(0.2), lineWidth: chosen ? 3 : 1)
        }
        .frame(height: 70)
        Text(arena?.rawValue.capitalized ?? "Follow chapter").font(.game(.caption, .bold)).foregroundStyle(Theme.ink)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!open)
    .accessibilityLabel("\(arena?.rawValue.capitalized ?? "Follow the chapter") backdrop\(open ? "" : ", locked")\(chosen ? ", selected" : "")")
  }
}
