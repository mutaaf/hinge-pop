import SpriteKit
import UIKit
import HingePopCore

/// Draws each world's twist and boss style so it reads at a glance: wind streaks, swirling wells, the tide's
/// range, fog, the dark, portal rims, the beat, springs and regrowth, shields and twin tethers.
/// Every node is built once and reused. Big surfaces are shaders, so nothing is rendered mid-play.
@MainActor
final class TwistLayer {
  /// What the scene does for us: sparks, shockwaves and sky ripples, in world coordinates.
  struct Host {
    var sparks: (CGPoint, CGFloat, Int, UIColor?) -> Void
    var shockwave: (CGPoint, CGFloat) -> Void
    var ripple: (CGPoint) -> Void
  }
  private let root = SKNode()
  private let dot: SKTexture
  private let host: Host
  private var twists: [Twist] = []
  private var boss = BossStyle.crown
  private var tint = UIColor.white
  private var tintVec = vector_float3(1, 1, 1)
  private var areaH: CGFloat = 1
  private var clock = 0.0
  private func y(_ gameY: Double) -> CGFloat { areaH - CGFloat(gameY) }

  // Wind
  private var streaks: [(node: SKSpriteNode, speed: CGFloat)] = []
  // Wells
  private var wellNodes: [SKSpriteNode] = []
  private let wellTime = SKUniform(name: "u_t", float: 0)
  private let wellTint = SKUniform(name: "u_tint", vectorFloat3: .init(1, 1, 1))
  private var wellShader: SKShader!
  // Tide
  private let tideBand = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private let tideTime = SKUniform(name: "u_t", float: 0)
  private let tideAxis = SKUniform(name: "u_axis", float: 0)
  private let tideTint = SKUniform(name: "u_tint", vectorFloat3: .init(1, 1, 1))
  // Fog
  private let fog = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private let fogU = (t: SKUniform(name: "u_t", float: 0), axis: SKUniform(name: "u_axis", float: 0), hinge: SKUniform(name: "u_hinge", float: 0),
                      lo: SKUniform(name: "u_lo", float: 0), hi: SKUniform(name: "u_hi", float: 1), clear: SKUniform(name: "u_clear", float: 0.4),
                      dense: SKUniform(name: "u_dense", float: 0.8), tint: SKUniform(name: "u_tint", vectorFloat3: .init(0.7, 0.75, 0.9)))
  // Blackout
  private let dark = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private let darkU = (t: SKUniform(name: "u_t", float: 0), axis: SKUniform(name: "u_axis", float: 0), hinge: SKUniform(name: "u_hinge", float: 0),
                       band: SKUniform(name: "u_band", float: 90), lamp: SKUniform(name: "u_lamp", vectorFloat4: .init(0, 0, 0, 1)),
                       size: SKUniform(name: "u_size", vectorFloat2: .init(1, 1)))
  private var lampGlow = 0.0
  private var lampAt = CGPoint.zero
  // Portals
  private var rims: [SKSpriteNode] = []
  private let rimTime = SKUniform(name: "u_t", float: 0)
  private let rimTint = SKUniform(name: "u_tint", vectorFloat3: .init(1, 1, 1))
  private var rimFlash = [SKUniform(name: "u_flash", float: 0), SKUniform(name: "u_flash", float: 0)]
  private var flash = [0.0, 0.0]
  // Pulse
  private var rings: [(node: SKSpriteNode, age: Double, dir: CGFloat)] = []
  private var nextRing = 0
  /// Added to the hinge's glow by the scene: the line flashes on each beat.
  private(set) var hingeBoost = 0.0
  // Bosses
  private var shieldNodes: [Int: SKSpriteNode] = [:]
  private var spareShields: [SKSpriteNode] = []
  private var shieldTexture: SKTexture?
  private let tether = SKSpriteNode()
  private var lastSpring = 0.0

  init(parent: SKNode, dot: SKTexture, host: Host) {
    self.dot = dot
    self.host = host
    parent.addChild(root)

    // Wind: soft streaks that race across the line while a gust blows.
    var d = SystemRandomNumberGenerator()
    for i in 0..<28 {
      let n = SKSpriteNode(texture: dot, size: CGSize(width: 40, height: 3))
      n.blendMode = .add
      n.zPosition = 4.5
      n.colorBlendFactor = 1
      n.isHidden = true
      root.addChild(n)
      streaks.append((n, CGFloat.random(in: 0.6...1.4, using: &d) * (i % 3 == 0 ? 1.3 : 1)))
    }

    // Wells: three spiral arms winding into a white-hot core.
    wellShader = SKShader(source: """
    void main() {
      vec2 p = v_tex_coord * 2.0 - 1.0;
      float r = length(p);
      if (r >= 1.0) { gl_FragColor = vec4(0.0); return; }
      float ang = atan(p.y, p.x);
      float s = u_spin;
      float arms = 0.5 + 0.5 * sin(ang * 3.0 - s * u_t * 2.4 + s * log(r + 0.04) * 5.5);
      float fade = 1.0 - smoothstep(0.35, 1.0, r);
      float core = exp(-r * r * 46.0);
      float halo = exp(-(r - 0.18) * (r - 0.18) * 160.0) * 0.5;
      vec3 col = mix(u_tint, vec3(1.0), clamp(core * 1.4 + halo * 0.6, 0.0, 1.0));
      float a = clamp(arms * fade * 0.5 + core * 0.95 + halo, 0.0, 1.0) * u_a;
      gl_FragColor = vec4(col * a, a);
    }
    """)
    wellShader.uniforms = [wellTime, wellTint]
    wellShader.attributes = [SKAttribute(name: "u_spin", type: .float), SKAttribute(name: "u_a", type: .float)]

    // Tide: the band the line sweeps, with flowing water marks at its high and low points.
    let tide = SKShader(source: """
    void main() {
      vec2 uv = v_tex_coord;
      float a = u_axis < 0.5 ? uv.y : uv.x;
      float al = u_axis < 0.5 ? uv.x : uv.y;
      float e0 = exp(-a * a * 900.0), e1 = exp(-(1.0 - a) * (1.0 - a) * 900.0);
      float dash = 0.35 + 0.65 * step(0.45, fract(al * 26.0 - u_t * 0.6));
      float body = 0.07 * (1.0 - abs(a - 0.5) * 2.0) * (0.7 + 0.3 * sin(al * 40.0 + u_t * 1.3 + a * 9.0));
      float alpha = clamp((e0 + e1) * 0.55 * dash + body, 0.0, 0.7);
      gl_FragColor = vec4(u_tint * alpha, alpha);
    }
    """)
    tide.uniforms = [tideTime, tideAxis, tideTint]
    tideBand.shader = tide
    tideBand.blendMode = .add
    tideBand.zPosition = 0.5
    tideBand.isHidden = true
    root.addChild(tideBand)

    // Fog: drifting banks that thicken away from the line, drawn over the bubbles.
    let fogShader = SKShader(source: """
    void main() {
      vec2 p = v_tex_coord;
      float a = u_axis < 0.5 ? p.y : p.x;
      float al = u_axis < 0.5 ? p.x : p.y;
      float d = a > u_hinge ? (a - u_hinge) / max(0.001, u_hi - u_hinge) : (u_hinge - a) / max(0.001, u_hinge - u_lo);
      float n = sin(al * 9.0 + u_t * 0.35 + 1.5 * sin(a * 7.0 - u_t * 0.2)) * 0.5
              + sin(al * 23.0 - u_t * 0.5 + a * 11.0) * 0.25 + sin(al * 4.0 + a * 3.0 + u_t * 0.15) * 0.25;
      float f = smoothstep(u_clear, u_dense, d + n * 0.07);
      float alpha = clamp(f * (0.66 + 0.14 * n), 0.0, 0.86);
      gl_FragColor = vec4(u_tint * alpha, alpha);
    }
    """)
    fogShader.uniforms = [fogU.t, fogU.axis, fogU.hinge, fogU.lo, fogU.hi, fogU.clear, fogU.dense, fogU.tint]
    fog.shader = fogShader
    fog.anchorPoint = .zero
    fog.zPosition = 5.6
    fog.isHidden = true
    root.addChild(fog)

    // Blackout: the dark, except for a band along the line and a pool of light where you touched.
    let darkShader = SKShader(source: """
    void main() {
      vec2 p = v_tex_coord * u_size;
      float a = u_axis < 0.5 ? p.y : p.x;
      float near = 1.0 - smoothstep(u_band * 0.75, u_band * 1.35, abs(a - u_hinge));
      float l = length(p - u_lamp.xy);
      float lamp = u_lamp.z * (1.0 - smoothstep(u_lamp.w * 0.5, u_lamp.w * 1.15, l));
      float light = max(near, lamp);
      float grain = 0.96 + 0.04 * sin(u_t * 9.0 + p.x * 0.07 + p.y * 0.05);
      float alpha = (1.0 - light) * 0.9 * grain;
      vec3 col = mix(vec3(0.0, 0.0, 0.03), vec3(0.04, 0.02, 0.1), light);
      gl_FragColor = vec4(col * alpha, alpha);
    }
    """)
    darkShader.uniforms = [darkU.t, darkU.axis, darkU.hinge, darkU.band, darkU.lamp, darkU.size]
    dark.shader = darkShader
    dark.anchorPoint = .zero
    dark.zPosition = 4.6
    dark.isHidden = true
    root.addChild(dark)

    // Portals: shimmering rims on the two walls at the ends of the line.
    for i in 0..<2 {
      let rim = SKShader(source: """
      void main() {
        vec2 uv = v_tex_coord;
        float e = uv.x;
        float al = uv.y;
        float swirl = 0.5 + 0.5 * sin(al * 34.0 - u_t * 5.0 + 2.0 * sin(al * 7.0 + u_t * 1.3));
        float g = exp(-e * 3.6) * (0.5 + 0.5 * swirl) + u_flash * exp(-e * 1.6);
        vec3 col = mix(u_tint, vec3(1.0), exp(-e * 12.0) * 0.75 + u_flash * 0.3);
        float a = clamp(g, 0.0, 1.0) * smoothstep(0.0, 0.06, al) * smoothstep(1.0, 0.94, al);
        gl_FragColor = vec4(col * a, a);
      }
      """)
      rim.uniforms = [rimTime, rimTint, rimFlash[i]]
      let n = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
      n.shader = rim
      n.blendMode = .add
      n.zPosition = 4
      n.isHidden = true
      root.addChild(n)
      rims.append(n)
    }

    // Pulse: a pair of light lines run out from the hinge on every beat.
    for _ in 0..<6 {
      let n = SKSpriteNode(texture: dot, size: CGSize(width: 10, height: 14))
      n.blendMode = .add
      n.zPosition = 0.6
      n.colorBlendFactor = 1
      n.isHidden = true
      root.addChild(n)
      rings.append((n, 9, 1))
    }

    tether.texture = dot
    tether.blendMode = .add
    tether.colorBlendFactor = 1
    tether.zPosition = 4.4
    tether.isHidden = true
    root.addChild(tether)
  }

  // MARK: Level

  func reset(_ game: Game, arena: Arena) {
    twists = game.spec.twists
    boss = game.spec.boss
    let palette = arena.sparkColors
    tint = palette.count > 1 ? palette[1] : .white
    var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1
    tint.getRed(&r, green: &g, blue: &b, alpha: nil)
    tintVec = .init(Float(r), Float(g), Float(b))
    wellTint.vectorFloat3Value = tintVec
    tideTint.vectorFloat3Value = tintVec
    rimTint.vectorFloat3Value = tintVec
    fogU.tint.vectorFloat3Value = .init(0.62 + 0.2 * Float(r), 0.66 + 0.2 * Float(g), 0.78 + 0.2 * Float(b))
    for n in wellNodes { n.removeFromParent() }
    wellNodes = game.wells.map { w in
      let n = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
      n.shader = wellShader
      n.setValue(SKAttributeValue(float: Float(w.spin)), forAttribute: "u_spin")
      n.setValue(SKAttributeValue(float: 0), forAttribute: "u_a")
      n.blendMode = .add
      n.zPosition = 0.4
      root.addChild(n)
      return n
    }
    for (_, n) in shieldNodes { n.removeFromParent(); spareShields.append(n) }
    shieldNodes.removeAll()
    for s in streaks { s.node.color = tint; s.node.isHidden = true }
    for i in rings.indices { rings[i].age = 9; rings[i].node.isHidden = true; rings[i].node.color = palette.first ?? .white }
    lampGlow = 0
    flash = [0, 0]
    hingeBoost = 0
    tether.isHidden = true
  }

  private func has(_ t: Twist) -> Bool { twists.contains(t) }

  // MARK: Frame

  func update(_ game: Game, area: CGSize, clock: Double, dt: Double, reduceMotion: Bool) {
    areaH = area.height
    self.clock = clock
    let t = Float(reduceMotion ? 0 : clock.truncatingRemainder(dividingBy: 1000))
    let vertical = game.vertical
    drawWind(game, area: area, dt: dt, reduceMotion: reduceMotion)
    // Wells swell in as the level starts and spin with the clock.
    wellTime.floatValue = t
    for (i, w) in game.wells.enumerated() where i < wellNodes.count {
      let n = wellNodes[i]
      n.position = CGPoint(x: w.x, y: y(w.y))
      n.size = CGSize(width: w.reach * 2, height: w.reach * 2)
      n.setValue(SKAttributeValue(float: Float(min(1, 0.3 + game.time * 0.5))), forAttribute: "u_a")
    }
    // The tide: a band showing how far the line will travel.
    if has(.tide), game.tideReachNow > 1 {
      tideBand.isHidden = false
      tideTime.floatValue = t
      let reach = CGFloat(game.tideReachNow) * 2
      if vertical {
        tideAxis.floatValue = 1
        tideBand.size = CGSize(width: reach, height: CGFloat(game.h - game.top))
        tideBand.position = CGPoint(x: game.baseHinge, y: y(game.top) - CGFloat(game.h - game.top) / 2)
      } else {
        tideAxis.floatValue = 0
        tideBand.size = CGSize(width: CGFloat(game.w), height: reach)
        tideBand.position = CGPoint(x: game.w / 2, y: y(game.baseHinge))
      }
    } else { tideBand.isHidden = true }
    // Fog over everything far from the line.
    if has(.fog) {
      fog.isHidden = false
      fog.size = area
      fog.position = .zero
      fogU.t.floatValue = t
      fogU.axis.floatValue = vertical ? 1 : 0
      if vertical {
        fogU.hinge.floatValue = Float(game.hinge / game.w); fogU.lo.floatValue = 0; fogU.hi.floatValue = 1
      } else {
        // Texture y runs up the screen: the far wall is at the bottom.
        fogU.hinge.floatValue = Float(y(game.hinge) / area.height); fogU.lo.floatValue = 0; fogU.hi.floatValue = Float(y(game.top) / area.height)
      }
      let clear = game.tuning.fogClear + (1 - min(1, game.spec.intensity)) * 0.3
      fogU.clear.floatValue = Float(clear - 0.06)
      fogU.dense.floatValue = Float(game.tuning.fogDense + 0.08)
    } else { fog.isHidden = true }
    // The dark, with the line's band and the last touch's lantern cut out of it.
    if has(.blackout) {
      dark.isHidden = false
      dark.size = area
      darkU.size.vectorFloat2Value = .init(Float(area.width), Float(area.height))
      darkU.t.floatValue = t
      darkU.axis.floatValue = vertical ? 1 : 0
      darkU.hinge.floatValue = Float(vertical ? CGFloat(game.hinge) : y(game.hinge))
      darkU.band.floatValue = Float(game.darkBand)
      let target = game.lantern.map { min(1, $0.left / 0.5) } ?? 0
      if let l = game.lantern { lampAt = CGPoint(x: l.x, y: y(l.y)) }
      lampGlow += (target - lampGlow) * min(1, dt * (target > lampGlow ? 18 : 5))
      darkU.lamp.vectorFloat4Value = .init(Float(lampAt.x), Float(lampAt.y), Float(lampGlow), Float(game.tuning.lanternReach * game.scale))
    } else { dark.isHidden = true }
    // Portal rims on the walls at each end of the line.
    if has(.portals) {
      rimTime.floatValue = t
      let thick: CGFloat = 30 * CGFloat(max(1, min(1.5, game.scale)))
      for (i, rim) in rims.enumerated() {
        rim.isHidden = false
        flash[i] = max(0, flash[i] - dt * 3)
        rimFlash[i].floatValue = Float(flash[i])
        if vertical {
          let span = CGFloat(game.w)
          rim.size = CGSize(width: thick, height: span)
          rim.zRotation = i == 0 ? -.pi / 2 : .pi / 2
          rim.position = CGPoint(x: span / 2, y: i == 0 ? y(game.top) - thick / 2 : y(game.h) + thick / 2)
        } else {
          let span = CGFloat(game.h - game.top)
          rim.size = CGSize(width: thick, height: span)
          rim.zRotation = i == 0 ? 0 : .pi
          rim.position = CGPoint(x: i == 0 ? thick / 2 : CGFloat(game.w) - thick / 2, y: y(game.top) - span / 2)
        }
      }
    } else { rims.forEach { $0.isHidden = true } }
    // The beat: lines run out from the hinge and the hinge itself flares.
    hingeBoost = has(.pulse) && !reduceMotion ? 0.55 * exp(-game.beatPhase * 6) : 0
    for i in rings.indices where rings[i].age < 1 {
      rings[i].age += dt * 1.6
      let a = rings[i].age, n = rings[i].node
      n.isHidden = a >= 1
      let off = CGFloat(a) * 150 * CGFloat(game.scale) * rings[i].dir
      if vertical { n.position = CGPoint(x: CGFloat(game.hinge) + off, y: y((game.top + game.h) / 2)); n.size = CGSize(width: 14, height: CGFloat(game.h - game.top)) }
      else { n.position = CGPoint(x: game.w / 2, y: y(game.hinge) - off); n.size = CGSize(width: CGFloat(game.w), height: 14) }
      n.alpha = CGFloat((1 - a) * (1 - a)) * 0.8
    }
    drawBossExtras(game)
  }

  private func drawWind(_ game: Game, area: CGSize, dt: Double, reduceMotion: Bool) {
    guard has(.wind) else { if !(streaks.first?.node.isHidden ?? true) { streaks.forEach { $0.node.isHidden = true } }; return }
    let peak = max(1, game.windPeak)
    let strength = abs(game.wind) / peak
    // A few faint streaks gather in the second before a gust, from the side it'll blow from.
    let warn = game.gustIn > 0 && game.gustIn < game.tuning.windWarn ? 1 - game.gustIn / game.tuning.windWarn : 0
    let dir = CGFloat(game.wind != 0 ? (game.wind > 0 ? 1 : -1) : game.windDir)
    let show = max(strength, warn * 0.35)
    for (i, s) in streaks.enumerated() {
      let n = s.node
      guard show > 0.02 else { n.isHidden = true; continue }
      if n.isHidden {
        n.isHidden = false
        n.position = CGPoint(x: .random(in: 0...max(1, area.width)), y: .random(in: 0...max(1, y(game.top))))
      }
      let speed = CGFloat(reduceMotion ? 0 : (abs(game.wind) * 3.2 + 60 * warn + 40)) * s.speed
      let len = 18 + CGFloat(strength) * 70 * s.speed
      // Across the line means down the screen for a horizontal hinge (game y grows down).
      if game.vertical {
        n.zRotation = 0
        n.size = CGSize(width: len, height: 2.5)
        n.position.x += dir * speed * CGFloat(dt)
        if n.position.x > area.width + 60 { n.position.x = -60 } else if n.position.x < -60 { n.position.x = area.width + 60 }
      } else {
        n.zRotation = .pi / 2
        n.size = CGSize(width: len, height: 2.5)
        n.position.y -= dir * speed * CGFloat(dt)
        let top = y(game.top)
        if n.position.y < -60 { n.position.y = top + 60 } else if n.position.y > top + 60 { n.position.y = -60 }
      }
      n.alpha = CGFloat(show) * (i % 4 == 0 ? 0.75 : 0.42)
    }
  }

  private func drawBossExtras(_ game: Game) {
    let bosses = game.bubbles.filter { $0.kind == .boss }
    // Shields: a bright arc that turns around the boss.
    if boss == .shielded {
      var seen = Set<Int>()
      for b in bosses {
        seen.insert(b.id)
        let n = shieldNodes[b.id] ?? makeShield(b.id)
        let side = CGFloat(b.r * 2.5)
        n.size = CGSize(width: side, height: side)
        n.position = CGPoint(x: b.x, y: y(b.y))
        // Game angles grow clockwise on screen (y down), scene angles counterclockwise.
        n.zRotation = -CGFloat(b.shieldAngle)
        n.alpha = b.bossGuard > 0 ? 0.6 : 1
      }
      for (id, n) in shieldNodes where !seen.contains(id) { n.removeFromParent(); spareShields.append(n); shieldNodes[id] = nil }
    }
    // Twins: a faint tether of light between them, the shared health bar made visible.
    if boss == .twins, bosses.count == 2 {
      let a = CGPoint(x: bosses[0].x, y: y(bosses[0].y)), b = CGPoint(x: bosses[1].x, y: y(bosses[1].y))
      tether.isHidden = false
      tether.size = CGSize(width: max(1, hypot(b.x - a.x, b.y - a.y)), height: 10)
      tether.position = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
      tether.zRotation = atan2(b.y - a.y, b.x - a.x)
      tether.color = tint
      tether.alpha = CGFloat(0.22 + 0.1 * sin(clock * 3))
    } else if !tether.isHidden { tether.isHidden = true }
  }

  private func makeShield(_ id: Int) -> SKSpriteNode {
    let n = spareShields.popLast() ?? SKSpriteNode(texture: shieldTexture ?? Self.shieldArt())
    if shieldTexture == nil { shieldTexture = n.texture }
    n.texture = shieldTexture
    n.zPosition = 5.5
    n.blendMode = .alpha
    root.addChild(n)
    shieldNodes[id] = n
    return n
  }

  /// A thick golden arc facing +x, drawn once.
  private static func shieldArt() -> SKTexture {
    let px = 160
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let c = CGPoint(x: px / 2, y: px / 2), r = CGFloat(px) * 0.43
    let arc = CGFloat(1.15)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(UIColor(red: 1, green: 0.78, blue: 0.25, alpha: 0.35).cgColor)
    ctx.setLineWidth(18)
    ctx.addArc(center: c, radius: r, startAngle: -arc, endAngle: arc, clockwise: false)
    ctx.strokePath()
    ctx.setStrokeColor(UIColor(red: 1, green: 0.86, blue: 0.4, alpha: 1).cgColor)
    ctx.setLineWidth(9)
    ctx.addArc(center: c, radius: r, startAngle: -arc, endAngle: arc, clockwise: false)
    ctx.strokePath()
    ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.95).cgColor)
    ctx.setLineWidth(3)
    ctx.addArc(center: c, radius: r + 1, startAngle: -arc * 0.8, endAngle: arc * 0.8, clockwise: false)
    ctx.strokePath()
    // Rivets.
    ctx.setFillColor(UIColor.white.cgColor)
    for a in stride(from: -arc * 0.66, through: arc * 0.66, by: arc * 0.66) {
      ctx.fillEllipse(in: CGRect(x: c.x + cos(a) * r - 3, y: c.y + sin(a) * r - 3, width: 6, height: 6))
    }
    return SKTexture(cgImage: ctx.makeImage()!)
  }

  // MARK: Bubbles

  /// How a bubble shows under this world's twist: how visible it is, a tint and a throb.
  func look(_ b: Bubble, game: Game) -> (alpha: CGFloat, tint: UIColor?, amount: CGFloat, scale: CGFloat) {
    guard !twists.isEmpty, b.kind != .boss else { return (1, nil, 0, 1) }
    var alpha: CGFloat = 1, tintColor: UIColor?, amount: CGFloat = 0, scale: CGFloat = 1
    if has(.fog) { alpha *= CGFloat(0.06 + 0.94 * game.visibility(b)) }
    if has(.blackout) {
      let glow = min(1, b.lit / 0.35)
      alpha *= CGFloat(0.13 + 0.87 * glow)
    }
    if has(.ghost) {
      alpha *= CGFloat(0.16 + 0.84 * b.presence)
      if b.presence < 1 {
        tintColor = UIColor(red: 0.55, green: 0.95, blue: 1, alpha: 1); amount = CGFloat(0.6 * (1 - b.presence))
        scale = 1 + CGFloat(sin(clock * 30 + Double(b.id)) * 0.04 * (1 - b.presence))
      }
    }
    if has(.bounce), b.spring > 1.01 {
      tintColor = UIColor(red: 1, green: 0.42, blue: 0.75, alpha: 1); amount = CGFloat(min(0.55, (b.spring - 1) * 0.9))
    }
    if has(.regrow), b.regrow > 0.55 {
      let k = (b.regrow - 0.55) / 0.45
      tintColor = UIColor(red: 0.45, green: 1, blue: 0.5, alpha: 1); amount = CGFloat(0.4 * k)
      scale = 1 + CGFloat(0.07 * k * max(0, sin(clock * (8 + 10 * k))))
    }
    return (alpha, tintColor, amount, scale)
  }

  // MARK: Events

  /// Moments worth juicing. Returns true when it handled the event.
  func effect(_ e: GameEvent, game: Game?) -> Bool {
    let sound = Sound.shared
    switch e {
    case let .gust(dir):
      if let game {
        let at = game.vertical ? CGPoint(x: dir > 0 ? 0 : CGFloat(game.w), y: y((game.top + game.h) / 2)) : CGPoint(x: game.w / 2, y: dir > 0 ? y(game.top) : y(game.h))
        host.ripple(at)
      }
      sound.blip(110, 0.5, .saw, gain: 0.05)
    case .beat:
      for dir: CGFloat in [-1, 1] {
        rings[nextRing].age = 0; rings[nextRing].dir = dir; rings[nextRing].node.isHidden = false
        nextRing = (nextRing + 1) % rings.count
      }
      sound.blip(70, 0.08, .sine, gain: 0.05)
    case let .beatPop(x, gy, _):
      let at = CGPoint(x: x, y: y(gy))
      host.sparks(at, 34, 22, UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1))
      host.shockwave(at, 46)
      sound.blip(990, 0.08, .square, gain: 0.07)
      Haptics.shared.good()
    case let .portal(fromX, fromY, x, gy, r):
      host.sparks(CGPoint(x: fromX, y: y(fromY)), CGFloat(r), 12, tint)
      host.sparks(CGPoint(x: x, y: y(gy)), CGFloat(r), 16, .white)
      if let game {
        let leftOrTop = game.vertical ? gy < (game.top + game.h) / 2 : x < game.w / 2
        flash[leftOrTop ? 0 : 1] = 1
      }
      sound.blip(1300, 0.06, .sine, gain: 0.07)
    case let .spring(x, gy, r):
      guard clock - lastSpring > 0.06 else { return true }
      lastSpring = clock
      host.sparks(CGPoint(x: x, y: y(gy)), CGFloat(r) * 0.7, 8, UIColor(red: 1, green: 0.45, blue: 0.78, alpha: 1))
      sound.blip(520, 0.05, .square, gain: 0.04)
    case let .regrow(x, gy, r, _):
      let at = CGPoint(x: x, y: y(gy))
      host.shockwave(at, CGFloat(r) * 1.5)
      host.sparks(at, CGFloat(r), 14, UIColor(red: 0.45, green: 1, blue: 0.55, alpha: 1))
      sound.blip(240, 0.14, .triangle, gain: 0.1)
    case let .untouchable(x, gy, r):
      host.sparks(CGPoint(x: x, y: y(gy)), CGFloat(r) * 0.5, 5, UIColor(white: 0.7, alpha: 1))
      sound.blip(160, 0.05, .sine, gain: 0.05)
    case let .bossBlink(fromX, fromY, x, gy, r):
      host.sparks(CGPoint(x: fromX, y: y(fromY)), CGFloat(r), 34, UIColor(red: 0.75, green: 0.5, blue: 1, alpha: 1))
      host.shockwave(CGPoint(x: x, y: y(gy)), CGFloat(r) * 1.3)
      host.ripple(CGPoint(x: x, y: y(gy)))
      sound.blip(1500, 0.06, .square, gain: 0.07); sound.blip(400, 0.12, .saw, gain: 0.08)
      Haptics.shared.hit()
    case let .bossSummon(x, gy, r, _):
      host.shockwave(CGPoint(x: x, y: y(gy)), CGFloat(r) * 1.8)
      sound.blip(220, 0.3, .triangle, gain: 0.12)
    case let .bossSplit(x, gy, r):
      host.sparks(CGPoint(x: x, y: y(gy)), CGFloat(r), 30, nil)
      host.shockwave(CGPoint(x: x, y: y(gy)), CGFloat(r) * 1.2)
      sound.blip(300, 0.16, .saw, gain: 0.12)
    case let .bossShielded(x, gy, r):
      host.sparks(CGPoint(x: x, y: y(gy)), CGFloat(r) * 0.8, 14, UIColor(red: 1, green: 0.86, blue: 0.4, alpha: 1))
      sound.blip(1800, 0.05, .square, gain: 0.08)
      Haptics.shared.tap()
    default:
      return false
    }
    return true
  }
}
