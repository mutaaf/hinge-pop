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
        Button("Bubble Guide") { app.route = .guide }.buttonStyle(QuietStyle())
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
  var body: some View {
    ZStack {
      ArenaBackground(arena: .space)
      VStack(spacing: 0) {
        BackBar(title: "Bubble Guide")
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], spacing: 12) {
            GuideBlock(title: "The rules") {
              VStack(alignment: .leading, spacing: 8) {
                ForEach(rules, id: \.self) { Text($0).font(.game(.subheadline, .medium)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true) }
              }
            }
            GuideBlock(title: "Sizes") {
              HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(zip([64.0, 46, 32, 24], [100, 200, 300, 500])), id: \.1) { pair in
                  VStack(spacing: 4) {
                    ArtImage(item: .bubble(.basic), size: pair.0)
                    Text("\(pair.1)").font(.game(.footnote, .heavy)).foregroundStyle(Theme.ink)
                  }
                }
              }
              Text("Smaller is lighter, faster and bouncier. Each tap is worth that many points, times your combo.").font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(ActorKind.allCases, id: \.self) { k in
              GuideRow(title: k.title, detail: k.detail) { ArtImage(item: .bubble(k.artKind), size: 72) }
            }
            ForEach(PowerUp.allCases, id: \.self) { p in
              GuideRow(title: p.title, detail: p.detail) { ArtImage(item: .power(p.artKind), size: 60) }
            }
            GuideBlock(title: "Replay a tour") {
              Button("The full tour") {
                app.progress.seenTour = false
                app.route = .play(.campaign(app.progress.unlocked))
              }.buttonStyle(QuietStyle())
              Button("Two-player tour") {
                app.progress.seenVersusTour = false
                app.route = .play(.versus)
              }.buttonStyle(QuietStyle())
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 28)
          .frame(maxWidth: 1000)
          .frame(maxWidth: .infinity)
        }
      }
    }
    #if DEBUG
    .task { Debug.ready("root") }
    #endif
  }
  private let rules = [
    "Tap a bubble to split it, or swipe to hit every bubble in a line. Clear every bubble to win.",
    "Popping a tiny bubble sets off every tiny bubble close to it.",
    "A larger bubble that crosses the hinge charges your overload meter. A full meter costs a shield.",
    "The smallest bubbles pop on the hinge for free.",
    "Tap 8 times in a row with no crossing to win a shield back.",
    "2 Players: each player owns one side. A crossing charges whoever let it through and lands on the other side.",
  ]
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
