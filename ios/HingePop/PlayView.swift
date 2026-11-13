import SwiftUI
import SpriteKit
import HingePopArt
import HingePopCore

struct SpotFrames: PreferenceKey {
  static let defaultValue: [SpotTarget: CGRect] = [:]
  static func reduce(value: inout [SpotTarget: CGRect], nextValue: () -> [SpotTarget: CGRect]) { value.merge(nextValue()) { $1 } }
}
extension View {
  func spotFrame(_ target: SpotTarget) -> some View {
    background(GeometryReader { p in Color.clear.preference(key: SpotFrames.self, value: [target: p.frame(in: .named("play"))]) })
  }
}

/// A game in progress: the arena, the SpriteKit layer, the HUD and whatever sits on top.
struct PlayView: View {
  @Environment(AppModel.self) private var app
  @Environment(DuoModel.self) private var duo
  @Environment(\.displayScale) private var displayScale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var phase
  @State private var session: Session
  @State private var scene: GameScene?
  @State private var spots: [SpotTarget: CGRect] = [:]

  init(mode: GameMode, app: AppModel) { _session = State(initialValue: Session(mode: mode, app: app)) }

  private func applyInsets(_ proxy: GeometryProxy) {
    let i = proxy.safeAreaInsets
    scene?.insets = UIEdgeInsets(top: i.top, left: i.leading, bottom: i.bottom, right: i.trailing)
    #if DEBUG
    session.debugLeft = i.leading; session.debugTop = i.top
    #endif
  }

  var body: some View {
    GeometryReader { proxy in
      let fold = foldRect(proxy, duo: duo)
      ZStack(alignment: .top) {
        if let scene {
          SpriteView(scene: scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
            .ignoresSafeArea()
            .accessibilityLabel("Game arena. Tap bubbles to split them.")
        }
        if session.versus {
          VersusHUD(session: session, size: proxy.size, fold: fold)
        } else {
          VStack(spacing: 4) {
            HUDView(session: session)
            if let left = session.bossLeft { BossBar(left: left) { session.openTip(session.tipBoss()) } }
            EffectRow(session: session)
          }
          ToastView(toast: session.toast)
            .padding(.top, session.hudHeight + (session.bossLeft == nil ? 16 : 44))
        }
        overlays(size: proxy.size, fold: fold)
        #if DEBUG
        if Debug.has("-probe") {
          Text(session.probe).font(.system(size: 1)).opacity(0.02).allowsHitTesting(false)
            .accessibilityIdentifier("probe").accessibilityLabel(session.probe)
            .frame(width: 2, height: 2).position(x: 1, y: 1)
        }
        #endif
      }
      .coordinateSpace(name: "play")
      .onPreferenceChange(SpotFrames.self) { spots = $0 }
      .onAppear {
        if scene == nil {
          let s = GameScene(scale: displayScale)
          s.session = session
          s.reduceMotion = reduceMotion
          s.hingeGlow = { [duo] in MainActor.assumeIsolated { duo.glow } }
          scene = s
        }
        session.layout(size: proxy.size, fold: fold)
        applyInsets(proxy)
      }
      .onChange(of: proxy.size) { _, new in session.layout(size: new, fold: fold); applyInsets(proxy) }
      .onChange(of: proxy.safeAreaInsets) { _, _ in applyInsets(proxy) }
      .onChange(of: fold) { _, new in session.layout(size: proxy.size, fold: new) }
    }
    .onChange(of: phase) { _, new in if new != .active { session.pause() } }
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    .background(Theme.night.ignoresSafeArea())
    #if DEBUG
    .task {
      Debug.ready("root")
      if let t = Debug.string("-tip") {
        try? await Task.sleep(for: .seconds(1.4))
        switch t {
        case "shields": session.openTip(session.tipShields(0))
        case "score": session.openTip(session.tipScore(0))
        default: session.openTip(session.tipMeter(0))
        }
        Debug.ready("tip")
      }
    }
    #endif
  }

  @ViewBuilder
  private func overlays(size: CGSize, fold: CGRect?) -> some View {
    if let tip = session.tip {
      // A two-player tip turns to face whoever asked.
      SeatTurn(degrees: tip.seat.map { session.seatDegrees($0) } ?? 0) {
        TipOverlay(tip: tip) { session.tip = nil }
      }
    }
    switch session.overlay {
    case .none: EmptyView()
    case .paused: if session.versus { VersusPauseOverlay(session: session) } else { PauseOverlay(session: session) }
    case .result: if session.versus { VersusResultOverlay(session: session) } else { ResultOverlay(session: session) }
    case .meet(let kind): MeetOverlay(kind: kind) { session.dismissMeet() }
    case .world(let n): if let w = Worlds.world(n) { WorldIntroOverlay(world: w) { session.dismissWorld() } }
    case .tour: TourOverlay(session: session, spots: spots, size: size, fold: fold)
    }
  }
}

/// Every screen sits on this: the arena's art with a living aurora over it.
struct ArenaBackground: View {
  let arena: Arena
  /// Which take on the biome (`LevelSpec.variant`, 0-3): time of day, weather and curtain colours.
  var variant = 0
  var heat: Double = 0
  var alwaysOn = false
  var strength = 0.42
  /// Just the art, for behind the game scene, which draws its own sky.
  var still = false
  @Environment(\.displayScale) private var scale
  var body: some View {
    ZStack {
      GeometryReader { p in
        if let art = ArenaKind(rawValue: arena.rawValue), p.size.width > 1, p.size.height > 1 {
          Image(decorative: Art.arena(art, variant: variant, size: p.size, scale: scale), scale: scale)
        }
      }
      .ignoresSafeArea()
      if !still { AuroraField(arena: arena, variant: variant, heat: heat, strength: strength, alwaysOn: alwaysOn) }
    }
    .background(Theme.night.ignoresSafeArea())
  }
}

// MARK: - HUD

struct HUDView: View {
  let session: Session
  @Environment(\.horizontalSizeClass) private var hClass

  var body: some View {
    let foldX = session.verticalFoldX
    // `game` isn't observed; reading `generation` redraws this when a new one starts.
    let hot = session.generation >= 0 && session.overdrive
    HStack(spacing: 8) {
      PlayerCluster(session: session, index: 0)
      if session.versus {
        Spacer(minLength: 2)
        if foldX == nil { pause }
        Spacer(minLength: 2)
        PlayerCluster(session: session, index: 1)
      }
      // On a fold nothing sits on the crease, so the button moves to the trailing edge.
      if !session.versus || foldX != nil { pause }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Theme.night.opacity(0.78))
    .background {
      // Overdrive warms the HUD from below.
      if hot { LinearGradient(colors: [.clear, Theme.ember.opacity(0.3)], startPoint: .top, endPoint: .bottom) }
    }
    .overlay(alignment: .bottom) {
      Rectangle().fill(hot ? AnyShapeStyle(LinearGradient(colors: [Theme.orange.opacity(0.2), Theme.orange, Theme.orange.opacity(0.2)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Theme.panelEdge.opacity(0.6)))
        .frame(height: hot ? 2 : 1)
    }
    .background(GeometryReader { p in
      Color.clear.onChange(of: p.size.height, initial: true) { _, h in session.hudHeight = h }
    })
    .spotFrame(.hud)
  }

  private var pause: some View {
    Button { session.pause() } label: {
      ArtImage(item: .glyph(.pause), size: 40).frame(width: Theme.target, height: Theme.target).contentShape(Rectangle())
    }
    .accessibilityLabel("Pause")
    .buttonStyle(.plain)
  }
}

struct PlayerCluster: View {
  let session: Session
  let index: Int
  /// Two-player face-off: this player's own scoreboard at their own edge, read the normal way round.
  var seated = false
  @Environment(\.horizontalSizeClass) private var hClass
  private var mirrored: Bool { index == 1 && !seated }
  /// Player 1 wears the game's cyan, Player 2 the warm peach, wherever they sit.
  private var peach: Bool { seated ? index == 0 : mirrored }
  private var compact: Bool { session.versus && hClass == .compact && !seated }
  private var who: String { session.versus ? Seat.name(index) : "Your" }
  private var hud: PlayerHUD { session.hud.indices.contains(index) ? session.hud[index] : PlayerHUD() }
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var crackedIndex: Int?
  @State private var joltAmount: CGFloat = 0

  var body: some View {
    Group {
      if seated {
        HStack(spacing: 10) {
          shields
          meter.frame(maxWidth: 220)
          Spacer(minLength: 2)
          score
        }
      } else if compact {
        VStack(spacing: 2) {
          HStack(spacing: 6) { shields; Spacer(minLength: 2); score }
            .environment(\.layoutDirection, mirrored ? .rightToLeft : .leftToRight)
          meter
        }
      } else {
        HStack(spacing: 10) {
          shields
          meter.frame(maxWidth: session.versus ? 200 : 260)
          if !session.versus { Spacer(minLength: 4) }
          score
        }
        .environment(\.layoutDirection, mirrored ? .rightToLeft : .leftToRight)
      }
    }
  }

  private var maxShields: Int { session.game?.tuning.shields ?? 3 }
  private var streakMax: Double { Double(session.game?.tuning.rechargeStreak ?? 8) }

  private var shields: some View {
    Button { session.openTip(session.tipShields(index)) } label: {
      VStack(spacing: 5) {
        HStack(spacing: 2) {
          ForEach(0..<maxShields, id: \.self) { i in
            ShieldIcon(on: i < hud.shields, cracked: i == crackedIndex, danger: hud.shields == 1 && i == 0 && !session.versus, size: compact ? 18 : 24)
          }
        }
        .modifier(Jolt(amount: joltAmount))
        .spotFrame(index == 0 ? .shields : .hud)
        GeometryReader { p in
          ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.16))
            Capsule().fill(peach ? Theme.p2 : Theme.cyan)
              .frame(width: p.size.width * min(1, Double(hud.streak) / streakMax))
              .animation(.easeOut(duration: 0.14), value: hud.streak)
          }
        }
        .frame(height: 4)
        .spotFrame(index == 0 ? .streak : .hud)
      }
.frame(width: CGFloat(maxShields) * ((compact ? 18 : 24) + 2), alignment: .leading)
      .frame(minHeight: compact ? 34 : Theme.target)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(who) shields: \(hud.shields) of \(maxShields). Show details.")
    .onChange(of: hud.shields) { old, new in
      guard new < old else { crackedIndex = nil; return }
      // The shield that just went cracks, and the row jolts.
      crackedIndex = new
      if !reduceMotion { withAnimation(.linear(duration: 0.42)) { joltAmount += 1 } }
      Task { try? await Task.sleep(for: .seconds(1.6)); if crackedIndex == new { withAnimation(.easeOut(duration: 0.4)) { crackedIndex = nil } } }
    }
  }

  private var meter: some View {
    let max = session.game?.meterMax ?? 4
    let color = hud.meter >= max - 1 ? Theme.red : hud.meter >= max - 2 ? Theme.violet : Theme.cyan
    return Button { session.openTip(session.tipMeter(index)) } label: {
      VStack(alignment: .leading, spacing: 3) {
        if !session.versus {
          HStack(spacing: 4) {
            Text(label).font(.game(.caption2, .heavy)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
            if session.overdrive { OverdriveTag() }
          }
        } else if seated {
          Text(Seat.name(index).uppercased()).font(.game(.caption2, .heavy)).tracking(1).foregroundStyle(peach ? Theme.p2 : Theme.cyan).lineLimit(1).minimumScaleFactor(0.8)
        }
        HStack(spacing: 3) {
          ForEach(0..<max, id: \.self) { i in
            Capsule().fill(i < hud.meter ? color : .white.opacity(0.16)).frame(height: 9)
          }
        }
      }
      .frame(minHeight: compact ? 22 : Theme.target)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .spotFrame(index == 0 ? .meter : .hud)
    .accessibilityLabel("\(session.versus ? "\(who) overload" : "Overload") meter: \(hud.meter) of \(max). Show details.")
  }

  private var label: String {
    switch session.mode {
    case .campaign: "LEVEL \(session.levelNumber)"
    case .arcade: "ARCADE"
    case .daily: "DAILY"
    default: "OVERLOAD"
    }
  }

  private var score: some View {
    Button { session.openTip(session.tipScore(index)) } label: {
      VStack(alignment: mirrored ? .leading : .trailing, spacing: 0) {
        RollingScore(value: hud.score, big: !compact)
        ComboBadge(combo: hud.combo, mirrored: peach)
      }
      .environment(\.layoutDirection, .leftToRight)
      .frame(minWidth: 44, minHeight: compact ? 34 : Theme.target)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .spotFrame(index == 0 ? .score : .hud)
    .accessibilityLabel("\(session.versus ? "\(who) score" : "Score") \(hud.score), combo \(hud.combo.formatted()). Show details.")
  }
}

/// The combo beside the score: it grows, takes on its callout's colour and glows hotter with each tier.
struct ComboBadge: View {
  let combo: Double
  var mirrored = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    let tier = ComboTier.tier(combo)
    let color = combo <= 1 ? Theme.muted : tier == 0 ? (mirrored ? Theme.p2 : Theme.sun) : Color(ComboTier.color(tier))
    Text("x\(combo.formatted())")
      .font(.system(size: 12 + CGFloat(min(tier, 6)) * 1.2, weight: .black, design: .rounded))
      .monospacedDigit()
      .foregroundStyle(color)
      .shadow(color: tier > 0 ? color.opacity(0.9) : .clear, radius: CGFloat(tier) * 1.6)
      .shadow(color: tier >= 4 ? color.opacity(0.6) : .clear, radius: CGFloat(tier) * 3)
      .scaleEffect(reduceMotion ? 1 : 1 + CGFloat(tier) * 0.02)
      .animation(.spring(duration: 0.2, bounce: 0.5), value: tier)
  }
}

/// One shield in the HUD. Losing it cracks it open in red; down to the last one, it throbs.
struct ShieldIcon: View {
  let on: Bool
  let cracked: Bool
  let danger: Bool
  let size: CGFloat
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var throb = false
  var body: some View {
    ArtImage(item: .glyph(on ? .shieldOn : .shieldOff), size: size)
      .overlay {
        if cracked {
          Crack().trim(from: 0, to: cracked ? 1 : 0)
            .stroke(Theme.red, style: StrokeStyle(lineWidth: max(1.5, size / 11), lineCap: .round, lineJoin: .round))
            .shadow(color: Theme.red, radius: 3)
            .transition(.opacity)
        }
      }
      .colorMultiply(danger && throb ? Color(red: 1, green: 0.55, blue: 0.58) : .white)
      .scaleEffect(danger && throb && !reduceMotion ? 1.14 : 1)
      .shadow(color: danger ? Theme.red.opacity(throb ? 0.9 : 0.3) : .clear, radius: 5)
      .animation(danger ? .easeInOut(duration: 0.42).repeatForever(autoreverses: true) : .default, value: throb)
      .onChange(of: danger, initial: true) { _, d in throb = d }
  }
}

/// A jagged crack from the top of the shield down through the middle.
struct Crack: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    let pts: [(CGFloat, CGFloat)] = [(0.52, 0.08), (0.42, 0.32), (0.6, 0.46), (0.4, 0.66), (0.54, 0.9)]
    p.move(to: CGPoint(x: r.minX + r.width * pts[0].0, y: r.minY + r.height * pts[0].1))
    for q in pts.dropFirst() { p.addLine(to: CGPoint(x: r.minX + r.width * q.0, y: r.minY + r.height * q.1)) }
    p.move(to: CGPoint(x: r.minX + r.width * 0.6, y: r.minY + r.height * 0.46))
    p.addLine(to: CGPoint(x: r.minX + r.width * 0.78, y: r.minY + r.height * 0.56))
    return p
  }
}

/// A horizontal shake that plays once each time `amount` goes up by one.
struct Jolt: GeometryEffect {
  var amount: CGFloat
  var animatableData: CGFloat { get { amount } set { amount = newValue } }
  func effectValue(size: CGSize) -> ProjectionTransform {
    let t = amount - amount.rounded(.down)
    return ProjectionTransform(CGAffineTransform(translationX: sin(t * .pi * 6) * 6 * (1 - t), y: 0))
  }
}

/// The score rolls up to its new value and pops on each gain.
struct RollingScore: View {
  let value: Int
  var big = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var bump = false
  var body: some View {
    Text(value.formatted())
      .font(.system(big ? .title2 : .headline, design: .rounded, weight: .black))
      .monospacedDigit()
      .foregroundStyle(Theme.ink)
      .contentTransition(reduceMotion ? .identity : .numericText(value: Double(value)))
      .scaleEffect(bump && !reduceMotion ? 1.16 : 1)
      .animation(.spring(duration: 0.22), value: value)
      .animation(.spring(duration: 0.18), value: bump)
      .lineLimit(1)
      .minimumScaleFactor(0.6)
      .onChange(of: value) { old, new in
        guard new > old else { return }
        bump = true
        Task { try? await Task.sleep(for: .milliseconds(120)); bump = false }
      }
  }
}

struct BossBar: View {
  let left: Double
  let open: () -> Void
  var body: some View {
    Button(action: open) {
      HStack(spacing: 8) {
        ArtImage(item: .bubble(.boss), size: 28)
        GeometryReader { p in
          ZStack(alignment: .leading) {
            Capsule().fill(.black.opacity(0.45))
            Capsule().fill(LinearGradient(colors: [Theme.red, Theme.sun], startPoint: .leading, endPoint: .trailing))
              .frame(width: max(8, p.size.width * left))
              .animation(.easeOut(duration: 0.2), value: left)
          }
        }
        .frame(height: 12)
      }
      .padding(.horizontal, 14)
      .frame(minHeight: 34)
      .frame(maxWidth: 420)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Boss health \(Int(left * 100)) percent. Show details.")
  }
}

/// Timers for whatever power-ups are running.
struct EffectRow: View {
  let session: Session
  /// Two players: only this player's overcharge (freeze and focus hold everyone).
  var player: Int? = nil
  var body: some View {
    let charge = player.flatMap { session.hud.indices.contains($0) ? session.hud[$0].overcharge : nil } ?? (session.hud.map(\.overcharge).max() ?? 0)
    let items: [(PowerUp, Double)] = [
      (.overcharge, charge), (.freeze, session.freezeLeft), (.focus, session.focusLeft),
    ].filter { $0.1 > 0 }
    if !items.isEmpty {
      HStack(spacing: 8) {
        ForEach(items, id: \.0) { item in
          Button { session.openTip(session.tipPower(item.0)) } label: {
            HStack(spacing: 4) {
              ArtImage(item: .power(item.0.artKind), size: 24)
              Text(String(format: "%.0fs", item.1.rounded(.up))).font(.game(.footnote, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 34)
            .background(Capsule().fill(Theme.night.opacity(0.8)))
            .contentShape(Capsule())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(item.0.title), \(Int(item.1)) seconds left. Show details.")
        }
      }
      .transition(.opacity)
    }
  }
}

struct ToastView: View {
  let toast: Toast?
  var body: some View {
    Group {
      if let toast {
        HStack(spacing: 8) {
          if let p = toast.power { ArtImage(item: .power(p.artKind), size: 30) }
          Text(toast.text).font(.game(.subheadline, .semibold)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.panel.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.panelEdge, lineWidth: 1))
        .frame(maxWidth: 440)
        .padding(.horizontal, 20)
        .id(toast.id)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .animation(.easeOut(duration: 0.22), value: toast)
    .allowsHitTesting(false)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - On top of the game

struct TipOverlay: View {
  let tip: Tip
  let close: () -> Void
  var body: some View {
    ZStack(alignment: .top) {
      Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: close)
        .accessibilityLabel("Close").accessibilityAddTraits(.isButton)
      Button(action: close) {
        VStack(alignment: .leading, spacing: 8) {
          Text(tip.title).font(.game(.title3, .heavy)).foregroundStyle(Theme.ink)
          if !tip.live.isEmpty { Text(tip.live).font(.game(.subheadline, .bold)).foregroundStyle(Theme.cyan) }
          Text(tip.body).font(.game(.subheadline, .medium)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
          Text("The game is holding still. Tap anywhere to close.").font(.game(.caption, .medium)).foregroundStyle(Theme.muted)
        }
        .multilineTextAlignment(.leading)
        .padding(18)
        .frame(maxWidth: 440, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.panelEdge, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.top, 84)
    }
    .transition(.opacity)
  }
}

struct Centered<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    ZStack {
      Color.black.opacity(0.5).ignoresSafeArea()
      ViewThatFits(in: .vertical) {
        content.padding(16)
        ScrollView { content.padding(16).frame(maxWidth: .infinity) }.scrollBounceBehavior(.basedOnSize)
      }
    }
    .transition(.opacity)
  }
}

struct MeetOverlay: View {
  let kind: ActorKind
  let close: () -> Void
  @State private var showMore = false
  var body: some View {
    Centered {
      Sheet(maxWidth: 420) {
        HStack(spacing: 14) {
          AuroraAssemble(item: .bubble(kind.artKind), size: 96, count: 520)
          VStack(alignment: .leading, spacing: 2) {
            Text("NEW BUBBLE").font(.game(.caption, .heavy)).foregroundStyle(Theme.sun)
            Text(kind.title).font(.game(.largeTitle, .black)).foregroundStyle(Theme.ink)
          }
        }
        Text(kind.blurb).font(.game(.title3, .bold)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
        Button(showMore ? "Less" : "More") { showMore.toggle() }.buttonStyle(.plain).font(.game(.subheadline, .bold)).foregroundStyle(Theme.cyan).frame(minHeight: Theme.target)
        if showMore { Text(kind.detail).font(.game(.subheadline, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
        Button("Got it", action: close).buttonStyle(ChunkyStyle())
      }
    }
  }
}

struct PauseOverlay: View {
  @Environment(AppModel.self) private var app
  let session: Session
  var body: some View {
    Centered {
      Sheet(maxWidth: 420) {
        Text("Paused").font(.game(.largeTitle, .black)).foregroundStyle(Theme.ink)
        Button("Resume") { session.resume() }.buttonStyle(ChunkyStyle())
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 10) { restart; menu }
          VStack(spacing: 10) { restart; menu }
        }
        SettingsRows()
      }
    }
  }
  private var restart: some View { Button(session.versus ? "Rematch" : "Restart") { session.restart() }.buttonStyle(QuietStyle()) }
  private var menu: some View { Button("Menu") { app.route = session.isCampaign ? .map : (session.mode.isArcade ? .arcade : .home) }.buttonStyle(QuietStyle()) }
}

// The end card (`ResultOverlay`) lives in EndCard.swift.

struct StatGrid: View {
  let session: Session
  @State private var open: Tip?
  private let columns = [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)]
  var body: some View {
    let g = session.game!
    LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
      ForEach(rows(g), id: \.0) { row in
        Button { session.openTip(Tip(title: row.0, body: row.2)) } label: {
          VStack(alignment: .leading, spacing: 1) {
            Text(row.0).font(.game(.caption2, .bold)).foregroundStyle(Theme.muted).underline(pattern: .dot).lineLimit(1).minimumScaleFactor(0.8)
            Text(row.1).font(.game(.title3, .heavy)).monospacedDigit().foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
          }
          .frame(maxWidth: .infinity, minHeight: Theme.target, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(row.0): \(row.1). Show details.")
      }
    }
  }
  private func rows(_ g: Game) -> [(String, String, String)] {
    if g.versus {
      // Player 1 (the bottom seat) first.
      return [1, 0].flatMap { i -> [(String, String, String)] in
        let p = g.players[i], n = i == 1 ? "P1" : "P2", who = Seat.name(i)
        return [
          ("\(n) score", p.score.formatted(), "\(who)'s points. If every bubble gets cleared, the higher score wins."),
          ("\(n) cross", "\(p.crossings)", "Bubbles \(who) let through. Each charged their meter and landed on the rival's half."),
          ("\(n) shield", "\(p.shields)", "A player with no shields loses the match, whatever the score."),
        ]
      }
    }
    let p = g.players[0]
    return [
      ("Time", String(format: "%.0fs", g.time), "Time the bubbles were moving."),
      ("Taps", "\(p.taps)", "Touches that hit a bubble."),
      ("Crossings", "\(p.crossings)", "Bubbles that got past you."),
      ("Hinge pops", "\(p.zaps)", "Tiny ones the line popped for free."),
      ("Recharged", "\(p.recharges)", "Shields won back."),
      ("Top combo", "x\(p.bestCombo.formatted())", "Your best multiplier."),
    ]
  }
}

// MARK: - Tour

struct TourOverlay: View {
  let session: Session
  let spots: [SpotTarget: CGRect]
  let size: CGSize
  let fold: CGRect?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let step = session.tourSteps[session.tourIndex]
    let target = (session.tourDone && step.input) ? SpotTarget.arena : step.target
    let spot = session.spotRect(target, hudFrames: spots)
    ZStack {
      SpotShape(rect: spot?.rect ?? .zero, round: spot?.round ?? false)
        .fill(Color.black.opacity(spot?.open == true ? 0 : 0.6), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
        .animation(reduceMotion ? nil : .spring(duration: 0.34), value: spot?.rect)
      if let rect = spot?.rect, spot?.open != true {
        SpotShape(rect: rect, round: spot?.round ?? false, outerRect: false)
          .stroke(Theme.cyan, lineWidth: 2)
          .allowsHitTesting(false)
          .animation(reduceMotion ? nil : .spring(duration: 0.34), value: rect)
      }
      if session.versus {
        // Both players read the tour: one card in each half, facing its player.
        ForEach(0..<2, id: \.self) { i in
          SeatTurn(degrees: session.seatDegrees(i)) { seatCard(step) }
        }
      } else {
        card(step)
      }
    }
  }

  /// A two-player tour card, at the reader's own edge (inside a `SeatTurn`), clear of the hinge.
  private func seatCard(_ step: TourStep) -> some View {
    VStack {
      Spacer(minLength: 0)
      content(step).frame(maxWidth: 460)
    }
    .padding(.horizontal, 8)
    .padding(.bottom, 8)
  }

  /// The card stays clear of the action: on the trailing side when the hinge is vertical, at the bottom otherwise.
  @ViewBuilder
  private func card(_ step: TourStep) -> some View {
    let sideBySide = session.game?.vertical == true
    if sideBySide {
      HStack {
        Spacer(minLength: size.width * 0.52)
        content(step).frame(maxWidth: min(460, size.width * 0.46), maxHeight: size.height - 16)
      }
      .padding(.trailing, 8)
      .frame(maxHeight: .infinity, alignment: .bottom)
      .padding(.bottom, 8)
    } else {
      VStack {
        Spacer(minLength: size.height * 0.56)
        content(step).frame(maxWidth: 520, maxHeight: size.height * 0.44)
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 8)
    }
  }

  private func content(_ step: TourStep) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Step \(session.tourIndex + 1) of \(session.tourSteps.count)").font(.game(.caption, .semibold)).foregroundStyle(Theme.muted)
        Spacer()
        Button("Skip tour") { session.endTour() }
          .font(.game(.footnote, .semibold)).foregroundStyle(Theme.muted)
          .frame(minHeight: Theme.target).contentShape(Rectangle())
          .padding(.vertical, -10)
      }
      ProgressView(value: Double(session.tourIndex + 1), total: Double(session.tourSteps.count)).tint(Theme.cyan)
      ScrollView {
        VStack(alignment: .leading, spacing: 6) {
          Text(step.title).font(.game(.title3, .heavy)).foregroundStyle(Theme.ink)
          Text(session.tourDone ? (step.done ?? step.body) : step.body).font(.game(.subheadline, .medium)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
          if !session.tourDone, let todo = session.tourNote.isEmpty ? step.todo : session.tourNote {
            Text(todo).font(.game(.subheadline, .bold)).foregroundStyle(Theme.cyan).fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollBounceBehavior(.basedOnSize)
      HStack(spacing: 10) {
        Button("Back") { session.tourBack() }.buttonStyle(QuietStyle()).disabled(session.tourIndex == 0).opacity(session.tourIndex == 0 ? 0.45 : 1).frame(maxWidth: 110)
        Button(step.last ?? (session.tourDone ? "Next" : step.input ? "Try it first" : "Watch first")) { session.tourNext() }
          .buttonStyle(ChunkyStyle(colors: session.tourDone ? [Color(red: 1, green: 0.84, blue: 0.3), Theme.orange] : [Theme.panelEdge.opacity(0.5), Theme.panelEdge.opacity(0.35)], text: session.tourDone ? Color(red: 0.2, green: 0.08, blue: 0.1) : Theme.ink))
          .disabled(!session.tourDone)
      }
    }
    .padding(16)
    .fixedSize(horizontal: false, vertical: true)
    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.panel))
    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.panelEdge, lineWidth: 1.5))
    .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
  }
}

struct SpotShape: Shape {
  var rect: CGRect
  var round: Bool
  var outerRect = true
  var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
    get { .init(rect.minX, .init(rect.minY, .init(rect.width, rect.height))) }
    set { rect = CGRect(x: newValue.first, y: newValue.second.first, width: newValue.second.second.first, height: newValue.second.second.second) }
  }
  func path(in bounds: CGRect) -> Path {
    var p = Path()
    if outerRect { p.addRect(bounds.insetBy(dx: -200, dy: -200)) }
    if round { p.addEllipse(in: rect) } else { p.addRoundedRect(in: rect, cornerSize: CGSize(width: 14, height: 14)) }
    return p
  }
}
