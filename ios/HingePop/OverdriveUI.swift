import SwiftUI
import HingePopCore

// Overdrive's look: one flame mark used everywhere it shows (the switch, the HUD, the journey and the end
// card), and the Normal / Overdrive switch on a bright aurora, a few words each.

extension Theme {
  static let ember = Color(red: 1, green: 0.36, blue: 0.2)
  static let hot = [Color(red: 1, green: 0.86, blue: 0.36), Theme.orange, Color(red: 1, green: 0.3, blue: 0.24)]
}

/// The flame that marks Overdrive. `flicker` breathes it gently (never under Reduce Motion).
struct FlameMark: View {
  var size: CGFloat = 16
  var flicker = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var lit = false
  var body: some View {
    Image(systemName: "flame.fill")
      .font(.system(size: size, weight: .black))
      .foregroundStyle(LinearGradient(colors: Theme.hot, startPoint: .top, endPoint: .bottom))
      .shadow(color: Theme.ember.opacity(0.85), radius: size * 0.3)
      .shadow(color: .black.opacity(0.55), radius: 1, y: 1)
      .scaleEffect(lit ? 1.08 : 0.96, anchor: .bottom)
      .accessibilityHidden(true)
      .onAppear {
        guard flicker, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { lit = true }
      }
  }
}

/// Normal or Overdrive, with one line about the one that's picked. Sits where players start a level.
struct DifficultySwitch: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var pick

  var body: some View {
    let chosen = app.progress.difficulty
    AuroraSpot(arena: chosen == .overdrive ? .magma : .classic, corner: 26) {
      VStack(spacing: 6) {
        HStack(spacing: 4) {
          ForEach(Difficulty.allCases, id: \.self) { segment($0, chosen: chosen) }
        }
        .padding(4)
        .background(Capsule().fill(Theme.night.opacity(0.72)))
        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
        Text(chosen.blurb)
          .font(.game(.footnote, .heavy)).foregroundStyle(.white)
          .shadow(color: .black.opacity(0.6), radius: 2)
          .lineLimit(1).minimumScaleFactor(0.8)
          .contentTransition(.opacity)
          .accessibilityIdentifier("difficultyBlurb")
      }
      .padding(8)
    }
  }

  private func segment(_ d: Difficulty, chosen: Difficulty) -> some View {
    let on = d == chosen
    return Button {
      withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) { app.progress.difficulty = d }
      Haptics.shared.tap()
    } label: {
      HStack(spacing: 6) {
        if d == .overdrive { FlameMark(size: 15, flicker: on) }
        else { Image(systemName: "circle.circle.fill").font(.system(size: 14, weight: .black)).accessibilityHidden(true) }
        Text(d.title).font(.game(.headline, .heavy)).lineLimit(1).minimumScaleFactor(0.8)
      }
      .foregroundStyle(on ? Color(red: 0.18, green: 0.06, blue: 0.1) : Theme.ink.opacity(0.85))
      .frame(maxWidth: .infinity, minHeight: Theme.target)
      .background {
        if on {
          Capsule()
            .fill(LinearGradient(colors: d == .overdrive ? Theme.hot : [Color(red: 0.75, green: 0.96, blue: 1), Theme.cyan], startPoint: .top, endPoint: .bottom))
            .overlay(Capsule().fill(.white.opacity(0.25)).padding(.horizontal, 10).padding(.top, 3).padding(.bottom, 24))
            .shadow(color: (d == .overdrive ? Theme.ember : Theme.cyan).opacity(0.7), radius: 10)
            .matchedGeometryEffect(id: "pick", in: pick)
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(d.title). \(d.blurb)")
    .accessibilityAddTraits(on ? [.isSelected] : [])
    .accessibilityIdentifier("difficulty-\(d.rawValue)")
  }
}

/// The journey's quick flip: a flame that's lit while Overdrive is on.
struct OverdriveFlip: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let on = app.progress.difficulty == .overdrive
    Button {
      withAnimation(.snappy(duration: 0.25)) { app.progress.difficulty = on ? .normal : .overdrive }
      Haptics.shared.tap()
    } label: {
      ZStack {
        Circle().fill(on ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.42, green: 0.12, blue: 0.08), Color(red: 0.25, green: 0.06, blue: 0.12)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Theme.panel))
        Circle().stroke(on ? Theme.orange : Theme.panelEdge, lineWidth: on ? 2 : 1)
        if on { FlameMark(size: 21, flicker: true) }
        else { Image(systemName: "flame").font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.muted) }
      }
      .frame(width: Theme.target, height: Theme.target)
      .shadow(color: on ? Theme.ember.opacity(0.6) : .clear, radius: 8)
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(on ? "Overdrive is on" : "Overdrive is off")
    .accessibilityHint("Switches between Normal and Overdrive")
    .accessibilityIdentifier("overdriveFlip")
  }
}

/// A small "OVERDRIVE" tag with its flame, for the HUD and the end card.
struct OverdriveTag: View {
  var big = false
  var body: some View {
    HStack(spacing: 3) {
      FlameMark(size: big ? 13 : 10)
      Text("OVERDRIVE").font(.game(big ? .caption : .caption2, .black)).tracking(1.2)
        .foregroundStyle(LinearGradient(colors: Theme.hot, startPoint: .top, endPoint: .bottom))
    }
    .accessibilityElement().accessibilityLabel("Overdrive")
    .accessibilityIdentifier("overdriveTag")
  }
}
