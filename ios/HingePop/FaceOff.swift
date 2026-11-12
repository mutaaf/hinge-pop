import SwiftUI
import HingePopArt
import HingePopCore

// Two players, face to face. The phone lies flat between them at opposite ends, the hinge splits the long
// axis, and everything that belongs to a player turns to read the right way up from their seat: their
// scoreboard at their own edge, their tips, their pause card and their result. One pause button sits at the
// hinge's end where both can reach it.

/// Lays content out as if the screen were turned so one player's edge is at the bottom, then turns it into
/// place. `degrees` comes from `Seat.degrees` (0, 180, 90 or -90).
struct SeatTurn<Content: View>: View {
  let degrees: Double
  @ViewBuilder var content: Content
  var body: some View {
    GeometryReader { p in
      let sideways = abs(abs(degrees) - 90) < 1
      content
        .frame(width: sideways ? p.size.height : p.size.width, height: sideways ? p.size.width : p.size.height)
        .rotationEffect(.degrees(degrees))
        .position(x: p.size.width / 2, y: p.size.height / 2)
    }
  }
}

/// Each player's scoreboard at their own edge, their own toasts and power-up timers, and the shared pause.
struct VersusHUD: View {
  let session: Session
  let size: CGSize
  let fold: CGRect?

  var body: some View {
    // `game` isn't observed; reading `generation` redraws this when a new one starts or the seats move.
    let _ = session.generation
    ZStack {
      ForEach(0..<2, id: \.self) { i in
        SeatTurn(degrees: session.seatDegrees(i)) {
          VStack(spacing: 6) {
            Spacer(minLength: 0)
            ToastView(toast: session.toast)
            EffectRow(session: session, player: i)
            SeatBar(session: session, index: i)
          }
        }
      }
      if session.overlay == .none { pause }
    }
  }

  /// One pause button at the hinge's end, so both players can reach it. It turns with the line, so it reads
  /// as a pause from either side, and steps off a real fold (nothing sits on the crease).
  private var pause: some View {
    let p = pausePoint
    return Button { session.pause() } label: {
      ArtImage(item: .glyph(.pause), size: 34)
        .rotationEffect(.degrees(session.seatDegrees(1)))
        .frame(width: Theme.target, height: Theme.target)
        .background(Circle().fill(Theme.night.opacity(0.72)))
        .overlay(Circle().stroke(Theme.panelEdge.opacity(0.8), lineWidth: 1))
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Pause")
    .accessibilityIdentifier("versusPause")
    .position(p)
  }

  private var pausePoint: CGPoint {
    guard let g = session.game else { return CGPoint(x: size.width - 30, y: size.height / 2) }
    let r = session.playRect
    let off: CGFloat = session.onFold ? (fold.map { (g.vertical ? $0.width : $0.height) / 2 } ?? 20) + Theme.target / 2 + 4 : 0
    if g.vertical {
      return CGPoint(x: r.minX + CGFloat(g.hinge) + off, y: r.minY + Theme.target / 2 + 6)
    }
    return CGPoint(x: r.maxX - Theme.target / 2 - 6, y: r.minY + CGFloat(g.hinge) + off)
  }
}

/// One player's scoreboard: shields and streak, meter, score and combo, in a band at their edge.
struct SeatBar: View {
  let session: Session
  let index: Int
  var body: some View {
    PlayerCluster(session: session, index: index, seated: true)
      .padding(.horizontal, 14)
      .frame(height: session.seatBand)
      .frame(maxWidth: 560)
      .frame(maxWidth: .infinity)
      .background(Theme.night.opacity(0.82))
      .overlay(alignment: .top) {
        // The edge toward the hinge, in the player's colour.
        Rectangle().fill(LinearGradient(colors: [.clear, index == 1 ? Theme.cyan : Theme.p2, .clear], startPoint: .leading, endPoint: .trailing))
          .frame(height: 2).opacity(0.85)
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("seat\(index == 1 ? 1 : 2)")
  }
}

/// Paused, for two: each player gets the card facing them, and either can resume.
struct VersusPauseOverlay: View {
  @Environment(AppModel.self) private var app
  let session: Session
  var body: some View {
    ZStack {
      Color.black.opacity(0.5).ignoresSafeArea()
      ForEach(0..<2, id: \.self) { i in
        SeatTurn(degrees: session.seatDegrees(i)) {
          VStack {
            Spacer(minLength: 0)
            HalfSheet {
              Text("Paused").font(.game(.title, .black)).foregroundStyle(Theme.ink)
              Button("Resume") { session.resume() }.buttonStyle(ChunkyStyle())
              HStack(spacing: 10) {
                Button("Rematch") { session.restart() }.buttonStyle(QuietStyle())
                Button("Menu") { app.route = .home }.buttonStyle(QuietStyle())
              }
            }
          }
          .padding(12)
        }
      }
    }
    .transition(.opacity)
  }
}

/// The end of a match, split: each player sees their own result facing them, and one Rematch on the hinge
/// serves both.
struct VersusResultOverlay: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let session: Session
  @State private var shown = false

  var body: some View {
    let g = session.game!
    ZStack {
      Color.black.opacity(0.5).ignoresSafeArea()
      ForEach(0..<2, id: \.self) { i in
        SeatTurn(degrees: session.seatDegrees(i)) {
          VStack {
            Spacer(minLength: 0)
            half(g, player: i)
          }
          .padding(12)
          .padding(.bottom, 4)
        }
      }
      rematch(g)
    }
    .transition(.opacity)
    .onAppear { withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.45)) { shown = true } }
    .task {
      #if DEBUG
      Debug.ready("result-settled")
      #endif
    }
  }

  private func verdict(_ g: Game, _ i: Int) -> (title: String, colors: [Color]) {
    guard let w = g.winner else { return ("Draw!", [.white, Theme.sun]) }
    return w == i ? ("You win!", [.white, Theme.sun]) : ("You lose", [.white, Theme.muted])
  }

  private func half(_ g: Game, player i: Int) -> some View {
    let me = g.players[i], them = g.players[1 - i]
    let v = verdict(g, i)
    let why = g.players.contains { $0.shields <= 0 }
      ? (me.shields <= 0 ? "Your last shield went." : "Their last shield went.")
      : "All clear. Top score wins."
    return HalfSheet {
      Text(Seat.name(i).uppercased()).font(.game(.caption, .heavy)).tracking(2).foregroundStyle(i == 1 ? Theme.cyan : Theme.p2)
      Text(v.title)
        .font(.game(.largeTitle, .black))
        .foregroundStyle(LinearGradient(colors: v.colors, startPoint: .top, endPoint: .bottom))
        .scaleEffect(shown ? 1 : 1.6).opacity(shown ? 1 : 0)
        .accessibilityIdentifier("verdict\(i == 1 ? 1 : 2)")
      HStack(spacing: 18) {
        tally("You", me.score)
        tally("Rival", them.score)
      }
      Text(why).font(.game(.subheadline, .semibold)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
      Button("Menu") { app.route = .home }.buttonStyle(QuietStyle()).frame(maxWidth: 160)
    }
    .accessibilityElement(children: .contain)
  }

  private func tally(_ label: String, _ score: Int) -> some View {
    VStack(spacing: 0) {
      Text(label).font(.game(.caption, .bold)).foregroundStyle(Theme.muted)
      Text(score.formatted()).font(.system(size: 28, weight: .black, design: .rounded)).monospacedDigit().foregroundStyle(Theme.ink)
        .lineLimit(1).minimumScaleFactor(0.6)
    }
  }

  /// One Rematch on the hinge, for both. Its word reads from each side.
  private func rematch(_ g: Game) -> some View {
    let r = session.playRect
    let at = g.vertical ? CGPoint(x: r.minX + CGFloat(g.hinge), y: r.midY) : CGPoint(x: r.midX, y: r.minY + CGFloat(g.hinge))
    return Button { session.restart() } label: {
      VStack(spacing: 2) {
        Text("Rematch").font(.game(.caption, .heavy)).rotationEffect(.degrees(180))
        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 26, weight: .black))
        Text("Rematch").font(.game(.caption, .heavy))
      }
      .foregroundStyle(Color(red: 0.2, green: 0.08, blue: 0.1))
      .frame(width: 92, height: 92)
      .background(Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0.3), Theme.orange], startPoint: .top, endPoint: .bottom)))
      .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
      .shadow(color: Theme.orange.opacity(0.7), radius: 14)
      .rotationEffect(.degrees(g.vertical ? -90 : 0))
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Rematch")
    .accessibilityIdentifier("rematch")
    .scaleEffect(shown ? 1 : 0.4)
    .position(at)
  }
}

/// A compact panel for one player's half of the screen.
struct HalfSheet<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    VStack(spacing: 10) { content }
      .padding(16)
      .frame(maxWidth: 420)
      .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.panel.opacity(0.96)))
      .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.panelEdge, lineWidth: 1.5))
      .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
  }
}
