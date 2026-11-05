import SpriteKit
import UIKit
import HingePopArt
import HingePopCore

/// Draws the game and takes touches. All rules live in `Game`. Touch points in view coordinates match
/// game coordinates (y down), and nodes are placed at `height - y`.
@MainActor
final class GameScene: SKScene {
  weak var session: Session?
  var hingeGlow: () -> Double = { 0 }
  var reduceMotion = false

  private let world = SKNode()
  private let hingeCore = SKShapeNode()
  /// The hinge's light is an aurora ribbon: a curtain shader on one sprite, blended additively.
  private let ribbon = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private let ribbonTime = SKUniform(name: "u_t", float: 0)
  private let ribbonGlow = SKUniform(name: "u_glow", float: 1)
  private let ribbonColor = SKUniform(name: "u_tint", vectorFloat3: .init(0.3, 0.78, 1))
  private var gateNodes: [SKShapeNode] = []
  private var bubbleNodes: [Int: BubbleNode] = [:]
  private var pickupNodes: [Int: SKSpriteNode] = [:]
  private var textures: [String: SKTexture] = [:]
  private var fxTextures: [String: SKTexture] = [:]
  private var sparkTexture: SKTexture?
  private var lastTime: TimeInterval = 0
  private var pulse = 0.0
  private var shake = 0.0
  private var clock = 0.0
  private var lastBump = 0.0
  private var generation = -1
  /// One finger on the screen: what it landed on, where it last was, and what this stroke has already hit.
  private struct Stroke { var bubble: Bubble?; var start: CGPoint; var last: CGPoint; var slicing = false; var skip = Set<Int>() }
  private var active: [ObjectIdentifier: Stroke] = [:]
  private let displayScale: CGFloat

  init(scale: CGFloat) {
    displayScale = scale
    super.init(size: CGSize(width: 10, height: 10))
    backgroundColor = .clear
    scaleMode = .resizeFill
    anchorPoint = .zero
    addChild(world)
    let shader = SKShader(source: """
    void main() {
      vec2 uv = v_tex_coord;
      float c = abs(uv.x - 0.5) * 2.0;
      float n = sin(uv.y * 9.0 + u_t * 1.1) * 0.5 + sin(uv.y * 23.0 - u_t * 1.7) * 0.3 + sin(uv.y * 51.0 + u_t * 2.3) * 0.2;
      float width = 2.1 + n * 0.8;
      float band = exp(-(c * width) * (c * width) * 3.2);
      float rays = 0.55 + 0.45 * sin(uv.y * 90.0 + u_t * 0.9 + n * 3.0);
      vec3 green = vec3(0.3, 1.0, 0.72);
      vec3 col = mix(u_tint, green, rays * 0.35 * (1.0 - c));
      float a = band * (0.45 + 0.55 * rays) * u_glow;
      gl_FragColor = vec4(col * a, a);
    }
    """)
    shader.uniforms = [ribbonTime, ribbonGlow, ribbonColor]
    ribbon.shader = shader
    ribbon.blendMode = .add
    ribbon.zPosition = 1
    hingeCore.lineCap = .round; hingeCore.zPosition = 2
    world.addChild(ribbon)
    world.addChild(hingeCore)
  }
  required init?(coder: NSCoder) { fatalError() }

  override func didMove(to view: SKView) {
    view.isMultipleTouchEnabled = true
    view.allowsTransparency = true
    view.isOpaque = false
    view.preferredFramesPerSecond = view.window?.screen.maximumFramesPerSecond ?? 60
  }

  private func y(_ gameY: Double) -> CGFloat { size.height - CGFloat(gameY) }

  // MARK: Frame

  override func update(_ currentTime: TimeInterval) {
    let dt = lastTime == 0 ? 1.0 / 60 : currentTime - lastTime
    lastTime = currentTime
    guard let session else { return }
    session.tick(dt)
    guard let game = session.game else { return }
    clock += dt
    #if DEBUG
    demoSwipe(game)
    #endif
    if session.generation != generation {
      generation = session.generation
      resetFor(game)
    }
    for e in session.pendingEvents { effect(e) }
    session.pendingEvents.removeAll(keepingCapacity: true)
    pulse = max(0, pulse - dt * 3)
    shake = max(0, shake - dt * 3)
    world.position = shake > 0 && !reduceMotion
      ? CGPoint(x: .random(in: -1...1) * 7 * shake, y: .random(in: -1...1) * 7 * shake) : .zero
    drawHinge(game)
    drawGates(game)
    drawBubbles(game)
    drawPickups(game)
  }

  private func resetFor(_ game: Game) {
    for n in bubbleNodes.values { n.removeFromParent() }
    bubbleNodes.removeAll()
    for n in pickupNodes.values { n.removeFromParent() }
    pickupNodes.removeAll()
    for n in gateNodes { n.removeFromParent() }
    gateNodes.removeAll()
    active.removeAll()
    textures.removeAll()
  }

  private func meterColor(_ game: Game) -> UIColor {
    let m = game.players.map(\.meter).max() ?? 0
    if m >= game.meterMax - 1 { return UIColor(red: 1, green: 0.3, blue: 0.38, alpha: 1) }
    if m >= game.meterMax - 2 { return UIColor(red: 0.72, green: 0.48, blue: 1, alpha: 1) }
    return UIColor(red: 0.3, green: 0.78, blue: 1, alpha: 1)
  }

  private func drawHinge(_ game: Game) {
    let start = game.vertical ? CGFloat(game.top) : 0
    let end = game.vertical ? size.height : size.width
    let at = game.vertical ? CGFloat(game.hinge) : y(game.hinge)
    let meter = Double(game.players.map(\.meter).max() ?? 0)
    let amp = reduceMotion ? 0 : 1.5 + pulse * 6 + meter * 0.7
    let path = CGMutablePath()
    let steps = 56
    let t = clock * 1000
    for i in 0...steps {
      let along = (game.vertical ? size.height - start : start) + (game.vertical ? -1 : 1) * (end - start) * CGFloat(i) / CGFloat(steps)
      let off = i == 0 || i == steps ? 0 : CGFloat(sin(Double(i) * 0.42 + t * 0.005) * amp * sin(Double(i) * 0.17 - t * 0.003))
      let p = game.vertical ? CGPoint(x: at + off, y: along) : CGPoint(x: along, y: at + off)
      if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    let color = meterColor(game), glow = hingeGlow()
    hingeCore.path = path
    hingeCore.strokeColor = UIColor.white.withAlphaComponent(0.92)
    hingeCore.lineWidth = 2 + CGFloat(pulse) * 1.5
    // The ribbon widens and brightens on a hit, with the meter, and as a real hinge folds.
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: nil)
    ribbonColor.vectorFloat3Value = .init(Float(r), Float(g), Float(b))
    ribbonTime.floatValue = reduceMotion ? 0 : Float(clock.truncatingRemainder(dividingBy: 1000))
    ribbonGlow.floatValue = Float(0.8 + pulse * 0.7 + meter * 0.1 + glow * 0.4)
    let width = (70 + CGFloat(pulse) * 60 + CGFloat(glow) * 34) * CGFloat(max(1, min(1.6, game.scale)))
    let length = end - start
    ribbon.size = CGSize(width: width, height: length)
    if game.vertical {
      ribbon.zRotation = 0
      ribbon.position = CGPoint(x: at, y: length / 2)
    } else {
      ribbon.zRotation = .pi / 2
      ribbon.position = CGPoint(x: length / 2, y: at)
    }
  }

  private func drawGates(_ game: Game) {
    while gateNodes.count < game.gates.count {
      let n = SKShapeNode()
      n.zPosition = 3; n.lineCap = .round
      n.strokeColor = UIColor(red: 0.3, green: 1, blue: 0.62, alpha: 1)
      n.lineWidth = 8
      world.addChild(n)
      gateNodes.append(n)
    }
    for (i, g) in game.gates.enumerated() {
      let path = CGMutablePath()
      let half = CGFloat(g.width) / 2
      if game.vertical {
        let x = CGFloat(game.hinge), c = y(g.at)
        path.move(to: CGPoint(x: x, y: c - half)); path.addLine(to: CGPoint(x: x, y: c + half))
      } else {
        let c = CGFloat(g.at), yy = y(game.hinge)
        path.move(to: CGPoint(x: c - half, y: yy)); path.addLine(to: CGPoint(x: c + half, y: yy))
      }
      gateNodes[i].path = path
    }
  }

  private func artKind(_ b: Bubble) -> BubbleKind {
    switch b.kind {
    case .armored: return b.armor > 0 ? .armored : .armoredCracked
    case .boss: return b.bossPhase > 0 ? .bossHurt : .boss
    default: return b.kind.artKind
    }
  }

  private func texture(_ kind: BubbleKind, size px: CGFloat) -> SKTexture {
    let key = "\(kind.rawValue)-\(Int(px))"
    if let t = textures[key] { return t }
    let t = SKTexture(cgImage: Art.bubble(kind, size: px, scale: displayScale))
    textures[key] = t
    return t
  }

  private func drawBubbles(_ game: Game) {
    var seen = Set<Int>()
    for b in game.bubbles {
      seen.insert(b.id)
      let kind = artKind(b)
      let draw = CGFloat(b.r * 2) / Art.bodyFraction(kind)
      let node: BubbleNode
      if let n = bubbleNodes[b.id] {
        node = n
      } else {
        node = BubbleNode()
        node.zPosition = 5
        world.addChild(node)
        bubbleNodes[b.id] = node
        if b.grace > 0 && !reduceMotion {
          node.setScale(0.5)
          node.run(.scale(to: 1, duration: 0.14))
        }
      }
      if node.kind != kind || node.drawSize != draw {
        node.kind = kind; node.drawSize = draw
        node.sprite.texture = texture(kind, size: draw)
        node.sprite.size = CGSize(width: draw, height: draw)
      }
      node.position = CGPoint(x: b.x, y: y(b.y))
      node.sprite.alpha = b.grace > 0 ? 0.78 : 1
      // Squash along the direction of the hit, keeping the face upright.
      let q = reduceMotion ? 0 : CGFloat(b.sq) * 0.16
      node.squash.zRotation = -CGFloat(b.sqA)
      node.squash.xScale = 1 - q
      node.squash.yScale = 1 + q
      node.sprite.zRotation = CGFloat(b.sqA)
    }
    for (id, n) in bubbleNodes where !seen.contains(id) {
      n.removeFromParent()
      bubbleNodes[id] = nil
    }
  }

  private func drawPickups(_ game: Game) {
    var seen = Set<Int>()
    for p in game.pickups {
      seen.insert(p.id)
      let node: SKSpriteNode
      if let n = pickupNodes[p.id] {
        node = n
      } else {
        let px: CGFloat = 54 * CGFloat(max(1, min(1.6, game.scale)))
        node = SKSpriteNode(texture: SKTexture(cgImage: Art.power(p.kind.artKind, size: px, scale: displayScale)), size: CGSize(width: px, height: px))
        node.zPosition = 8
        world.addChild(node)
        pickupNodes[p.id] = node
        if !reduceMotion {
          node.setScale(0.2)
          node.run(.sequence([.scale(to: 1.15, duration: 0.14), .scale(to: 1, duration: 0.08)]))
        }
      }
      node.position = CGPoint(x: p.x, y: y(p.y) + CGFloat(reduceMotion ? 0 : sin(clock * 4 + Double(p.id)) * 4))
      // It blinks in its last two seconds, in shape as well as colour terms: the fade is the warning.
      node.alpha = p.life < 2 ? (sin(clock * 12) > 0 ? 1 : 0.35) : 1
    }
    for (id, n) in pickupNodes where !seen.contains(id) {
      n.removeFromParent()
      pickupNodes[id] = nil
    }
  }

  // MARK: Effects

  private func fxTexture(_ kind: FXKind, size px: CGFloat) -> SKTexture {
    let key = "\(kind)-\(Int(px))"
    if let t = fxTextures[key] { return t }
    let t = SKTexture(cgImage: Art.fx(kind, size: px, scale: displayScale))
    fxTextures[key] = t
    return t
  }

  private func burst(at p: CGPoint, r: CGFloat, particles: Int) {
    if reduceMotion { return }
    let pop = SKSpriteNode(texture: fxTexture(.popBurst, size: 96), size: CGSize(width: r * 2.2, height: r * 2.2))
    pop.position = p; pop.zPosition = 6
    pop.run(.sequence([.group([.scale(to: 1.4, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
    world.addChild(pop)
    for _ in 0..<particles {
      let s = SKSpriteNode(texture: fxTexture(.particleStar, size: 28), size: CGSize(width: 14, height: 14))
      s.position = p; s.zPosition = 6
      let a = Double.random(in: 0...(2 * .pi)), d = CGFloat.random(in: r...(r * 2.6))
      s.run(.sequence([.group([.moveBy(x: CGFloat(cos(a)) * d, y: CGFloat(sin(a)) * d, duration: 0.42), .fadeOut(withDuration: 0.42), .rotate(byAngle: 2, duration: 0.42)]), .removeFromParent()]))
      world.addChild(s)
    }
    auroraSparks(at: p, r: r, count: particles * 3)
  }

  /// A swipe leaves a ribbon of aurora light behind the finger.
  private func trail(from a: CGPoint, to b: CGPoint) {
    guard !reduceMotion else { return }
    let path = CGMutablePath()
    path.move(to: CGPoint(x: a.x, y: size.height - a.y))
    path.addLine(to: CGPoint(x: b.x, y: size.height - b.y))
    let line = SKShapeNode(path: path)
    let palette = (session?.arena ?? .classic).sparkColors
    line.strokeColor = palette[.random(in: 0..<palette.count)]
    line.lineWidth = 7
    line.lineCap = .round
    line.blendMode = .add
    line.zPosition = 7
    line.run(.sequence([.group([.fadeOut(withDuration: 0.28)]), .removeFromParent()]))
    world.addChild(line)
  }

  #if DEBUG
  /// Store captures: a held stroke across the arena that really slices, so the swipe shot shows a swipe.
  private var demoStroke: SKNode?
  private var demoSliceClock = 0.0
  private func demoSwipe(_ game: Game) {
    guard Debug.has("-demoSwipe"), game.status == .playing else { return }
    let a = CGPoint(x: size.width * 0.12, y: size.height * 0.28)
    let b = CGPoint(x: size.width * 0.88, y: size.height * 0.62)
    if demoStroke == nil {
      let path = CGMutablePath()
      path.move(to: CGPoint(x: a.x, y: size.height - a.y))
      path.addQuadCurve(to: CGPoint(x: b.x, y: size.height - b.y),
                        control: CGPoint(x: size.width * 0.42, y: size.height - size.height * 0.36))
      let line = SKShapeNode(path: path)
      line.strokeColor = (session?.arena ?? .classic).sparkColors[0]
      line.lineWidth = 8
      line.lineCap = .round
      line.glowWidth = 10
      line.blendMode = .add
      line.zPosition = 7
      world.addChild(line)
      demoStroke = line
    }
    if clock > demoSliceClock {
      demoSliceClock = clock + 2.5
      var skip = Set<Int>()
      _ = game.slice(fromX: a.x, fromY: a.y, toX: b.x, toY: b.y, skip: &skip)
    }
  }
  #endif

  /// Soft points of aurora light that fly out, curl and fade, with one shared texture and additive blending.
  private func auroraSparks(at p: CGPoint, r: CGFloat, count: Int) {
    if reduceMotion { return }
    if sparkTexture == nil { sparkTexture = SKTexture(cgImage: Self.softDot()) }
    let palette = (session?.arena ?? .classic).sparkColors
    for _ in 0..<count {
      let dot = SKSpriteNode(texture: sparkTexture, size: CGSize(width: 16, height: 16))
      dot.color = palette[.random(in: 0..<palette.count)]
      dot.colorBlendFactor = 1
      dot.blendMode = .add
      dot.position = p
      dot.zPosition = 6
      let a = Double.random(in: 0...(2 * .pi)), d = CGFloat.random(in: (r * 0.6)...(r * 3)), time = Double.random(in: 0.4...0.85)
      let out = CGPoint(x: CGFloat(cos(a)) * d, y: CGFloat(sin(a)) * d)
      let curl = CGPoint(x: -out.y * 0.35, y: out.x * 0.35)
      let path = CGMutablePath()
      path.move(to: .zero)
      path.addQuadCurve(to: out, control: CGPoint(x: out.x * 0.5 + curl.x, y: out.y * 0.5 + curl.y))
      let fly = SKAction.follow(path, asOffset: true, orientToPath: false, duration: time)
      fly.timingMode = .easeOut
      dot.run(.sequence([.group([fly, .fadeOut(withDuration: time), .scale(to: 0.3, duration: time)]), .removeFromParent()]))
      world.addChild(dot)
    }
  }

  private static func softDot() -> CGImage {
    let n = 32
    let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.35).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 0.3, 1])!
    let c = CGPoint(x: CGFloat(n) / 2, y: CGFloat(n) / 2)
    ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(n) / 2, options: [])
    return ctx.makeImage()!
  }

  private func shockwave(at p: CGPoint, r: CGFloat) {
    if reduceMotion { return }
    let n = SKSpriteNode(texture: fxTexture(.shockwave, size: 128), size: CGSize(width: r * 2, height: r * 2))
    n.position = p; n.zPosition = 4; n.blendMode = .add
    n.run(.sequence([.group([.scale(to: 2.6, duration: 0.34), .fadeOut(withDuration: 0.34)]), .removeFromParent()]))
    world.addChild(n)
  }

  private func scoreText(_ value: Int, at p: CGPoint, color: UIColor = .white) {
    let unit = max(15, min(size.width, size.height) / 40)
    let grow = 1 + min(1.2, CGFloat(value) / 2500)
    let label = SKLabelNode(text: "+\(value.formatted())")
    label.fontName = "AvenirNextRounded-Heavy"
    if UIFont(name: label.fontName ?? "", size: 12) == nil { label.fontName = "AvenirNext-Heavy" }
    label.fontSize = unit * grow
    label.fontColor = color
    label.position = p; label.zPosition = 9
    label.verticalAlignmentMode = .center
    label.run(.sequence([.group([.moveBy(x: 0, y: 34, duration: reduceMotion ? 0 : 0.8), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
    world.addChild(label)
  }

  private func confetti() {
    if reduceMotion { return }
    for i in 0..<56 {
      let c = SKSpriteNode(texture: fxTexture(.confetti(i % 6), size: 24), size: CGSize(width: 14, height: 14))
      c.position = CGPoint(x: .random(in: 0...size.width), y: size.height + 20)
      c.zPosition = 10
      let time = Double.random(in: 1.1...2.2)
      c.run(.sequence([.wait(forDuration: .random(in: 0...0.5)), .group([.moveBy(x: .random(in: -70...70), y: -size.height - 50, duration: time), .rotate(byAngle: .random(in: -9...9), duration: time)]), .removeFromParent()]))
      world.addChild(c)
    }
  }

  private func effect(_ e: GameEvent) {
    let sound = Sound.shared, haptic = Haptics.shared
    switch e {
    case let .split(x, gy, r, size, points, kind):
      burst(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r), particles: 4)
      scoreText(points, at: CGPoint(x: x, y: y(gy)), color: kind == .golden ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1) : .white)
      sound.blip(420 + Double(size) * 150, 0.09)
      haptic.tap()
    case let .pop(x, gy, r, _, points, kind):
      burst(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r) * 1.3, particles: 8)
      scoreText(points, at: CGPoint(x: x, y: y(gy)), color: kind == .golden ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1) : .white)
      sound.blip(880, 0.1)
      haptic.tap()
    case let .zap(x, gy, r, points):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r) * 1.6)
      scoreText(points, at: CGPoint(x: x, y: y(gy)), color: UIColor(red: 0.5, green: 0.9, blue: 1, alpha: 1))
      sound.blip(1200, 0.1, .sine, gain: 0.16)
    case let .chainPop(x, gy, r, points, count):
      burst(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r) * 1.3, particles: 4)
      scoreText(points, at: CGPoint(x: x, y: y(gy)), color: UIColor(red: 0.55, green: 1, blue: 0.75, alpha: 1))
      sound.blip(880 + Double(min(count, 8)) * 110, 0.08)
    case let .crossed(x, gy, r, _, _):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r))
      pulse = 1
      sound.blip(150, 0.17, .saw, gain: 0.16)
      haptic.hit()
    case let .gatePass(x, gy, r):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r) * 0.7)
      sound.blip(760, 0.09, .sine, gain: 0.14)
    case let .armorCrack(x, gy, r, points):
      burst(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r) * 0.6, particles: 6)
      scoreText(points, at: CGPoint(x: x, y: y(gy)))
      sound.blip(280, 0.12, .square, gain: 0.12)
      haptic.hit()
    case let .bossHit(x, gy, r, points, _):
      burst(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r) * 0.5, particles: 5)
      scoreText(points, at: CGPoint(x: x, y: y(gy) + CGFloat(r) * 0.5))
      sound.blip(240, 0.11, .square, gain: 0.14)
      haptic.hit()
    case let .bossPhase(x, gy, r, _):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r) * 1.4)
      shake = 1
      sound.blip(110, 0.35, .saw, gain: 0.2)
      haptic.bad()
    case let .bossSlam(x, gy, r, _):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r))
      pulse = 1.4; shake = 0.6
      sound.blip(90, 0.25, .square, gain: 0.18)
      haptic.hit()
    case let .bump(strength, size):
      if clock - lastBump > 0.07 {
        lastBump = clock
        sound.blip(150 + Double(size) * 90, 0.05, .sine, gain: Float(min(0.12, strength / 2500)))
      }
    case .shieldLost:
      shake = 1; pulse = 1.6
      sound.blip(80, 0.4, .square, gain: 0.2)
      haptic.bad()
    case .recharge, .cooled:
      sound.blip(520, 0.12); sound.blip(990, 0.26, .triangle, gain: 0.16)
      haptic.good()
    case let .collected(kind, x, gy, _):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: kind == .chainBurst ? 120 : 44)
      if kind == .chainBurst { shake = 0.7 }
      sound.blip(660, 0.1); sound.blip(1100, 0.18, .sine, gain: 0.15)
      haptic.good()
    case .dropped: sound.blip(1320, 0.08, .sine, gain: 0.12)
    case .wave: sound.blip(330, 0.2, .triangle, gain: 0.14)
    case .finished:
      if session?.game.status == .won || (session?.versus == true) { confetti(); sound.blip(660, 0.3) }
      else { sound.blip(70, 0.6, .saw) }
    }
  }

  // MARK: Touch

  private var inputOn: Bool {
    guard let session else { return false }
    if session.overlay == .tour { return session.tourInput }
    return session.overlay == .none && session.tip == nil
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard inputOn, let session, let game = session.game, let view else { return }
    for touch in touches {
      let p = touch.location(in: view)
      if let pickup = game.hitPickup(x: p.x, y: p.y), session.overlay != .tour {
        game.collect(pickup)
        continue
      }
      let b = game.hit(x: p.x, y: p.y)
      if !game.flick && session.overlay != .tour {
        if let b { game.tap(b) }
      } else {
        active[ObjectIdentifier(touch)] = Stroke(bubble: b, start: p, last: p)
      }
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let session, let game = session.game, let view else { return }
    for touch in touches {
      let id = ObjectIdentifier(touch)
      guard var stroke = active[id] else { continue }
      let p = touch.location(in: view)
      if !stroke.slicing, hypot(p.x - stroke.start.x, p.y - stroke.start.y) < 18 { continue }
      if !stroke.slicing {
        // The first stroke of a swipe also takes in whatever the finger started on.
        stroke.slicing = true
        stroke.last = stroke.start
      }
      game.slice(fromX: stroke.last.x, fromY: stroke.last.y, toX: p.x, toY: p.y, skip: &stroke.skip)
      trail(from: stroke.last, to: p)
      stroke.last = p
      active[id] = stroke
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let session, let game = session.game else { return }
    for touch in touches {
      guard let stroke = active[ObjectIdentifier(touch)] else { continue }
      active[ObjectIdentifier(touch)] = nil
      if !stroke.slicing, let b = stroke.bubble { game.tap(b) }
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches { active[ObjectIdentifier(touch)] = nil }
  }
}

final class BubbleNode: SKNode {
  let squash = SKNode()
  let sprite = SKSpriteNode()
  var kind: BubbleKind?
  var drawSize: CGFloat = 0
  override init() {
    super.init()
    addChild(squash)
    squash.addChild(sprite)
  }
  required init?(coder: NSCoder) { fatalError() }
}
