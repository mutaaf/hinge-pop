#if DEBUG
import SwiftUI

/// `-hitCheck` (debug builds): asks the real hit test which journey stops on screen would get a tap, without a
/// finger or a mouse. Each stop carries a tiny UIKit probe; a stop whose probe isn't what the window hits at its
/// centre is covered by something else. `JourneyTests` reads the result (works on a Mac, where UI tests can't click).
enum HitCheck {
  static let on = Debug.has("-hitCheck")

  /// "ok=2,3,4;blocked=" for the stops inside the journey's scroll view.
  @MainActor static func report() -> String {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
          let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first else { return "no window" }
    func all(_ v: UIView) -> [UIView] { [v] + v.subviews.flatMap(all) }
    var ok: [Int] = [], blocked: [Int] = []
    for p in all(window).compactMap({ $0 as? HitProbeView }).sorted(by: { $0.level < $1.level }) {
      let c = p.convert(CGPoint(x: p.bounds.midX, y: p.bounds.midY), to: window)
      // Only stops the path actually shows (not ones scrolled under the top bar).
      var scroll = p.superview
      while let s = scroll, !(s is UIScrollView) { scroll = s.superview }
      guard let scroll, scroll.convert(scroll.bounds, to: window).insetBy(dx: 0, dy: 4).contains(c) else { continue }
      if window.hitTest(c, with: nil) === p { ok.append(p.level) } else { blocked.append(p.level) }
    }
    return "ok=\(ok.map(String.init).joined(separator: ","));blocked=\(blocked.map(String.init).joined(separator: ","))"
  }
}

final class HitProbeView: UIView {
  var level = 0
}

/// A transparent 8 pt UIKit view at a stop's centre.
struct HitProbe: UIViewRepresentable {
  let level: Int
  func makeUIView(context: Context) -> HitProbeView {
    let v = HitProbeView()
    v.backgroundColor = .clear
    v.level = level
    return v
  }
  func updateUIView(_ v: HitProbeView, context: Context) { v.level = level }
}
#endif
