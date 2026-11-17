import SpriteKit
import UIKit

/// Flying bits with a little physics: bubble-film shards from a pop, shield pieces, glow puffs and the stars
/// that fly to the top when a level is cleared. A fixed pool of sprites made up front and moved by one loop,
/// so a busy screen never makes a node or runs an action per bit.
@MainActor
final class Debris {
  private struct Bit {
    var v = CGVector.zero
    var spin: CGFloat = 0
    var life = 0.0
    var total = 1.0
    var gravity: CGFloat = 0
    var drag: CGFloat = 0
    var size = CGSize.zero
    var scale0: CGFloat = 1
    var scale1: CGFloat = 1
    var alpha0: CGFloat = 1
    /// Homing: after `homeAt` seconds it stops flying free and eases into `home`.
    var home: CGPoint?
    var homeAt = 0.0
    var from = CGPoint.zero
    var tag = 0
  }
  private var nodes: [SKSpriteNode] = []
  private var bits: [Bit] = []
  private var next = 0
  private var live = 0
  /// Called when a homing bit arrives, with its tag and where it landed.
  var onLand: (Int, CGPoint) -> Void = { _, _ in }

  init(parent: SKNode, count: Int, z: CGFloat) {
    for _ in 0..<count {
      let n = SKSpriteNode()
      n.zPosition = z
      n.isHidden = true
      n.colorBlendFactor = 1
      parent.addChild(n)
      nodes.append(n)
      bits.append(Bit())
    }
  }

  /// Throws one bit. Returns false when there's no texture yet (art still warming up).
  @discardableResult
  func emit(_ texture: SKTexture?, at p: CGPoint, v: CGVector = .zero, spin: CGFloat = 0, rotation: CGFloat = 0, life: Double,
            gravity: CGFloat = 0, drag: CGFloat = 0, size: CGSize, scale: (CGFloat, CGFloat) = (1, 1), alpha: CGFloat = 1,
            color: UIColor = .white, add: Bool = false, home: CGPoint? = nil, homeAt: Double = 0, tag: Int = 0) -> Bool {
    guard let texture, life > 0 else { return false }
    // Take a free slot; if all are flying, reuse the oldest-started one.
    var i = next
    for k in 0..<bits.count {
      let j = (next + k) % bits.count
      if bits[j].life <= 0 { i = j; break }
    }
    next = (i + 1) % bits.count
    let n = nodes[i]
    if bits[i].life <= 0 { live += 1 }
    bits[i] = Bit(v: v, spin: spin, life: life, total: life, gravity: gravity, drag: drag, size: size, scale0: scale.0, scale1: scale.1,
                  alpha0: alpha, home: home, homeAt: homeAt, from: p, tag: tag)
    n.texture = texture
    n.size = size
    n.position = p
    n.zRotation = rotation
    n.color = color
    n.blendMode = add ? .add : .alpha
    n.alpha = alpha
    n.setScale(scale.0)
    n.isHidden = false
    return true
  }

  func update(_ dt: Double) {
    guard live > 0, dt > 0 else { return }
    let fdt = CGFloat(dt)
    for i in bits.indices where bits[i].life > 0 {
      var b = bits[i]
      let n = nodes[i]
      b.life -= dt
      let age = b.total - b.life
      if let home = b.home, age >= b.homeAt {
        // Ease into the target, faster as it gets there.
        let span = max(0.01, b.total - b.homeAt)
        let k = CGFloat(min(1, (age - b.homeAt) / span)), e = k * k * k
        n.position = CGPoint(x: b.from.x + (home.x - b.from.x) * e, y: b.from.y + (home.y - b.from.y) * e + sin(k * .pi) * 40)
        n.setScale(b.scale0 + (b.scale1 - b.scale0) * e)
        n.zRotation += b.spin * fdt * (1 - k)
        if b.life <= 0 { onLand(b.tag, home) }
      } else {
        b.v.dy += b.gravity * fdt
        let keep = exp(-b.drag * fdt)
        b.v = CGVector(dx: b.v.dx * keep, dy: b.v.dy * keep)
        n.position.x += b.v.dx * fdt
        n.position.y += b.v.dy * fdt
        n.zRotation += b.spin * fdt
        b.from = n.position
        if b.home == nil {
          let k = CGFloat(age / b.total)
          n.setScale(b.scale0 + (b.scale1 - b.scale0) * k)
          // Full for the first half, then out.
          n.alpha = b.alpha0 * min(1, CGFloat(b.life / (b.total * 0.5)))
        }
      }
      if b.life <= 0 { n.isHidden = true; live -= 1 }
      bits[i] = b
    }
  }

  func reset() {
    for i in bits.indices { bits[i].life = 0; nodes[i].isHidden = true }
    live = 0
  }
}
