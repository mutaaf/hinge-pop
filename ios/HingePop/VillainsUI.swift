import SwiftUI
import HingePopArt
import HingePopCore

extension VillainKind {
  var artKind: VillainSprite { VillainSprite(rawValue: rawValue) ?? .hex }
  /// The tier's warning colour (the spiked rim's).
  var tint: Color { let w = artKind.warning; return Color(red: w.r, green: w.g, blue: w.b) }
  var uiTint: UIColor { let w = artKind.warning; return UIColor(red: w.r, green: w.g, blue: w.b, alpha: 1) }
}

/// The tier as a small badge: "MENACE · costs a shield".
struct VillainTierBadge: View {
  let kind: VillainKind
  var body: some View {
    Text("\(kind.tier.label.uppercased()) · \(kind.tier.cost.lowercased())")
      .font(.game(.caption, .heavy))
      .foregroundStyle(.black.opacity(0.85))
      .padding(.horizontal, 8).padding(.vertical, 3)
      .background(Capsule().fill(kind.tint))
      .fixedSize()
  }
}

/// A villain's picture, name, tier and tell, in one row.
struct VillainRow: View {
  let kind: VillainKind
  var size: CGFloat = 64
  var body: some View {
    HStack(spacing: 12) {
      ArtImage(item: .villain(kind.artKind), size: size)
      VStack(alignment: .leading, spacing: 4) {
        Text(kind.title).font(.game(.title3, .black)).foregroundStyle(Theme.ink)
        VillainTierBadge(kind: kind)
        Text(kind.tell).font(.game(.subheadline, .bold)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
  }
}

/// The first time villains turn up: who they are, what a touch costs, and how to bust them safely.
struct VillainAlertOverlay: View {
  let kinds: [VillainKind]
  let close: () -> Void
  @State private var shown = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    Centered {
      Sheet(maxWidth: 440) {
        VStack(alignment: .leading, spacing: 2) {
          Text(kinds.count == 1 ? "NEW VILLAIN" : "NEW VILLAINS").font(.game(.caption, .heavy)).tracking(2).foregroundStyle(Theme.red)
          Text("Hands off!").font(.game(.largeTitle, .black)).foregroundStyle(Theme.ink).minimumScaleFactor(0.7).lineLimit(1)
        }
        ForEach(Array(kinds.enumerated()), id: \.element) { i, kind in
          VillainRow(kind: kind, size: kinds.count > 2 ? 52 : 72)
            .scaleEffect(shown || reduceMotion ? 1 : 0.85)
            .opacity(shown || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.4).delay(0.06 + Double(i) * 0.1), value: shown)
        }
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "hand.raised.slash.fill").foregroundStyle(Theme.sun)
          Text("Leave them be and they leave. A snap, a Chain Burst or a freeze busts them for points.")
            .font(.game(.subheadline, .bold)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.06)))
        Button("Got it", action: close).buttonStyle(ChunkyStyle()).accessibilityIdentifier("villainGotIt")
      }
    }
    .onAppear { shown = true }
  }
}

/// The villain that ended a run, with its line.
struct VillainLoss: View {
  let kind: VillainKind
  var body: some View {
    HStack(spacing: 12) {
      ArtImage(item: .villain(kind.artKind), size: 76)
      VStack(alignment: .leading, spacing: 4) {
        Text(kind.tier == .doom ? "\(kind.title) ended it" : "\(kind.title) took your last shield")
          .font(.game(.title3, .black)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("lossReason")
        Text("“\(kind.taunt)”").font(.game(.subheadline, .bold)).italic().foregroundStyle(.white.opacity(0.92)).fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
  }
}

/// How to play: every villain, its tier and its tell.
struct VillainGuide: View {
  var body: some View {
    Text("Spiked rims mean hands off. The colour says how bad a touch is.").font(.game(.subheadline, .semibold)).foregroundStyle(Theme.muted)
    ForEach(VillainKind.allCases, id: \.self) { VillainRow(kind: $0, size: 52) }
    Text("Snap the Hinge busts menaces and brutes near the line and throws a Doom back. A Crease Clap busts them all. Chain Bursts and a freeze bust anything.")
      .font(.game(.footnote, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
  }
}
