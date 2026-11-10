import SwiftUI
import HingePopCore

/// The update card: a bright headline, up to four callouts, a fold for the rest, and one button.
/// It reads release-notes/<version>.md, the same file TestFlight's notes come from.
struct WhatsNewView: View {
  let notes: UpdateNotes
  let done: () -> Void
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
            HStack(spacing: 14) {
              AuroraSpot(arena: arenas[i % arenas.count], corner: 16) {
                Image(systemName: c.symbol)
                  .font(.system(size: 24, weight: .bold))
                  .foregroundStyle(.white)
                  .shadow(color: .black.opacity(0.35), radius: 3)
                  .frame(width: 54, height: 54)
              }
              .accessibilityHidden(true)
              Text(c.text)
                .font(.game(.body, .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 0)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.panelEdge, lineWidth: 1))
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
}
