import SwiftUI
import HingePopArt
import HingePopCore

/// The violet cartoon world from the concept sheet.
extension Arena {
  var sparkColors: [UIColor] { aurora.map { UIColor($0) } }
}

enum Theme {
  static let night = Color(red: 0.08, green: 0.04, blue: 0.18)
  static let panel = Color(red: 0.14, green: 0.08, blue: 0.29)
  static let panelEdge = Color(red: 0.43, green: 0.31, blue: 0.75)
  static let ink = Color(red: 0.97, green: 0.96, blue: 1)
  static let muted = Color(red: 0.76, green: 0.72, blue: 0.9)
  static let cyan = Color(red: 0.31, green: 0.85, blue: 1)
  static let sun = Color(red: 1, green: 0.78, blue: 0.2)
  static let orange = Color(red: 1, green: 0.58, blue: 0.2)
  static let violet = Color(red: 0.69, green: 0.51, blue: 1)
  static let red = Color(red: 1, green: 0.34, blue: 0.42)
  static let p2 = Color(red: 1, green: 0.7, blue: 0.48)
  static let target: CGFloat = 48
}

extension Font {
  static func game(_ style: Font.TextStyle, _ weight: Font.Weight = .bold) -> Font { .system(style, design: .rounded, weight: weight) }
}

/// A chunky, glossy game button. Always at least the minimum touch target.
struct ChunkyStyle: ButtonStyle {
  var colors: [Color] = [Color(red: 1, green: 0.84, blue: 0.3), Theme.orange]
  var text = Color(red: 0.2, green: 0.08, blue: 0.1)
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.game(.headline, .heavy))
      .foregroundStyle(text)
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, minHeight: 56)
      .background(
        ZStack {
          Capsule().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
          Capsule().fill(.white.opacity(0.22)).padding(.horizontal, 8).padding(.top, 4).padding(.bottom, 28)
        }
      )
      .overlay(Capsule().stroke(.black.opacity(0.25), lineWidth: 1))
      .contentShape(Capsule())
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

struct QuietStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.game(.headline))
      .foregroundStyle(Theme.ink)
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity, minHeight: 52)
      .background(Capsule().fill(Theme.panel.opacity(configuration.isPressed ? 0.6 : 0.92)))
      .overlay(Capsule().stroke(Theme.panelEdge, lineWidth: 1.5))
      .contentShape(Capsule())
  }
}

struct Sheet<Content: View>: View {
  var maxWidth: CGFloat = 480
  @ViewBuilder var content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 14) { content }
      .padding(22)
      .frame(maxWidth: maxWidth)
      .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.panel.opacity(0.94)))
      .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.panelEdge, lineWidth: 1.5))
      .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
  }
}

/// Art as a SwiftUI image. The scale matches the screen so it stays crisp.
struct ArtImage: View {
  enum Item { case bubble(BubbleKind), power(PowerKind), glyph(UIGlyph), logo }
  let item: Item
  let size: CGFloat
  @Environment(\.displayScale) private var scale
  var body: some View {
    switch item {
    case .bubble(let k): Image(decorative: Art.bubble(k, size: size, scale: scale), scale: scale)
    case .power(let k): Image(decorative: Art.power(k, size: size, scale: scale), scale: scale)
    case .glyph(let g): Image(decorative: Art.glyph(g, size: size, scale: scale), scale: scale)
    case .logo: Image(decorative: Art.logo(width: size, scale: scale), scale: scale)
    }
  }
}

extension ActorKind {
  var artKind: BubbleKind { BubbleKind(rawValue: rawValue) ?? .basic }
  var title: String {
    switch self {
    case .basic: "Basic"; case .fast: "Fast"; case .armored: "Armored"; case .magnetic: "Magnetic"
    case .repel: "Repel"; case .golden: "Golden"; case .frozen: "Frozen"; case .boss: "Boss"
    }
  }
  /// The full explanation, shown when you meet it and in the bubble guide.
  var detail: String {
    switch self {
    case .basic: "The everyday bubble. Each tap splits it into two smaller ones, down to the smallest size, which pops for good."
    case .fast: "Moves about half again as fast as a basic bubble, and its pieces stay fast. Deal with these before they reach the hinge."
    case .armored: "Its helmet takes the first hit, for a few points, and the bubble keeps going. The next tap splits it. Heavy, so it shoves lighter bubbles around."
    case .magnetic: "Pulls nearby bubbles on its side of the hinge toward it, which bunches them up. Good for chain bursts, and bad when it drags them over the line."
    case .repel: "Pushes nearby bubbles on its side away from it, sometimes straight at the hinge. Split it early if it is near the line."
    case .golden: "Worth 5 times the points, and it splits into basic bubbles. It moves fast, so grab it while your combo is high."
    case .frozen: "Slow and heavy, so it gives you time, but it is hard to knock off course once it is heading for the hinge."
    case .boss: "Too big to cross. Each slam on the hinge charges your meter. Tap it to wear down each phase. Every phase it gets faster, sends out fast bubbles and drops a Chain Burst."
    }
  }
}

extension PowerUp {
  var artKind: PowerKind { PowerKind(rawValue: rawValue) ?? .shield }
  var title: String {
    switch self {
    case .overcharge: "Overcharge"; case .freeze: "Freeze"; case .focus: "Focus"; case .shield: "Shield"; case .chainBurst: "Chain Burst"
    }
  }
  var detail: String {
    switch self {
    case .overcharge: "For 8 seconds every bubble scores double. The risk: a crossing charges your meter twice."
    case .freeze: "Slows all the bubbles to about a third of their speed for 3 seconds. Your timers keep running."
    case .focus: "For 4 seconds the smallest bubbles pop by themselves, and then small ones split. Points count, but your streak does not grow."
    case .shield: "Restores one shield, up to the maximum of 3."
    case .chainBurst: "Pops or splits every bubble around it, right away. Best when a magnetic bubble has bunched them up."
    }
  }
}
