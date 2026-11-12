import CoreText
import SpriteKit
import UIKit
import HingePopCore

// Game feel: time (hit-stop and slow motion), the camera (shake and zoom punch), screen-wide light
// (flash, vignette, edge warnings, fever), words that slam in (combo callouts, boss banners), the combo
// counter, chromatic bursts on the hinge, and confetti. Everything here is built once when the scene is
// made and reused, and every word is drawn off the main thread before play, so nothing is created mid-play.

/// The combo ladder: where each callout lands and its colour. Original words only.
enum ComboTier {
  static let steps: [(at: Double, word: Callout, color: UIColor)] = [
    (2, .nice, UIColor(red: 0.36, green: 0.9, blue: 1, alpha: 1)),
    (3, .sweet, UIColor(red: 0.42, green: 1, blue: 0.7, alpha: 1)),
    (4.5, .wild, UIColor(red: 1, green: 0.86, blue: 0.3, alpha: 1)),
    (6, .blazing, UIColor(red: 1, green: 0.58, blue: 0.22, alpha: 1)),
    (8, .unreal, UIColor(red: 1, green: 0.42, blue: 0.72, alpha: 1)),
    (10, .legendary, UIColor(red: 0.8, green: 0.6, blue: 1, alpha: 1)),
  ]
  /// 0 below the first callout, then 1 per step reached.
  static func tier(_ combo: Double) -> Int { steps.lastIndex { combo >= $0.at }.map { $0 + 1 } ?? 0 }
  static func color(_ tier: Int) -> UIColor { tier <= 0 ? UIColor(white: 0.92, alpha: 1) : steps[min(tier, steps.count) - 1].color }
}

/// Every word the game can slam onto the screen.
enum Callout: String, CaseIterable {
  case nice = "NICE!", sweet = "SWEET!", wild = "WILD!", blazing = "BLAZING!", unreal = "UNREAL!", legendary = "LEGENDARY!"
  case snap = "SNAP!", clap = "CLAP!", stagger = "STAGGER!", bossDown = "BOSS DOWN!", clear = "CLEAR!", flawless = "FLAWLESS!"
  case lastOne = "LAST ONE!", fever = "FEVER!", overtime = "OVERTIME!", faster = "FASTER!", shieldDown = "SHIELD DOWN!", surge = "SURGE!"
  case phase2 = "PHASE 2", phase3 = "PHASE 3", phase4 = "PHASE 4", finalPhase = "FINAL PHASE!", boss = "BOSS"
  case comboBreak = "COMBO LOST"

  /// Smaller words for notices that shouldn't shout.
  var points: CGFloat {
    switch self {
    case .boss, .comboBreak: 22
    case .shieldDown, .phase2, .phase3, .phase4, .finalPhase, .faster, .lastOne, .surge: 40
    default: 54
    }
  }
}

/// Draws words as chunky, slanted, outlined game type. Pure Core Graphics and Core Text, so it runs off the
/// main thread. The fill is a white-to-grey ramp, tinted at draw time, so one texture serves every colour.
enum CalloutArt {
  static func word(_ text: String, points: CGFloat, scale: CGFloat, weight: UIFont.Weight = .black) -> CGImage? {
    let base = UIFont.systemFont(ofSize: points, weight: weight)
    let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: points) } ?? base
    let attr = NSAttributedString(string: text, attributes: [.font: font, .kern: points * 0.02])
    let line = CTLineCreateWithAttributedString(attr)
    let b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let shear: CGFloat = 0.16
    let pad = points * 0.3
    let w = ceil(b.width + pad * 2 + shear * b.height), h = ceil(b.height + pad * 2)
    guard w > 1, h > 1, let ctx = CGContext(data: nil, width: Int(w * scale), height: Int(h * scale), bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.scaleBy(x: scale, y: scale)
    ctx.textMatrix = CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0)
    let origin = CGPoint(x: pad - b.minX - shear * b.minY, y: pad - b.minY)
    let ink = CGColor(srgbRed: 0.07, green: 0.03, blue: 0.16, alpha: 1)
    // A dark outline with a drop shadow, so the word reads over any sky.
    ctx.setShadow(offset: CGSize(width: 0, height: -points * 0.07), blur: points * 0.14, color: CGColor(gray: 0, alpha: 0.6))
    ctx.setLineJoin(.round)
    ctx.setLineWidth(points * 0.17)
    ctx.setStrokeColor(ink)
    ctx.setFillColor(ink)
    ctx.setTextDrawingMode(.fillStroke)
    ctx.textPosition = origin
    CTLineDraw(line, ctx)
    // The face: a vertical ramp clipped to the letters.
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.saveGState()
    ctx.setTextDrawingMode(.clip)
    ctx.textPosition = origin
    CTLineDraw(line, ctx)
    let ramp = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [
      CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 1), CGColor(gray: 0.74, alpha: 1), CGColor(gray: 0.9, alpha: 1),
    ] as CFArray, locations: [0, 0.42, 0.58, 1])!
    ctx.drawLinearGradient(ramp, start: CGPoint(x: 0, y: origin.y + b.maxY), end: CGPoint(x: 0, y: origin.y + b.minY), options: [])
    ctx.restoreGState()
    return ctx.makeImage()
  }

  /// The boss banner's band: dark in the middle, fading at the ends, with a bright rule top and bottom.
  static func plate(scale: CGFloat) -> CGImage? {
    let w: CGFloat = 512, h: CGFloat = 128
    guard let ctx = CGContext(data: nil, width: Int(w * scale), height: Int(h * scale), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.scaleBy(x: scale, y: scale)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let band = CGGradient(colorsSpace: space, colors: [
      CGColor(srgbRed: 0.05, green: 0.02, blue: 0.12, alpha: 0), CGColor(srgbRed: 0.05, green: 0.02, blue: 0.12, alpha: 0.88),
      CGColor(srgbRed: 0.05, green: 0.02, blue: 0.12, alpha: 0.88), CGColor(srgbRed: 0.05, green: 0.02, blue: 0.12, alpha: 0),
    ] as CFArray, locations: [0, 0.2, 0.8, 1])!
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 10, width: w, height: h - 20))
    ctx.drawLinearGradient(band, start: .zero, end: CGPoint(x: w, y: 0), options: [])
    ctx.restoreGState()
    let rule = CGGradient(colorsSpace: space, colors: [
      CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0),
    ] as CFArray, locations: [0, 0.3, 0.7, 1])!
    for y in [CGFloat(8), h - 12] {
      ctx.saveGState()
      ctx.clip(to: CGRect(x: 0, y: y, width: w, height: 4))
      ctx.drawLinearGradient(rule, start: .zero, end: CGPoint(x: w, y: 0), options: [])
      ctx.restoreGState()
    }
    return ctx.makeImage()
  }
}

@MainActor
final class FeelLayer {
  /// Sits at the safe-area corner like `world`, but never shakes, so words stay readable.
  let overlay = SKNode()
  var reduceMotion = false

  // MARK: Time

  private var stopLeft = 0.0
  private var lastStopAt = -10.0
  private var slowFrom = 1.0, slowLeft = 0.0, slowTotal = 1.0
  private var clock = 0.0
  /// How fast the rules run this frame: 0 during a hit-stop, below 1 in slow motion.
  private(set) var simScale = 1.0

  /// A few milliseconds of freeze on impact. Small ones are skipped right after another, so a busy screen
  /// never stutters; `force` is for the hits that must land (shields, bosses, snaps).
  func hitStop(_ seconds: Double, force: Bool = false) {
    guard !reduceMotion else { return }
    guard force || clock - lastStopAt > 0.22 else { return }
    lastStopAt = clock
    stopLeft = max(stopLeft, min(0.16, seconds))
  }

  /// Time slows to `scale` and eases back to full speed over `seconds`.
  func slowMo(_ scale: Double, for seconds: Double) {
    guard !reduceMotion else { return }
    slowFrom = min(slowLeft > 0 ? currentSlow : 1, scale)
    slowLeft = seconds; slowTotal = seconds
  }
  private var currentSlow: Double {
    guard slowLeft > 0 else { return 1 }
    let k = 1 - slowLeft / slowTotal
    return slowFrom + (1 - slowFrom) * k * k
  }

  // MARK: Camera

  private var trauma = 0.0
  private var kick = CGVector.zero
  private var punchAmount = 0.0
  private var punchAt = CGPoint.zero

  /// Adds shake. Trauma is squared on the way out, so small knocks stay small and big ones really rock.
  func shake(_ amount: Double) { trauma = min(1, max(trauma, amount) + amount * 0.25) }
  /// A shove in one direction that springs back, for hits with a direction (a snap pushes off the line).
  func shove(_ v: CGVector) { kick = CGVector(dx: kick.dx + v.dx, dy: kick.dy + v.dy) }
  /// A quick zoom toward a point.
  func punch(_ amount: Double, at p: CGPoint) {
    guard !reduceMotion else { return }
    punchAmount = max(punchAmount, amount); punchAt = p
  }

  /// Where `world` goes this frame, and its scale.
  func camera(origin: CGPoint) -> (CGPoint, CGFloat) {
    guard !reduceMotion else { return (origin, 1) }
    let t = clock
    let s = trauma * trauma * 11
    // Layered sines rather than random jitter: it reads as a shove, not as dropped frames.
    let dx = s * (sin(t * 53) * 0.6 + sin(t * 31 + 1.3) * 0.4) + kick.dx
    let dy = s * (cos(t * 61) * 0.6 + sin(t * 37 + 0.4) * 0.4) + kick.dy
    let scale = 1 + CGFloat(punchAmount)
    // Zoom about the punch point, so it stays put while everything else leans in.
    let zx = -punchAt.x * (scale - 1), zy = -punchAt.y * (scale - 1)
    return (CGPoint(x: origin.x + dx + zx, y: origin.y + dy + zy), scale)
  }

  // MARK: Screen light

  private let frameNode = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private let uRed = SKUniform(name: "u_red", float: 0)
  private let uWarn = SKUniform(name: "u_warn", float: 0)
  private let uWarnColor = SKUniform(name: "u_wc", vectorFloat3: .init(1, 0.25, 0.3))
  private let uFever = SKUniform(name: "u_fever", float: 0)
  private let uTime = SKUniform(name: "u_t", float: 0)
  private let uAspect = SKUniform(name: "u_aspect", float: 0.5)
  private let uMask = SKUniform(name: "u_mask", vectorFloat4: .init(0, 0.5, 1, 0))
  private let flashNode = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private var flashA = 0.0
  private var red = 0.0
  private var warn = 0.0
  /// Held warnings, set every frame by the scene: a boss winding up, overtime.
  var warnHold = 0.0
  var warnColor = UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1)
  /// 0...1, set every frame: how hot fever mode is.
  var fever = 0.0
  /// 0 none, 0.5 down to the last shield, 1 one crossing from losing it.
  var danger = 0.0
  /// For versus, the half of the screen a red pulse belongs to (axis, line, side, on).
  private var redMask = vector_float4(0, 0.5, 1, 0)
  private var beatClock = 0.0
  private var beatsInDanger = 0
  /// Called on each heartbeat, so the scene can play the haptic and thump.
  var onHeartbeat: (Double) -> Void = { _ in }

  func flash(_ amount: Double, _ color: UIColor = .white) {
    flashNode.color = color
    flashA = max(flashA, amount * (reduceMotion ? 0.35 : 1))
  }
  /// A red pulse in from the edges. `mask` limits it to one player's half in versus.
  func vignette(_ amount: Double, mask: vector_float4? = nil) {
    red = max(red, amount * (reduceMotion ? 0.6 : 1))
    redMask = mask ?? vector_float4(0, 0.5, 1, 0)
  }
  func warnPulse(_ amount: Double, color: UIColor) { warn = max(warn, amount); warnColor = color }

  // MARK: Words

  private var words: [String: SKTexture] = [:]
  private var calloutPool: [SKSpriteNode] = []
  private var nextCallout = 0
  private var calloutGlows: [SKSpriteNode] = []
  private let plate = SKSpriteNode()
  private let bannerEyebrow = SKSpriteNode()
  private let bannerTitle = SKSpriteNode()
  private let bannerSub = SKSpriteNode()

  // MARK: Combo counter

  let counter = ScoreNode()
  private let counterBar = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 4))
  private let counterBack = SKSpriteNode(color: UIColor(white: 1, alpha: 0.18), size: CGSize(width: 10, height: 4))
  private let counterGlow = SKSpriteNode()
  private var counterShown = 1.0
  private var counterPunch = 0.0
  private var counterFade = 0.0
  private var counterBreak = 0.0

  // MARK: Hinge chromatic burst

  private struct Chroma { var nodes: [SKSpriteNode]; var age = 1.0; var vertical = false; var at: CGFloat = 0; var length: CGFloat = 0; var strength: CGFloat = 1 }
  private var chromas: [Chroma] = []
  private var nextChroma = 0

  // MARK: Confetti and the last bubble

  private struct Piece { var node: SKSpriteNode; var v = CGVector.zero; var spin: CGFloat = 0; var life = 0.0; var wobble = 0.0 }
  private var pieces: [Piece] = []
  private var confettiLive = false
  let spotlight = SKSpriteNode()
  private let scoreGlow = SKSpriteNode()
  private var scoreGlowA = 0.0

  /// Scheduled follow-ups (a slam's impact after its fall). Rare, so a closure each is fine.
  private var later: [(at: Double, run: () -> Void)] = []
  func after(_ seconds: Double, _ run: @escaping () -> Void) { later.append((clock + seconds, run)) }

  private let dot: SKTexture
  /// The play area (safe area) size. The scene sets it at the top of each frame, before any effect fires.
  var area = CGSize(width: 10, height: 10)

  init(scene: SKScene, dot: SKTexture, scale: CGFloat) {
    self.dot = dot
    overlay.zPosition = 30
    scene.addChild(overlay)

    let frame = SKShader(source: """
    void main() {
      vec2 uv = v_tex_coord;
      vec2 c = (uv - 0.5) * vec2(u_aspect, 1.0);
      float r = length(c) / length(vec2(0.5 * u_aspect, 0.5));
      float vig = smoothstep(0.3, 1.0, r);
      float edge = min(min(uv.x, 1.0 - uv.x) * u_aspect, min(uv.y, 1.0 - uv.y));
      float rim = exp(-edge * 16.0);
      float a = vig * u_red * 0.78;
      vec3 col = vec3(1.0, 0.1, 0.2) * a;
      float w = rim * u_warn;
      col += u_wc * w * 0.9; a += w * 0.45;
      if (u_fever > 0.001) {
        float along = uv.x * 0.7 + uv.y * 1.3;
        vec3 rb = 0.55 + 0.45 * cos(6.2831 * (fract(along * 0.6 - u_t * 0.3) + vec3(0.0, 0.33, 0.67)));
        float f = (exp(-edge * 12.0) * 0.7 + vig * 0.08) * u_fever;
        col += rb * f; a += f * 0.35;
      }
      if (u_mask.w > 0.5) {
        float p = u_mask.x > 0.5 ? uv.x : 1.0 - uv.y;
        float m = smoothstep(-0.02, 0.05, (p - u_mask.y) * u_mask.z);
        col *= m; a *= m;
      }
      gl_FragColor = vec4(col, clamp(a, 0.0, 1.0));
    }
    """)
    frame.uniforms = [uRed, uWarn, uWarnColor, uFever, uTime, uAspect, uMask]
    frameNode.shader = frame
    frameNode.zPosition = 40
    frameNode.isHidden = true
    scene.addChild(frameNode)
    flashNode.blendMode = .add
    flashNode.zPosition = 41
    flashNode.isHidden = true
    scene.addChild(flashNode)

    for _ in 0..<4 {
      let s = SKSpriteNode()
      s.zPosition = 12
      s.colorBlendFactor = 1
      s.isHidden = true
      let g = SKSpriteNode(texture: dot)
      g.blendMode = .add
      g.colorBlendFactor = 1
      g.zPosition = -1
      s.addChild(g)
      overlay.addChild(s)
      calloutPool.append(s)
      calloutGlows.append(g)
    }
    for n in [plate, bannerEyebrow, bannerTitle, bannerSub] {
      n.isHidden = true
      n.zPosition = n === plate ? 14 : 15
      overlay.addChild(n)
    }
    bannerTitle.colorBlendFactor = 1
    bannerEyebrow.colorBlendFactor = 1
    bannerSub.colorBlendFactor = 1
    plate.colorBlendFactor = 1

    counterGlow.texture = dot
    counterGlow.blendMode = .add
    counterGlow.colorBlendFactor = 1
    for n in [counterGlow, counterBack, counterBar] { n.zPosition = 10; overlay.addChild(n); n.isHidden = true }
    counter.zPosition = 11
    counter.isHidden = true
    overlay.addChild(counter)
    counterBar.anchorPoint = CGPoint(x: 0, y: 0.5)

    for _ in 0..<2 {
      var nodes: [SKSpriteNode] = []
      for color in [UIColor(red: 1, green: 0.2, blue: 0.35, alpha: 1), UIColor(red: 0.4, green: 1, blue: 0.7, alpha: 1), UIColor(red: 0.3, green: 0.5, blue: 1, alpha: 1)] {
        let n = SKSpriteNode(texture: dot)
        n.color = color; n.colorBlendFactor = 1; n.blendMode = .add; n.zPosition = 2; n.isHidden = true
        overlay.addChild(n)
        nodes.append(n)
      }
      chromas.append(Chroma(nodes: nodes))
    }
    for _ in 0..<64 {
      let n = SKSpriteNode(color: .white, size: CGSize(width: 9, height: 13))
      n.zPosition = 13; n.isHidden = true
      overlay.addChild(n)
      pieces.append(Piece(node: n))
    }
    spotlight.isHidden = true
    spotlight.blendMode = .add
    spotlight.colorBlendFactor = 1
    spotlight.color = UIColor(red: 1, green: 0.88, blue: 0.4, alpha: 1)
    spotlight.zPosition = 4
    scoreGlow.texture = dot
    scoreGlow.blendMode = .add
    scoreGlow.colorBlendFactor = 1
    scoreGlow.color = UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1)
    scoreGlow.isHidden = true
    scoreGlow.zPosition = 9
    overlay.addChild(scoreGlow)

    // Every word, each boss's name and line, and the banner band, drawn off the main thread.
    let titles = BossStyle.allCases.map { ($0.title.uppercased(), $0.blurb) }
    Task.detached(priority: .userInitiated) {
      var drawn: [(String, CGImage)] = []
      for c in Callout.allCases { if let i = CalloutArt.word(c.rawValue, points: c.points, scale: scale) { drawn.append((c.rawValue, i)) } }
      for (title, blurb) in titles {
        if let i = CalloutArt.word(title, points: 58, scale: scale) { drawn.append(("title:" + title, i)) }
        if let i = CalloutArt.word(blurb, points: 19, scale: scale, weight: .heavy) { drawn.append(("blurb:" + blurb, i)) }
      }
      if let p = CalloutArt.plate(scale: scale) { drawn.append(("plate", p)) }
      let ready = drawn
      await MainActor.run { [weak self] in
        guard let self else { return }
        var textures: [SKTexture] = []
        for (key, image) in ready {
          let t = SKTexture(image: UIImage(cgImage: image, scale: scale, orientation: .up))
          self.words[key] = t
          textures.append(t)
        }
        self.plate.texture = self.words["plate"]
        SKTexture.preload(textures) {}
      }
    }
  }

  /// Confetti pieces and the spotlight ring use the game's own art, which the scene prewarms.
  func dress(confetti: [SKTexture], ring: SKTexture?) {
    for (i, p) in pieces.enumerated() where !confetti.isEmpty { p.node.texture = confetti[i % confetti.count] }
    spotlight.texture = ring
  }

  func reset() {
    stopLeft = 0; slowLeft = 0; simScale = 1
    trauma = 0; kick = .zero; punchAmount = 0
    red = 0; warn = 0; flashA = 0; warnHold = 0; fever = 0; danger = 0; beatsInDanger = 0
    counterShown = 1; counterFade = 0; counterBreak = 0
    for p in pieces.indices { pieces[p].life = 0; pieces[p].node.isHidden = true }
    confettiLive = false
    for i in chromas.indices { chromas[i].age = 1; chromas[i].nodes.forEach { $0.isHidden = true } }
    for n in calloutPool { n.removeAllActions(); n.isHidden = true }
    for n in [plate, bannerEyebrow, bannerTitle, bannerSub] { n.removeAllActions(); n.isHidden = true }
    spotlight.isHidden = true
    later.removeAll()
  }

  // MARK: Showing words

  private static let calloutAction = SKAction.sequence([
    .group([.scale(to: 0.9, duration: 0.11), .fadeIn(withDuration: 0.05)]),
    .scale(to: 1.06, duration: 0.07),
    .scale(to: 1, duration: 0.06),
    .wait(forDuration: 0.42),
    .group([.moveBy(x: 0, y: 26, duration: 0.28), .fadeOut(withDuration: 0.28)]),
    .hide(),
  ])
  private static let calloutSoft = SKAction.sequence([.fadeIn(withDuration: 0.1), .wait(forDuration: 0.6), .fadeOut(withDuration: 0.3), .hide()])
  private static let glowAction = SKAction.sequence([.fadeAlpha(to: 0.9, duration: 0.05), .fadeAlpha(to: 0.35, duration: 0.5)])

  /// Slams a word in at a point (clamped so it stays on screen), tinted.
  func callout(_ word: Callout, at p: CGPoint, color: UIColor, size: CGFloat = 1) {
    guard let t = words[word.rawValue] else { return }
    let n = calloutPool[nextCallout], g = calloutGlows[nextCallout]
    nextCallout = (nextCallout + 1) % calloutPool.count
    // Bigger on bigger screens, but never wider than the play area.
    let k = min(size * max(1, min(1.35, min(area.width, area.height) / 420)), (area.width - 24) / max(1, t.size().width))
    let s = CGSize(width: t.size().width * k, height: t.size().height * k)
    n.texture = t
    n.size = s
    n.color = color
    let mx = s.width / 2 + 8, my = s.height / 2 + 8
    n.position = CGPoint(x: min(max(mx, p.x), max(mx, area.width - mx)), y: min(max(my, p.y), max(my, area.height - my)))
    n.removeAllActions()
    n.isHidden = false
    g.color = color
    g.size = CGSize(width: s.width * 1.5, height: s.height * 2.2)
    g.alpha = 0.6
    if reduceMotion {
      n.setScale(1); n.zRotation = 0; n.alpha = 0
      n.run(Self.calloutSoft)
    } else {
      n.setScale(2.3); n.alpha = 0
      n.zRotation = CGFloat.random(in: -0.07...0.07)
      n.run(Self.calloutAction)
      g.run(Self.glowAction)
    }
  }

  private static let plateAction = SKAction.sequence([.scaleX(to: 1, y: 1, duration: 0.12), .wait(forDuration: 1.45), .group([.scaleX(to: 1.1, y: 0, duration: 0.22), .fadeOut(withDuration: 0.22)]), .hide()])
  private static let titleAction = SKAction.sequence([
    .wait(forDuration: 0.06), .group([.scale(to: 1, duration: 0.13), .fadeIn(withDuration: 0.06)]),
    .scale(to: 1.04, duration: 0.05), .scale(to: 1, duration: 0.06),
    .wait(forDuration: 1.2), .group([.moveBy(x: 60, y: 0, duration: 0.22), .fadeOut(withDuration: 0.22)]), .hide(),
  ])
  private static let lineAction = SKAction.sequence([.wait(forDuration: 0.22), .fadeIn(withDuration: 0.16), .wait(forDuration: 1.1), .fadeOut(withDuration: 0.2), .hide()])

  /// The boss's name across the middle of the screen.
  func banner(_ style: BossStyle) {
    guard let title = words["title:" + style.title.uppercased()] else { return }
    let mid = CGPoint(x: area.width / 2, y: area.height * 0.56)
    let k = min(max(0.8, min(1.3, min(area.width, area.height) / 420)), (area.width - 24) / max(1, title.size().width))
    plate.size = CGSize(width: max(area.width * 1.1, 520), height: 150 * k)
    plate.position = mid
    plate.color = UIColor(white: 1, alpha: 1)
    bannerTitle.texture = title
    bannerTitle.size = CGSize(width: title.size().width * k, height: title.size().height * k)
    bannerTitle.position = mid
    bannerTitle.color = UIColor(red: 1, green: 0.84, blue: 0.4, alpha: 1)
    if let eye = words[Callout.boss.rawValue] {
      bannerEyebrow.texture = eye
      bannerEyebrow.size = CGSize(width: eye.size().width * k, height: eye.size().height * k)
      bannerEyebrow.position = CGPoint(x: mid.x, y: mid.y + bannerTitle.size.height * 0.62)
      bannerEyebrow.color = UIColor(red: 1, green: 0.4, blue: 0.45, alpha: 1)
    }
    if let sub = words["blurb:" + style.blurb] {
      bannerSub.texture = sub
      bannerSub.size = CGSize(width: sub.size().width * k, height: sub.size().height * k)
      bannerSub.position = CGPoint(x: mid.x, y: mid.y - bannerTitle.size.height * 0.6)
      bannerSub.color = UIColor(white: 0.95, alpha: 1)
    }
    for n in [plate, bannerEyebrow, bannerTitle, bannerSub] { n.removeAllActions(); n.isHidden = false; n.alpha = 0 }
    plate.alpha = 1
    plate.xScale = 1; plate.yScale = 0.01
    plate.run(Self.plateAction)
    bannerTitle.setScale(reduceMotion ? 1 : 2.6)
    bannerTitle.run(Self.titleAction)
    bannerEyebrow.run(Self.lineAction)
    bannerSub.run(Self.lineAction)
  }

  /// The chromatic burst along the hinge: red, green and blue copies of the line tear apart and fade.
  func chroma(vertical: Bool, at: CGFloat, length: CGFloat, strength: CGFloat = 1) {
    guard !reduceMotion else { return }
    chromas[nextChroma].age = 0
    chromas[nextChroma].vertical = vertical
    chromas[nextChroma].at = at
    chromas[nextChroma].length = length
    chromas[nextChroma].strength = strength
    nextChroma = (nextChroma + 1) % chromas.count
  }

  /// Confetti fired from both bottom corners and dropped from the top.
  func confetti() {
    guard !reduceMotion else { return }
    confettiLive = true
    let w = area.width, h = area.height
    for i in pieces.indices {
      var p = pieces[i]
      let side: CGFloat = i % 2 == 0 ? -1 : 1
      if i < 40 {
        p.node.position = CGPoint(x: side < 0 ? 10 : w - 10, y: h * 0.12)
        let a = CGFloat.random(in: 0.95...1.35)
        let speed = CGFloat.random(in: 0.9...1.45) * h
        p.v = CGVector(dx: -side * cos(a) * speed * 0.55, dy: sin(a) * speed)
      } else {
        p.node.position = CGPoint(x: .random(in: 0...w), y: h + .random(in: 10...80))
        p.v = CGVector(dx: .random(in: -40...40), dy: -.random(in: 40...160))
      }
      p.spin = .random(in: -12...12)
      p.life = .random(in: 1.6...2.4)
      p.wobble = .random(in: 0...6)
      p.node.alpha = 1
      p.node.setScale(.random(in: 0.8...1.3))
      p.node.isHidden = false
      pieces[i] = p
    }
  }

  // MARK: Frame

  /// Advances feel time with the real frame time. Call before ticking the rules.
  func step(_ dt: Double) {
    clock += dt
    if stopLeft > 0 { stopLeft -= dt; simScale = 0 } else {
      if slowLeft > 0 { slowLeft = max(0, slowLeft - dt) }
      simScale = currentSlow
    }
    while let i = later.firstIndex(where: { $0.at <= clock }) { let f = later.remove(at: i).run; f() }
  }

  /// Draws everything the layer owns. `dt` is real time; `vdt` is slowed with the game.
  func update(dt: Double, area: CGSize, scene: CGSize, origin: CGPoint, combo: (value: Double, left: Double, window: Double)?, top: CGFloat) {
    self.area = area
    overlay.position = origin
    let vdt = dt * simScale
    // Camera
    trauma = max(0, trauma - dt * 1.7)
    let spring = exp(-dt * 16)
    kick = CGVector(dx: kick.dx * spring, dy: kick.dy * spring)
    punchAmount = max(0, punchAmount * exp(-dt * 7) - dt * 0.02)
    // Light
    flashA = max(0, flashA - dt * 5.5)
    flashNode.isHidden = flashA <= 0.003
    if !flashNode.isHidden {
      flashNode.size = scene
      flashNode.position = CGPoint(x: scene.width / 2, y: scene.height / 2)
      flashNode.alpha = CGFloat(min(0.8, flashA))
    }
    red = max(0, red - dt * 1.6)
    warn = max(0, warn - dt * 1.4)
    // The heartbeat: lub-dub, faster when one more crossing would cost the last shield.
    var beat = 0.0
    if danger > 0 {
      let period = danger >= 1 ? 0.6 : 0.86
      let before = beatClock
      beatClock += dt
      if beatClock >= period || before == 0 {
        if beatClock >= period { beatClock -= period }
        if beatsInDanger < 3 || danger >= 1 { onHeartbeat(danger) }
        beatsInDanger += 1
      }
      let t = beatClock
      let e = exp(-pow(t / 0.07, 2)) + 0.6 * exp(-pow((t - 0.19) / 0.07, 2))
      beat = (reduceMotion ? 0.55 : 0.35 + 0.65 * e) * (danger >= 1 ? 0.5 : 0.3)
    } else { beatClock = 0; beatsInDanger = 0 }
    let redNow = min(1, red + beat)
    let warnNow = min(1, warn + warnHold * (reduceMotion ? 0.6 : 0.55 + 0.45 * sin(clock * 14)))
    frameNode.isHidden = redNow < 0.005 && warnNow < 0.005 && fever < 0.005
    if !frameNode.isHidden {
      frameNode.size = scene
      frameNode.position = CGPoint(x: scene.width / 2, y: scene.height / 2)
      uAspect.floatValue = Float(scene.width / max(1, scene.height))
      uRed.floatValue = Float(redNow)
      uWarn.floatValue = Float(warnNow)
      var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
      warnColor.getRed(&r, green: &g, blue: &b, alpha: nil)
      uWarnColor.vectorFloat3Value = .init(Float(r), Float(g), Float(b))
      uFever.floatValue = Float(fever)
      uTime.floatValue = reduceMotion ? 0 : Float(clock.truncatingRemainder(dividingBy: 100))
      uMask.vectorFloat4Value = redNow > 0.005 ? redMask : vector_float4(0, 0.5, 1, 0)
    }
    drawCounter(dt: dt, combo: combo, top: top)
    drawChroma(dt: vdt)
    drawConfetti(dt: vdt)
    scoreGlowA = max(0, scoreGlowA - dt * 4)
    scoreGlow.isHidden = scoreGlowA <= 0.01
    scoreGlow.alpha = CGFloat(scoreGlowA)
  }

  /// A flare where flying points land in the score.
  func scoreLanded(at p: CGPoint) {
    scoreGlow.position = p
    scoreGlow.size = CGSize(width: 110, height: 26)
    scoreGlowA = min(0.9, scoreGlowA + 0.35)
  }

  private func drawCounter(dt: Double, combo: (value: Double, left: Double, window: Double)?, top: CGFloat) {
    let value = combo?.value ?? 1
    if value != counterShown {
      if value > counterShown {
        let tier = ComboTier.tier(value)
        counter.showText("x" + Self.comboText(value), height: 22 + CGFloat(min(tier, 6)) * 2.2, color: ComboTier.color(tier))
        counterPunch = 1
        counterBreak = 0
      } else if counterShown >= 2 {
        counterBreak = 1
      }
      counterShown = value
    }
    counterPunch = max(0, counterPunch - dt * 6)
    let showing = value > 1 && combo != nil
    counterFade += ((showing ? 1 : 0) - counterFade) * min(1, dt * (showing ? 14 : 5))
    counterBreak = max(0, counterBreak - dt * 1.6)
    let visible = counterFade > 0.02 || counterBreak > 0.02
    for n in [counter, counterBar, counterBack, counterGlow] as [SKNode] { n.isHidden = !visible }
    guard visible else { return }
    let at = CGPoint(x: area.width / 2, y: area.height - top - 30)
    let tier = ComboTier.tier(value)
    let color = counterBreak > 0 && !showing ? UIColor(red: 1, green: 0.35, blue: 0.4, alpha: 1) : ComboTier.color(tier)
    counter.position = CGPoint(x: at.x, y: at.y - CGFloat(counterBreak > 0 && !showing ? (1 - counterBreak) * 14 : 0))
    counter.setScale(reduceMotion ? 1 : 1 + CGFloat(counterPunch) * 0.4)
    counter.alpha = CGFloat(showing ? counterFade : counterBreak) * 0.95
    let width: CGFloat = 70
    let left = combo.map { $0.window > 0 ? max(0, min(1, $0.left / $0.window)) : 0 } ?? 0
    counterBack.size = CGSize(width: width, height: 4)
    counterBack.position = CGPoint(x: at.x, y: at.y - 20)
    counterBar.size = CGSize(width: max(0.5, width * CGFloat(left)), height: 4)
    counterBar.position = CGPoint(x: at.x - width / 2, y: at.y - 20)
    counterBar.color = color
    counterBar.colorBlendFactor = 1
    counterBack.alpha = counter.alpha * 0.8
    counterBar.alpha = counter.alpha
    // The glow grows with the tier and breathes faster as the combo window runs out.
    let breathe = reduceMotion ? 1 : 0.8 + 0.2 * sin(clock * (6 + (1 - left) * 14))
    counterGlow.color = color
    counterGlow.size = CGSize(width: 120 + CGFloat(tier) * 22, height: 64 + CGFloat(tier) * 8)
    counterGlow.position = at
    counterGlow.alpha = counter.alpha * CGFloat(0.12 + Double(tier) * 0.07) * CGFloat(breathe) + CGFloat(counterPunch) * 0.3
  }

  static func comboText(_ v: Double) -> String { v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v) }

  private func drawChroma(dt: Double) {
    for i in chromas.indices where chromas[i].age < 1 {
      chromas[i].age = min(1, chromas[i].age + dt / 0.32)
      let c = chromas[i], a = CGFloat(c.age)
      let fade = (1 - a) * (1 - a) * c.strength
      let spread = (1 - pow(1 - a, 3)) * 46 * c.strength
      for (k, n) in c.nodes.enumerated() {
        n.isHidden = c.age >= 1
        let off = k == 0 ? spread : k == 2 ? -spread : 0
        let thick = k == 1 ? 18 + spread * 1.4 : 16 + spread * 0.4
        if c.vertical {
          n.size = CGSize(width: thick, height: c.length)
          n.position = CGPoint(x: c.at + off, y: area.height / 2)
        } else {
          n.size = CGSize(width: c.length, height: thick)
          n.position = CGPoint(x: area.width / 2, y: c.at + off)
        }
        n.alpha = fade * (k == 1 ? 0.7 : 0.9)
      }
    }
  }

  private func drawConfetti(dt: Double) {
    guard confettiLive else { return }
    var any = false
    let drag = CGFloat(exp(-dt * 1.4))
    for i in pieces.indices where pieces[i].life > 0 {
      any = true
      var p = pieces[i]
      p.life -= dt
      p.v.dy -= 620 * CGFloat(dt)
      p.v = CGVector(dx: p.v.dx * drag, dy: max(-260, p.v.dy * drag))
      p.wobble += dt * 7
      p.node.position.x += (p.v.dx + CGFloat(sin(p.wobble)) * 40) * CGFloat(dt)
      p.node.position.y += p.v.dy * CGFloat(dt)
      p.node.zRotation += p.spin * CGFloat(dt)
      p.node.xScale = abs(CGFloat(cos(p.wobble * 1.3))) * 1.1 + 0.15
      p.node.alpha = CGFloat(min(1, p.life / 0.5))
      if p.life <= 0 { p.node.isHidden = true }
      pieces[i] = p
    }
    confettiLive = any
  }
}
