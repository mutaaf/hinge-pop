import SwiftUI
import HingePopCore

/// The update card: a bright headline, up to four callouts, a fold for the rest, and one button.
/// It reads release-notes/<version>.md, the same file TestFlight's notes come from.
/// A callout with a `{destination}` is a tap target that closes the card and opens that place.
struct WhatsNewView: View {
  let notes: UpdateNotes
  let done: () -> Void
  let go: (UpdateNotes.Destination) -> Void
  @State private var open: String? = nil
  @State private var shown = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let arenas: [Arena] = [.neon, .classic, .space, .forest]

  var body: some View {
    ZStack {
      Theme.night.opacity(0.94).ignoresSafeArea()
        .onTapGesture {}
      ScrollView {
        VStack(spacing: 12) {
          AuroraSpot(arena: .space, corner: 26) {
            VStack(spacing: 6) {
              Text("NEW IN \(notes.version)")
                .font(.game(.caption, .heavy)).tracking(2)
                .foregroundStyle(Theme.sun)
              Text(notes.headline)
                .font(.game(.largeTitle, .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            }
            .padding(.vertical, 26).padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
          }
          .accessibilityElement(children: .combine)
          .accessibilityAddTraits(.isHeader)

          ForEach(Array(notes.callouts.enumerated()), id: \.offset) { i, c in
            Group {
              if let place = c.destination {
                Button { go(place) } label: { callout(c, index: i, place: place) }
                  .buttonStyle(CalloutPress())
                  .accessibilityHint("Closes what's new and opens \(Self.name(place))")
              } else {
                callout(c, index: i, place: nil)
              }
            }
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .animation(reduceMotion ? nil : .spring(duration: 0.45).delay(0.08 * Double(i)), value: shown)
          }

          if !notes.more.isEmpty {
            Fold(title: "More news", note: "\(notes.more.count)", id: "more", open: $open) {
              ForEach(notes.more, id: \.self) { line in
                Label { Text(line).foregroundStyle(Theme.ink) } icon: { Image(systemName: "sparkle").foregroundStyle(Theme.cyan) }
                  .font(.game(.subheadline, .semibold))
              }
            }
          }

          Button("Let's pop!", action: done)
            .buttonStyle(ChunkyStyle())
            .padding(.top, 4)
            .accessibilityHint("Closes what's new")
        }
        .padding(18)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .onAppear { shown = true }
    .accessibilityAddTraits(.isModal)
  }

  private func callout(_ c: UpdateNotes.Callout, index i: Int, place: UpdateNotes.Destination?) -> some View {
    HStack(spacing: 14) {
      AuroraSpot(arena: arenas[i % arenas.count], corner: 16) {
        Image(systemName: c.symbol)
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(.white)
          .shadow(color: .black.opacity(0.35), radius: 3)
          .frame(width: 54, height: 54)
      }
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(c.text)
          .font(.game(.body, .bold))
          .foregroundStyle(Theme.ink)
          .fixedSize(horizontal: false, vertical: true)
        if let place {
          Text(Self.cta(place).uppercased())
            .font(.game(.caption, .heavy)).tracking(1.2)
            .foregroundStyle(Theme.sun)
        }
      }
      .multilineTextAlignment(.leading)
      Spacer(minLength: 0)
      if place != nil {
        Image(systemName: "chevron.right.circle.fill")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(Theme.sun)
          .accessibilityHidden(true)
      }
    }
    .padding(10)
    .frame(minHeight: Theme.target)
    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel))
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
      .stroke(place == nil ? Theme.panelEdge : Theme.sun.opacity(0.55), lineWidth: place == nil ? 1 : 1.5))
    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  /// The small call to action under a callout that goes somewhere.
  static func cta(_ place: UpdateNotes.Destination) -> String {
    switch place {
    case .map: "Open the map"
    case .settings: "Open settings"
    case .guide: "Show me how"
    case .play: "Play it"
    case .arcade: "Try Arcade"
    case .daily: "Try today's Daily"
    case .versus: "Grab a friend"
    }
  }

  static func name(_ place: UpdateNotes.Destination) -> String {
    switch place {
    case .map: "the level map"
    case .settings: "settings"
    case .guide: "How to play"
    case .play: "the next level"
    case .arcade: "Arcade"
    case .daily: "today's Daily"
    case .versus: "two players"
    }
  }
}

/// A callout that goes somewhere squishes a little under the finger.
private struct CalloutPress: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
      .brightness(configuration.isPressed ? 0.06 : 0)
      .animation(.snappy(duration: 0.15), value: configuration.isPressed)
  }
}
