import SwiftUI
import HingePopCore

// iPhone Duo. Apple's rule: layout comes from the fold's reserved region, and the hinge angle only
// drives effects. So the fold says where the game's hinge sits, and the angle only makes it glow.
// On every device without a hinge none of this changes anything.

@MainActor @Observable
final class DuoModel {
  private(set) var degrees: Double?
  private(set) var pinnedPose: String?

  init() {
    #if DEBUG
    pinnedPose = Debug.string("-pose")
    if pinnedPose != nil { degrees = Double(Debug.int("-hinge") ?? 110) }
    #endif
  }
  var hasHinge: Bool { degrees != nil }
  var glow: Double { FoldLayout.glow(degrees: degrees) }
  func update(_ value: Double?) {
    guard pinnedPose == nil, value != degrees else { return }
    degrees = value
  }
}

struct TracksHinge: ViewModifier {
  let duo: DuoModel
  func body(content: Content) -> some View {
    if #available(iOS 27.1, *) {
      content.onHingeChange(isEnabled: duo.pinnedPose == nil) { _, new in
        duo.update(new.hinge.map { $0.angle.degrees })
      }
    } else {
      content
    }
  }
}

/// The fold in this view's own coordinates. Inactive regions count, so a Duo lying flat keeps the same
/// layout as one folded like a book, and folding only changes the glow.
@MainActor
func foldRect(_ proxy: GeometryProxy, duo: DuoModel) -> CGRect? {
  if #available(iOS 27.1, *),
     let r = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first,
     r.frame.intersects(CGRect(origin: .zero, size: proxy.size)) {
    return r.frame
  }
  #if DEBUG
  // The simulator cannot fold by script, so debug poses synthesize the fold.
  switch duo.pinnedPose {
  case "book", "flat": return CGRect(x: proxy.size.width / 2 - 20, y: 0, width: 40, height: proxy.size.height)
  case "tabletop": return CGRect(x: 0, y: proxy.size.height / 2 - 20, width: proxy.size.width, height: 40)
  default: break
  }
  #endif
  return nil
}
