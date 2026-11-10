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
  /// The arena art and the sky live in the scene, so the view can be opaque and pops can touch the aurora.
  private let arenaNode = SKSpriteNode(color: .clear, size: CGSize(width: 10, height: 10))
  private let skyNode = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private let skyTime = SKUniform(name: "u_t", float: 0)
  private let skyHeat = SKUniform(name: "u_heat", float: 0)
  private let skyEnergy = SKUniform(name: "u_energy", float: 0)
  private let skyAspect = SKUniform(name: "u_aspect", float: 0.5)
  private let skyHinge = SKUniform(name: "u_hinge", float: 0.5)
  private let skyTints = (1...3).map { SKUniform(name: "u_c\($0)", vectorFloat3: .init(0.3, 0.8, 1)) }
  private let skyRipples = (0..<4).map { SKUniform(name: "u_r\($0)", vectorFloat3: .init(0, 0, 1)) }
  private var ripples = [SIMD3<Float>](repeating: .init(0, 0, 1), count: 4)
  private var nextRipple = 0
  private var skyArena: Arena?
  private var arenaKey = ""
  private var energy = 0.0
  private var bloom = 0.0
  private var skyClock = 0.0

  /// The hinge is one aurora ribbon with an electric core, all in a shader, so nothing is rebuilt per frame.
  private let ribbon = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private let ribbonTime = SKUniform(name: "u_t", float: 0)
  private let ribbonGlow = SKUniform(name: "u_glow", float: 1)
  private let ribbonColor = SKUniform(name: "u_tint", vectorFloat3: .init(0.3, 0.78, 1))
  private let ribbonAmp = SKUniform(name: "u_amp", float: 0.02)
  private let ribbonCore = SKUniform(name: "u_core", float: 30)
  private var gateNodes: [SKSpriteNode] = []
  private var bubbleNodes: [Int: BubbleNode] = [:]
  private var sparePuppets: [BubbleNode] = []
  private var pickupNodes: [Int: SKSpriteNode] = [:]
  private var visitorNodes: [Int: SKSpriteNode] = [:]
  private var textures: [String: SKTexture] = [:]
  private var fxTextures: [String: SKTexture] = [:]
  private var spareSprites: [SKSpriteNode] = []
  private var emitters: [SKEmitterNode] = []
  private var nextEmitter = 0
  private var spareScores: [ScoreNode] = []
  private let glyphs = ScoreGlyphs()
  private let dashLine = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private var lastChain: CGPoint?
  private var lastChainClock = 0.0
  private var snapFlare = 0.0
  /// iPhone Duo: the rushing page glows gold, brighter as the device folds (the angle only ever lights things).
  private let rushNode = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private let rushTime = SKUniform(name: "u_t", float: 0)
  private let rushAlpha = SKUniform(name: "u_a", float: 0)
  private let rushAxis = SKUniform(name: "u_axis", float: 0)
  private let rushFlip = SKUniform(name: "u_flip", float: 0)
  private var rushGlow = 0.0
  private var rushFlash = 0.0
  private var rushShown = 0
  /// The last touch beside the crease, for spotting a clap: one finger on each page at once.
  private var creaseTouch: (side: Int, at: Double)?
  private var lastTime: TimeInterval = 0
  private var pulse = 0.0
  private var shake = 0.0
  private var clock = 0.0
  private var lastBump = 0.0
  private var generation = -1
  private var prewarmedFor = -1.0
  /// One finger on the screen: what it landed on, where it last was, and what this stroke has already hit.
  private struct Stroke { var bubble: Bubble?; var start: CGPoint; var last: CGPoint; var slicing = false; var skip = Set<Int>(); var onLine = false }
  private var active: [ObjectIdentifier: Stroke] = [:]
  private let displayScale: CGFloat

  init(scale: CGFloat) {
    displayScale = scale
    super.init(size: CGSize(width: 10, height: 10))
    backgroundColor = UIColor(red: 0.08, green: 0.04, blue: 0.18, alpha: 1)
    scaleMode = .resizeFill
    anchorPoint = .zero
    addChild(arenaNode)
    addChild(skyNode)
    addChild(world)
    arenaNode.zPosition = -20
    arenaNode.anchorPoint = .zero
    let sky = SKShader(source: """
    float wave(vec2 p, float t, float s, float f, float ph) { return sin(p.x * f + t * s + ph + 1.6 * sin(p.x * f * 0.37 - t * s * 0.61 + ph)); }
    float ring(vec3 r, vec2 p, float aspect) {
      if (r.z >= 1.0) { return 0.0; }
      float l = length(p - vec2(r.x * aspect, r.y));
      float d = (l - r.z * 0.62) * 11.0;
      return exp(-d * d) * (1.0 - r.z);
    }
    void main() {
      vec2 uv = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y);
      vec2 p = vec2(uv.x * u_aspect, uv.y);
      float rip = ring(u_r0, p, u_aspect) + ring(u_r1, p, u_aspect) + ring(u_r2, p, u_aspect) + ring(u_r3, p, u_aspect);
      p.y += rip * 0.045;
      float speed = 1.0 + u_energy * 1.6;
      float t = u_t * speed;
      vec3 col = vec3(0.0);
      float c0 = u_hinge * 0.42 + 0.03 * wave(p, t, 0.17, 2.2, 0.0);
      float d0 = p.y - c0;
      col += u_c1 * (d0 > 0.0 ? exp(-d0 * d0 * 26.0) : exp(-d0 * d0 * 150.0)) * (0.6 + 0.4 * sin(p.x * 34.0 + 1.8 * wave(p, t, 0.31, 3.4, 0.0) + t * 0.22));
      float c1 = u_hinge + 0.08 * wave(p, t, 0.2, 2.9, 2.1);
      float d1 = p.y - c1;
      col += u_c2 * (d1 > 0.0 ? exp(-d1 * d1 * 26.0) : exp(-d1 * d1 * 150.0)) * (0.6 + 0.4 * sin(p.x * 47.0 + 1.8 * wave(p, t, 0.31, 3.4, 1.0) + t * 0.22));
      float c2 = u_hinge + (1.0 - u_hinge) * 0.56 + 0.07 * wave(p, t, 0.23, 3.6, 4.2);
      float d2 = p.y - c2;
      col += u_c3 * (d2 > 0.0 ? exp(-d2 * d2 * 26.0) : exp(-d2 * d2 * 150.0)) * (0.6 + 0.4 * sin(p.x * 60.0 + 1.8 * wave(p, t, 0.31, 3.4, 2.0) + t * 0.22));
      col *= 0.46 + u_energy * 0.5;
      col += (u_c1 * 0.5 + u_c2 * 0.5) * rip * 0.55;
      float luma = dot(col, vec3(0.34));
      col = mix(col, vec3(1.0, 0.24, 0.32) * luma * 1.6, clamp(u_heat, 0.0, 1.0) * 0.8);
      gl_FragColor = vec4(col, 0.0);
    }
    """)
    sky.uniforms = [skyTime, skyHeat, skyEnergy, skyAspect, skyHinge] + skyTints + skyRipples
    skyNode.shader = sky
    skyNode.blendMode = .add
    skyNode.zPosition = -10
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
      float edge = smoothstep(0.0, 0.015, uv.y) * smoothstep(1.0, 0.985, uv.y);
      float off = sin(uv.y * 24.0 + u_t * 5.0) * sin(uv.y * 9.0 - u_t * 3.0) * u_amp * edge;
      float dc = (uv.x - 0.5 - off) * u_core;
      float core = exp(-dc * dc);
      col = col * a + vec3(1.0) * core * 0.95;
      gl_FragColor = vec4(col, min(1.0, a + core));
    }
    """)
    shader.uniforms = [ribbonTime, ribbonGlow, ribbonColor, ribbonAmp, ribbonCore]
    ribbon.shader = shader
    ribbon.blendMode = .add
    ribbon.zPosition = 1
    world.addChild(ribbon)
    let rush = SKShader(source: """
    void main() {
      vec2 uv = v_tex_coord;
      float a = u_axis < 0.5 ? uv.x : uv.y;
      float d = u_flip > 0.5 ? 1.0 - a : a;
      float along = u_axis < 0.5 ? uv.y : uv.x;
      float curtains = 0.55 + 0.45 * sin(along * 16.0 + u_t * 1.4 + 1.6 * sin(d * 5.0 - u_t * 0.8));
      vec3 col = mix(vec3(1.0, 0.72, 0.16), vec3(1.0, 0.3, 0.62), clamp(d * 1.4, 0.0, 1.0));
      float glow = exp(-d * 2.6) * 0.66 + 0.12;
      float rim = smoothstep(0.0, 0.04, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
      float al = clamp(glow * curtains * rim * u_a, 0.0, 0.74);
      gl_FragColor = vec4(col * al, al);
    }
    """)
    rush.uniforms = [rushTime, rushAlpha, rushAxis, rushFlip]
    rushNode.shader = rush
    // A tint, not added light, so the page reads gold even over a bright sky.
    rushNode.blendMode = .alpha
    rushNode.zPosition = -5
    rushNode.isHidden = true
    world.addChild(rushNode)
    dashLine.isHidden = true
    dashLine.blendMode = .add
    dashLine.zPosition = 3
    dashLine.color = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)
    dashLine.colorBlendFactor = 1
    world.addChild(dashLine)
    let dot = SKTexture(cgImage: Self.softDot())
    fxTextures["softDot"] = dot
    dashLine.texture = dot
    for _ in 0..<8 {
      let e = SKEmitterNode()
      e.particleTexture = dot
      e.particleBirthRate = 4000
      e.numParticlesToEmit = 1
      e.particleLifetime = 0.6
      e.particleLifetimeRange = 0.35
      e.emissionAngleRange = 2 * .pi
      e.particleAlpha = 1
      e.particleAlphaSpeed = -1.5
      e.particleScale = 0.55
      e.particleScaleRange = 0.35
      e.particleScaleSpeed = -0.5
      e.particleColorBlendFactor = 1
      e.particleBlendMode = .add
      e.particleSize = CGSize(width: 16, height: 16)
      e.zPosition = 6
      e.targetNode = world
      world.addChild(e)
      emitters.append(e)
    }
  }
  required init?(coder: NSCoder) { fatalError() }

  override func didMove(to view: SKView) {
    view.isMultipleTouchEnabled = true
    view.allowsTransparency = false
    view.isOpaque = true
    view.shouldCullNonVisibleNodes = false
    view.preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 60 : (view.window?.screen.maximumFramesPerSecond ?? 60)
  }

  /// The scene fills the whole screen so the art and sky reach every edge. Play stays inside the safe area,
  /// so `world` sits at its corner and these convert game coordinates into it.
  var insets = UIEdgeInsets.zero {
    didSet { if insets != oldValue { placeWorld() } }
  }
  private var area: CGSize { CGSize(width: max(1, size.width - insets.left - insets.right), height: max(1, size.height - insets.top - insets.bottom)) }
  private func y(_ gameY: Double) -> CGFloat { area.height - CGFloat(gameY) }
  private var worldOrigin: CGPoint { CGPoint(x: insets.left, y: insets.bottom) }
  private func placeWorld() { world.position = worldOrigin }

  // MARK: Frame

  override func update(_ currentTime: TimeInterval) {
    let dt = lastTime == 0 ? 1.0 / 60 : currentTime - lastTime
    lastTime = currentTime
    #if DEBUG
    perfSample(dt)
    #endif
    guard let session else { return }
    session.tick(dt)
    guard let game = session.game else { return }
    clock += dt
    #if DEBUG
    demoSwipe(game)
    demoSnap(game)
    #endif
    if session.generation != generation {
      generation = session.generation
      resetFor(game)
    }
    for e in session.pendingEvents { effect(e) }
    session.pendingEvents.removeAll(keepingCapacity: true)
    pulse = max(0, pulse - dt * 3)
    shake = max(0, shake - dt * 3)
    snapFlare = max(0, snapFlare - dt * 2)
    // A damped wobble instead of random jitter, so a hit reads as a shove and not as dropped frames.
    let origin = worldOrigin
    world.position = shake > 0 && !reduceMotion
      ? CGPoint(x: origin.x + sin(clock * 47) * 6 * shake, y: origin.y + cos(clock * 59) * 6 * shake) : origin
    let alpha = session.stepAlpha
    drawSky(game, dt: dt, session: session)
    drawRush(game, dt: dt)
    drawHinge(game)
    drawGates(game)
    drawBubbles(game, alpha: alpha)
    drawVisitors(game, alpha: alpha)
    drawPickups(game)
  }

  private func resetFor(_ game: Game) {
    for n in bubbleNodes.values { n.removeFromParent(); sparePuppets.append(n) }
    bubbleNodes.removeAll()
    for n in pickupNodes.values { n.removeFromParent() }
    pickupNodes.removeAll()
    for n in visitorNodes.values { n.removeFromParent() }
    visitorNodes.removeAll()
    for n in gateNodes { n.removeFromParent() }
    gateNodes.removeAll()
    active.removeAll()
    rushGlow = 0; rushFlash = 0; rushShown = 0; creaseTouch = nil
    rushNode.isHidden = true
    dashLine.isHidden = true
    prewarm(game)
    placeBackdrop()
  }

  /// Every sprite this screen could need is drawn ahead of time, off the main thread, so a split never
  /// waits for artwork in the middle of play.
  private func prewarm(_ game: Game) {
    guard game.scale != prewarmedFor else { return }
    prewarmedFor = game.scale
    let scale = displayScale
    var bubbles: [(BubbleKind, CGFloat)] = []
    for kind in BubbleKind.allCases {
      for size in 0..<4 {
        let actor: ActorKind = kind == .boss || kind == .bossHurt ? .boss : .basic
        bubbles.append((kind, CGFloat(game.radius(of: actor, size: actor == .boss ? 0 : size) * 2) / Art.bodyFraction(kind)))
      }
    }
    let cameo = CGFloat(game.visitorRadius * 2) / 0.72
    let power = CGFloat(54 * max(1, min(1.6, game.scale)))
    Task.detached(priority: .userInitiated) {
      for (k, px) in bubbles { _ = Art.bubble(k, size: px, scale: scale) }
      for k in CameoKind.allCases { _ = Art.cameo(k, size: cameo, scale: scale) }
      for k in PowerKind.allCases { _ = Art.power(k, size: power, scale: scale) }
      for k in [FXKind.popBurst, .particleStar] { _ = Art.fx(k, size: 96, scale: scale) }
      _ = Art.fx(.shockwave, size: 128, scale: scale)
    }
  }

  private func placeBackdrop() {
    guard size.width > 1, size.height > 1, let session else { return }
    let arena = session.game == nil ? Arena.classic : session.arena
    skyNode.size = size
    skyNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
    skyAspect.floatValue = Float(size.width / size.height)
    if skyArena != arena {
      skyArena = arena
      for (uniform, color) in zip(skyTints, arena.skyColors) { uniform.vectorFloat3Value = color }
    }
    let key = "\(arena.rawValue)-\(Int(size.width))x\(Int(size.height))"
    guard key != arenaKey, let art = ArenaKind(rawValue: arena.rawValue) else { return }
    arenaKey = key
    let box = size, scale = min(displayScale, 2)
    Task.detached(priority: .userInitiated) { [weak self] in
      let image = Art.arena(art, size: box, scale: scale)
      await MainActor.run {
        guard let self, self.arenaKey == key else { return }
        self.arenaNode.texture = SKTexture(cgImage: image)
        self.arenaNode.size = box
        self.arenaNode.color = .white
      }
    }
  }

  override func didChangeSize(_ oldSize: CGSize) { placeBackdrop() }

  private func drawSky(_ game: Game, dt: Double, session: Session) {
    let combo = game.players.map(\.combo).max() ?? 1
    let target = min(1, (combo - 1) / 6)
    energy += (target - energy) * min(1, dt * 3)
    bloom = max(0, bloom - dt * 1.1)
    if !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled { skyClock += dt * (session.isHeld ? 0.35 : 1) }
    skyTime.floatValue = Float(skyClock.truncatingRemainder(dividingBy: 2000))
    let windup = game.bubbles.contains { $0.bossWindup > 0 } ? 0.6 : 0
    skyHeat.floatValue = Float(max(session.heat, windup))
    skyEnergy.floatValue = Float(min(1.6, energy + bloom + hingeGlow() * 0.25))
    skyHinge.floatValue = game.vertical ? 0.5 : Float(game.hinge / max(1, game.h))
    for i in ripples.indices where ripples[i].z < 1 {
      ripples[i].z = min(1, ripples[i].z + Float(dt) / 0.95)
      skyRipples[i].vectorFloat3Value = ripples[i]
    }
  }

  private func drawRush(_ game: Game, dt: Double) {
    let target = game.rushLeft > 0 ? min(1, game.rushLeft / 0.8) : 0
    rushGlow += (target - rushGlow) * min(1, dt * 5)
    rushFlash = max(0, rushFlash - dt * 1.5)
    // Remember the page while the glow fades out after the rush ends.
    if game.rushSide != 0 { rushShown = game.rushSide }
    let side = rushShown
    guard rushGlow > 0.01, side != 0 else { rushNode.isHidden = true; return }
    rushNode.isHidden = false
    let hinge = CGFloat(game.hinge), w = CGFloat(game.w), top = CGFloat(game.top), h = CGFloat(game.h)
    if game.vertical {
      let x0 = side < 0 ? 0 : hinge, width = side < 0 ? hinge : w - hinge
      rushNode.size = CGSize(width: width, height: h - top)
      rushNode.position = CGPoint(x: x0 + width / 2, y: y(Double(top)) - (h - top) / 2)
      rushAxis.floatValue = 0; rushFlip.floatValue = side < 0 ? 1 : 0
    } else {
      let y0 = side < 0 ? top : hinge, height = side < 0 ? hinge - top : h - hinge
      rushNode.size = CGSize(width: w, height: height)
      rushNode.position = CGPoint(x: w / 2, y: y(Double(y0)) - height / 2)
      rushAxis.floatValue = 1; rushFlip.floatValue = side < 0 ? 0 : 1
    }
    rushTime.floatValue = reduceMotion ? 0 : Float(clock.truncatingRemainder(dividingBy: 1000))
    rushAlpha.floatValue = Float(rushGlow * (0.75 + 0.35 * hingeGlow()) + rushFlash * 0.8)
  }

  /// A pop shakes the sky: a ring of light runs out through the curtains from where it happened.
  private func ripple(_ p: CGPoint) {
    guard !reduceMotion, size.width > 1 else { return }
    ripples[nextRipple] = .init(Float((p.x + insets.left) / size.width), Float(1 - (p.y + insets.bottom) / size.height), 0)
    skyRipples[nextRipple].vectorFloat3Value = ripples[nextRipple]
    nextRipple = (nextRipple + 1) % ripples.count
  }

  private func meterColor(_ game: Game) -> UIColor {
    let m = game.players.map(\.meter).max() ?? 0
    if m >= game.meterMax - 1 { return UIColor(red: 1, green: 0.3, blue: 0.38, alpha: 1) }
    if m >= game.meterMax - 2 { return UIColor(red: 0.72, green: 0.48, blue: 1, alpha: 1) }
    return UIColor(red: 0.3, green: 0.78, blue: 1, alpha: 1)
  }

  private func drawHinge(_ game: Game) {
    let at = game.vertical ? CGFloat(game.hinge) : y(game.hinge)
    let meter = Double(game.players.map(\.meter).max() ?? 0)
    let color = meterColor(game), glow = hingeGlow()
    // The ribbon widens and brightens on a hit, with the meter, and as a real hinge folds.
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: nil)
    ribbonColor.vectorFloat3Value = .init(Float(r), Float(g), Float(b))
    ribbonTime.floatValue = reduceMotion ? 0 : Float(clock.truncatingRemainder(dividingBy: 1000))
    // A recharging snap dims the line, so you can see at a glance whether it's ready.
    let cooling = game.players.allSatisfy { $0.snapLeft > 0 } ? 0.62 : 1
    ribbonGlow.floatValue = Float((0.85 + pulse * 0.7 + meter * 0.12 + glow * 0.4) * cooling + snapFlare * 1.6)
    let width = (84 + CGFloat(pulse) * 60 + CGFloat(glow) * 34 + CGFloat(snapFlare) * 150) * CGFloat(max(1, min(1.6, game.scale)))
    // The light runs edge to edge, past the safe area. Only play stops there.
    let length = game.vertical ? area.height - CGFloat(game.top) + insets.bottom : size.width
    ribbon.size = CGSize(width: width, height: length)
    ribbonAmp.floatValue = reduceMotion ? 0 : Float((1.5 + pulse * 6 + meter * 0.7) / Double(width))
    ribbonCore.floatValue = Float(width / (1.4 + CGFloat(pulse) * 0.8))
    if game.vertical {
      ribbon.zRotation = 0
      ribbon.position = CGPoint(x: at, y: length / 2 - insets.bottom)
    } else {
      ribbon.zRotation = .pi / 2
      ribbon.position = CGPoint(x: length / 2 - insets.left, y: at)
    }
  }

  private func drawGates(_ game: Game) {
    while gateNodes.count < game.gates.count {
      let n = SKSpriteNode(color: UIColor(red: 0.3, green: 1, blue: 0.62, alpha: 1), size: CGSize(width: 10, height: 8))
      n.zPosition = 3
      world.addChild(n)
      gateNodes.append(n)
    }
    for (i, g) in game.gates.enumerated() {
      if game.vertical {
        gateNodes[i].size = CGSize(width: 8, height: CGFloat(g.width))
        gateNodes[i].position = CGPoint(x: CGFloat(game.hinge), y: y(g.at))
      } else {
        gateNodes[i].size = CGSize(width: CGFloat(g.width), height: 8)
        gateNodes[i].position = CGPoint(x: CGFloat(g.at), y: y(game.hinge))
      }
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

  private func drawBubbles(_ game: Game, alpha: Double) {
    var seen = Set<Int>(minimumCapacity: game.bubbles.count)
    var winding: (Bubble, CGPoint)?
    for b in game.bubbles {
      seen.insert(b.id)
      let kind = artKind(b)
      let draw = CGFloat(b.r * 2) / Art.bodyFraction(kind)
      let node: BubbleNode
      if let n = bubbleNodes[b.id] {
        node = n
      } else {
        node = sparePuppets.popLast() ?? BubbleNode()
        node.zPosition = 5
        node.setScale(1)
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
      // Physics runs in fixed steps. Drawing lands between the last two, so motion stays even at any frame rate.
      let px = b.prevX + (b.x - b.prevX) * alpha, py = b.prevY + (b.y - b.prevY) * alpha
      node.position = CGPoint(x: px, y: y(py))
      node.sprite.alpha = b.grace > 0 ? 0.78 : 1
      if b.kind == .boss {
        // A wind-up flushes red and swells, which is the player's cue to hit it.
        let flush = b.bossWindup > 0 ? 0.35 + 0.35 * sin(clock * 22) : (b.bossGuard > 0 ? 0.5 : 0)
        node.sprite.color = b.bossWindup > 0 ? .red : .white
        node.sprite.colorBlendFactor = CGFloat(flush)
        if b.bossWindup > 0 && !reduceMotion { node.setScale(1 + 0.05 * sin(clock * 22)) } else if !node.hasActions() { node.setScale(1) }
        if b.bossWindup > 0 { winding = (b, node.position) }
      } else if node.sprite.colorBlendFactor != 0 {
        node.sprite.colorBlendFactor = 0
      }
      // Squash along the direction of the hit, keeping the face upright.
      let q = reduceMotion ? 0 : CGFloat(b.sq) * 0.16
      node.squash.zRotation = -CGFloat(b.sqA)
      node.squash.xScale = 1 - q
      node.squash.yScale = 1 + q
      node.sprite.zRotation = CGFloat(b.sqA)
    }
    for (id, n) in bubbleNodes where !seen.contains(id) {
      n.removeAllActions()
      n.removeFromParent()
      sparePuppets.append(n)
      bubbleNodes[id] = nil
    }
    // The line it's about to dash along.
    if let (b, at) = winding {
      let hingePoint = game.vertical ? CGPoint(x: CGFloat(game.hinge), y: at.y) : CGPoint(x: at.x, y: y(game.hinge))
      place(dashLine, from: at, to: hingePoint, thickness: 26)
      dashLine.isHidden = false
      dashLine.alpha = CGFloat(0.9 - b.bossWindup / game.tuning.bossWindupTime * 0.7)
    } else if !dashLine.isHidden {
      dashLine.isHidden = true
    }
  }

  private func drawVisitors(_ game: Game, alpha: Double) {
    var seen = Set<Int>()
    for v in game.visitors {
      seen.insert(v.id)
      let node: SKSpriteNode
      if let n = visitorNodes[v.id] {
        node = n
      } else {
        let px = CGFloat(game.visitorRadius * 2) / 0.72
        let key = "cameo-\(v.cameo.rawValue)-\(Int(px))"
        let t = textures[key] ?? SKTexture(cgImage: Art.cameo(v.cameo.artKind, size: px, scale: displayScale))
        textures[key] = t
        node = SKSpriteNode(texture: t, size: CGSize(width: px, height: px))
        node.zPosition = 7
        world.addChild(node)
        visitorNodes[v.id] = node
      }
      node.position = CGPoint(x: v.prevX + (v.x - v.prevX) * alpha, y: y(v.prevY + (v.y - v.prevY) * alpha))
      node.alpha = CGFloat(max(0.12, v.presence))
      node.zRotation = reduceMotion ? 0 : CGFloat(sin(v.age * 2.1) * 0.14)
      if v.life < 1.5 { node.alpha *= CGFloat(v.life / 1.5) }
    }
    for (id, n) in visitorNodes where !seen.contains(id) {
      n.removeFromParent()
      visitorNodes[id] = nil
    }
  }

  /// Stretches a soft sprite between two points.
  private func place(_ n: SKSpriteNode, from a: CGPoint, to b: CGPoint, thickness: CGFloat) {
    n.size = CGSize(width: max(1, hypot(b.x - a.x, b.y - a.y) + thickness), height: thickness)
    n.position = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    n.zRotation = atan2(b.y - a.y, b.x - a.x)
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
        let key = "power-\(p.kind.rawValue)-\(Int(px))"
        let t = textures[key] ?? SKTexture(cgImage: Art.power(p.kind.artKind, size: px, scale: displayScale))
        textures[key] = t
        node = SKSpriteNode(texture: t, size: CGSize(width: px, height: px))
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

  /// Sprites and emitters are reused, because making nodes mid-play is what shows up as a hitch.
  private func sprite(_ texture: SKTexture?, size: CGSize, at p: CGPoint, z: CGFloat, add: Bool = false) -> SKSpriteNode {
    let n = spareSprites.popLast() ?? SKSpriteNode()
    n.texture = texture
    n.size = size
    n.position = p
    n.zPosition = z
    n.zRotation = 0
    n.alpha = 1
    n.setScale(1)
    n.colorBlendFactor = 0
    n.blendMode = add ? .add : .alpha
    world.addChild(n)
    return n
  }
  private func play(_ n: SKSpriteNode, _ action: SKAction) {
    n.run(action) { [weak self, weak n] in
      guard let n else { return }
      n.removeFromParent()
      self?.spareSprites.append(n)
    }
  }

  private func sparks(at p: CGPoint, r: CGFloat, count: Int) {
    guard !reduceMotion else { return }
    let palette = (session?.arena ?? .classic).sparkColors
    let e = emitters[nextEmitter]
    nextEmitter = (nextEmitter + 1) % emitters.count
    e.resetSimulation()
    e.position = p
    e.particleColor = palette[.random(in: 0..<palette.count)]
    e.particleSpeed = r * 2.6
    e.particleSpeedRange = r * 2
    e.numParticlesToEmit = min(40, count)
  }

  private func burst(at p: CGPoint, r: CGFloat, particles: Int) {
    if reduceMotion { return }
    let pop = sprite(fxTexture(.popBurst, size: 96), size: CGSize(width: r * 2.2, height: r * 2.2), at: p, z: 6)
    play(pop, Self.popAction)
    sparks(at: p, r: r, count: particles * 4)
    ripple(p)
  }
  private static let popAction = SKAction.group([.scale(to: 1.4, duration: 0.2), .fadeOut(withDuration: 0.2)])
  private static let waveAction = SKAction.group([.scale(to: 2.6, duration: 0.34), .fadeOut(withDuration: 0.34)])
  private static let trailAction = SKAction.fadeOut(withDuration: 0.3)
  private static let arcAction = SKAction.fadeOut(withDuration: 0.22)

  /// A swipe leaves a ribbon of aurora light behind the finger. The colour drifts along the stroke.
  private func trail(from a: CGPoint, to b: CGPoint) {
    guard !reduceMotion else { return }
    let palette = (session?.arena ?? .classic).sparkColors
    let index = Int(clock * 6) % palette.count
    let from = CGPoint(x: a.x, y: area.height - a.y), to = CGPoint(x: b.x, y: area.height - b.y)
    let n = sprite(fxTextures["softDot"], size: .zero, at: .zero, z: 7, add: true)
    place(n, from: from, to: to, thickness: 22)
    n.color = palette[index]
    n.colorBlendFactor = 1
    play(n, Self.trailAction)
  }

  /// A bolt of aurora between links of a chain pop.
  private func arc(from a: CGPoint, to b: CGPoint) {
    guard !reduceMotion else { return }
    let n = sprite(fxTextures["softDot"], size: .zero, at: .zero, z: 7, add: true)
    place(n, from: a, to: b, thickness: 18)
    n.color = UIColor(red: 0.55, green: 1, blue: 0.8, alpha: 1)
    n.colorBlendFactor = 1
    play(n, Self.arcAction)
  }

  #if DEBUG
  /// `-perf` logs frame times to the ready file after a warm-up, so smoothness is measured rather than guessed.
  private var perfTimes: [Double] = []
  private var demoSliceClock = 0.0
  private func perfSample(_ dt: Double) {
    guard Debug.has("-perf"), clock > 3 else { return }
    perfTimes.append(dt * 1000)
    guard perfTimes.count == 900 else { return }
    let sorted = perfTimes.sorted()
    let at = { (q: Double) in sorted[min(sorted.count - 1, Int(Double(sorted.count) * q))] }
    let long = perfTimes.filter { $0 > 25 }.count
    Debug.ready(String(format: "perf frames=900 p50=%.1f p95=%.1f p99=%.1f max=%.1f over25ms=%d nodes=%d", at(0.5), at(0.95), at(0.99), sorted.last ?? 0, long, world.children.count))
  }

  /// Store captures: real snaps going off often enough for a screenshot to catch one. Nothing is drawn specially.
  private func demoSnap(_ game: Game) {
    guard Debug.has("-demoSnap"), game.status == .playing else { return }
    game.players[0].snapLeft = 0
    if clock > demoSliceClock { demoSliceClock = clock + 0.45; game.snap(along: Double(area.width / 2)) }
  }

  /// Store captures: a real swipe, replayed in a loop through the same slice and trail a finger uses.
  private var demoPhase = 0.0
  private var demoLast: CGPoint?
  private var demoSkip = Set<Int>()
  private func demoSwipe(_ game: Game) {
    guard Debug.has("-demoSwipe"), game.status == .playing else { return }
    demoPhase += 1.0 / 28
    if demoPhase > 1.25 { demoPhase = 0; demoLast = nil; demoSkip.removeAll() }
    guard demoPhase <= 1 else { return }
    let t = demoPhase
    let p = CGPoint(x: area.width * (0.12 + 0.76 * t), y: area.height * (0.28 + 0.34 * t * t))
    if let last = demoLast {
      game.slice(fromX: last.x, fromY: last.y, toX: p.x, toY: p.y, skip: &demoSkip)
      trail(from: last, to: p)
    }
    demoLast = p
  }
  #endif

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
    let n = sprite(fxTexture(.shockwave, size: 128), size: CGSize(width: r * 2, height: r * 2), at: p, z: 4, add: true)
    play(n, Self.waveAction)
    ripple(p)
  }

  /// Numbers are built from pre-drawn glyphs. Changing a label's text re-renders it, which stutters at this rate.
  private func scoreText(_ value: Int, at p: CGPoint, color: UIColor = .white) {
    let unit = max(15, min(area.width, area.height) / 40)
    let grow = 1 + min(1.2, CGFloat(value) / 2500)
    let node = spareScores.popLast() ?? ScoreNode()
    node.show(value, glyphs: glyphs, height: unit * grow, color: color)
    node.position = p
    node.zPosition = 9
    node.alpha = 1
    world.addChild(node)
    node.run(reduceMotion ? Self.scoreStill : Self.scoreRise) { [weak self, weak node] in
      guard let node else { return }
      node.removeFromParent()
      self?.spareScores.append(node)
    }
  }
  private static let scoreRise = SKAction.group([.moveBy(x: 0, y: 34, duration: 0.8), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])])
  private static let scoreStill = SKAction.sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])

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
      let link = CGPoint(x: x, y: y(gy))
      if let last = lastChain, clock - lastChainClock < 0.05 { arc(from: last, to: link) }
      lastChain = link; lastChainClock = clock
      burst(at: link, r: CGFloat(r) * 1.3, particles: 4)
      scoreText(points, at: link, color: UIColor(red: 0.55, green: 1, blue: 0.75, alpha: 1))
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
    case let .hingeSnap(along, _, _):
      snapFlare = 1
      pulse = 1.6
      shake = 0.5
      if let game = session?.game {
        let spots = stride(from: 0.1, through: 0.9, by: 0.2)
        for u in spots {
          let at = game.vertical ? CGPoint(x: CGFloat(game.hinge), y: area.height * CGFloat(u)) : CGPoint(x: area.width * CGFloat(u), y: y(game.hinge))
          sparks(at: at, r: 46, count: 18)
        }
        ripple(game.vertical ? CGPoint(x: CGFloat(game.hinge), y: y(along)) : CGPoint(x: CGFloat(along), y: y(game.hinge)))
      }
      sound.blip(190, 0.2, .saw, gain: 0.18); sound.blip(1400, 0.12, .square, gain: 0.08)
      haptic.good()
    case .snapReady:
      sound.blip(880, 0.08, .sine, gain: 0.08)
    case let .rushStart(side):
      rushFlash = 1
      if let game = session?.game {
        let across = (Double(side) < 0 ? game.hinge / 2 : game.hinge + ((game.vertical ? game.w : game.h) - game.hinge) / 2)
        ripple(game.vertical ? CGPoint(x: across, y: y((game.top + game.h) / 2)) : CGPoint(x: game.w / 2, y: y(across)))
      }
      sound.blip(520, 0.12, .triangle, gain: 0.12); sound.blip(780, 0.2, .triangle, gain: 0.1)
      haptic.hit()
    case .rushOver:
      sound.blip(330, 0.14, .sine, gain: 0.06)
    case let .crossfold(x, gy, combo):
      if let game = session?.game {
        let at = game.vertical ? CGPoint(x: CGFloat(game.hinge), y: y(gy)) : CGPoint(x: x, y: y(game.hinge))
        sparks(at: at, r: 30, count: 14)
      }
      bloom = max(bloom, 0.35)
      sound.blip(600 + min(8, combo) * 60, 0.08, .sine, gain: 0.1)
    case let .creaseClap(flung):
      snapFlare = 1.4
      pulse = 1.8
      shake = 0.7
      bloom = 0.8
      if let game = session?.game {
        for u in stride(from: 0.06, through: 0.94, by: 0.11) {
          let at = game.vertical ? CGPoint(x: CGFloat(game.hinge), y: y(game.top + (game.h - game.top) * u)) : CGPoint(x: area.width * CGFloat(u), y: y(game.hinge))
          sparks(at: at, r: 60, count: 16)
        }
        let mid = game.vertical ? CGPoint(x: CGFloat(game.hinge), y: y((game.top + game.h) / 2)) : CGPoint(x: area.width / 2, y: y(game.hinge))
        shockwave(at: mid, r: 160)
        ripple(mid)
      }
      sound.blip(150, 0.25, .saw, gain: 0.2); sound.blip(1200 + Double(min(flung, 6)) * 80, 0.16, .square, gain: 0.08)
      haptic.good()
    case let .bossWindup(x, gy, r):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r))
      sound.blip(140, 0.5, .saw, gain: 0.14)
      haptic.hit()
    case let .bossStagger(x, gy, r, points):
      burst(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r), particles: 10)
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r) * 1.3)
      scoreText(points, at: CGPoint(x: x, y: y(gy) + CGFloat(r) * 0.5), color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1))
      bloom = 0.6
      sound.blip(520, 0.14, .square, gain: 0.16); sound.blip(780, 0.2)
      haptic.good()
    case .bossBlocked:
      sound.blip(190, 0.04, .sine, gain: 0.07)
    case let .cameoArrived(_, x, gy):
      ripple(CGPoint(x: min(max(0, x), area.width), y: y(gy)))
      sound.blip(740, 0.1, .sine, gain: 0.12); sound.blip(990, 0.16, .sine, gain: 0.12)
    case let .cameoCaught(_, x, gy, points, _):
      let at = CGPoint(x: x, y: y(gy))
      burst(at: at, r: 44, particles: 10)
      shockwave(at: at, r: 60)
      scoreText(points, at: at, color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1))
      bloom = 0.9
      sound.blip(660, 0.1); sound.blip(880, 0.12); sound.blip(1320, 0.22, .sine, gain: 0.15)
      haptic.good()
    case let .cameoDodged(_, x, gy):
      sparks(at: CGPoint(x: x, y: y(gy)), r: 30, count: 24)
      sound.blip(1500, 0.07, .sine, gain: 0.1)
    case let .cameoBlink(_, fromX, fromY, x, gy):
      sparks(at: CGPoint(x: fromX, y: y(fromY)), r: 34, count: 30)
      sparks(at: CGPoint(x: x, y: y(gy)), r: 26, count: 16)
      sound.blip(1000, 0.05, .square, gain: 0.05)
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
      if session?.game.status == .won || (session?.versus == true) {
        // Clearing a level lights up the whole sky before the confetti lands.
        bloom = 1.6
        ripple(CGPoint(x: area.width / 2, y: area.height / 2))
        confetti(); sound.blip(660, 0.3)
      }
      else { sound.blip(70, 0.6, .saw) }
    }
  }

  // MARK: Touch

  private var inputOn: Bool {
    guard let session else { return false }
    if session.overlay == .tour { return session.tourInput }
    return session.overlay == .none && session.tip == nil
  }

  private func gamePoint(_ touch: UITouch, in view: UIView) -> CGPoint {
    let p = touch.location(in: view)
    return CGPoint(x: p.x - insets.left, y: p.y - insets.top)
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard inputOn, let session, let game = session.game, let view else { return }
    for touch in touches {
      let p = gamePoint(touch, in: view)
      if session.overlay != .tour {
        if let guest = game.hitVisitor(x: p.x, y: p.y) { game.catchVisitor(guest.id); continue }
        if let pickup = game.hitPickup(x: p.x, y: p.y) { game.collect(pickup); continue }
      }
      let b = game.hit(x: p.x, y: p.y)
      // One finger on each page beside the fold, together, claps the crease.
      if b == nil, session.overlay != .tour, let side = game.besideCrease(x: p.x, y: p.y) {
        if let last = creaseTouch, last.side != side, clock - last.at <= game.tuning.clapWindow, game.clap() {
          creaseTouch = nil
          continue
        }
        creaseTouch = (side, clock)
      }
      if !game.flick && session.overlay != .tour {
        if let b { game.tap(b) }
      } else {
        active[ObjectIdentifier(touch)] = Stroke(bubble: b, start: p, last: p, onLine: b == nil && game.onHinge(x: p.x, y: p.y))
      }
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let session, let game = session.game, let view else { return }
    for touch in touches {
      let id = ObjectIdentifier(touch)
      guard var stroke = active[id] else { continue }
      // Every sample the screen took since the last frame, so a fast swipe draws and slices the line the finger made.
      for sample in event?.coalescedTouches(for: touch) ?? [touch] {
        let p = gamePoint(sample, in: view)
        if !stroke.slicing, hypot(p.x - stroke.start.x, p.y - stroke.start.y) < 18 { continue }
        if stroke.onLine {
          // Dragging off the line snaps it. If it's still recharging, the same drag is an ordinary swipe.
          stroke.onLine = false
          game.snap(along: game.vertical ? Double(stroke.start.y) : Double(stroke.start.x), owner: game.versus && (game.vertical ? Double(stroke.start.x) : Double(stroke.start.y)) >= game.hinge ? 1 : 0)
        }
        if !stroke.slicing {
          // The first stroke of a swipe also takes in whatever the finger started on.
          stroke.slicing = true
          stroke.last = stroke.start
        }
        game.slice(fromX: stroke.last.x, fromY: stroke.last.y, toX: p.x, toY: p.y, skip: &stroke.skip)
        trail(from: stroke.last, to: p)
        stroke.last = p
      }
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

/// White pre-drawn glyphs for floating scores, tinted at draw time.
@MainActor
final class ScoreGlyphs {
  private var map: [Character: (SKTexture, CGFloat)] = [:]
  private let drawn: CGFloat = 60
  init() {
    let base = UIFont.systemFont(ofSize: drawn, weight: .black)
    let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: drawn) } ?? base
    let shadow = NSShadow()
    shadow.shadowColor = UIColor.black.withAlphaComponent(0.45)
    shadow.shadowBlurRadius = 5
    shadow.shadowOffset = CGSize(width: 0, height: 2)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white, .shadow: shadow]
    for ch in "+,0123456789" {
      let text = NSAttributedString(string: String(ch), attributes: attrs)
      let box = text.size()
      let pad: CGFloat = 8
      let image = UIGraphicsImageRenderer(size: CGSize(width: box.width + pad * 2, height: drawn * 1.3)).image { _ in
        text.draw(at: CGPoint(x: pad, y: (drawn * 1.3 - box.height) / 2))
      }
      map[ch] = (SKTexture(image: image), box.width)
    }
  }
  func glyph(_ ch: Character) -> (texture: SKTexture, advance: CGFloat)? { map[ch].map { ($0.0, $0.1 / drawn) } }
  var aspect: CGFloat { 1.3 }
}

final class ScoreNode: SKNode {
  private var parts: [SKSpriteNode] = []
  func show(_ value: Int, glyphs: ScoreGlyphs, height: CGFloat, color: UIColor) {
    let text = "+\(value.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US"))))"
    while parts.count < text.count {
      let s = SKSpriteNode()
      s.colorBlendFactor = 1
      parts.append(s)
      addChild(s)
    }
    var x: CGFloat = 0
    var placed: [(SKSpriteNode, CGFloat)] = []
    for (i, ch) in text.enumerated() {
      guard let g = glyphs.glyph(ch) else { parts[i].isHidden = true; continue }
      let s = parts[i]
      s.isHidden = false
      s.texture = g.texture
      let w = height * (g.advance + 16 / 60)
      s.size = CGSize(width: w, height: height * glyphs.aspect)
      s.color = color
      let advance = height * g.advance
      placed.append((s, x + advance / 2))
      x += advance
    }
    for i in text.count..<max(text.count, parts.count) { parts[i].isHidden = true }
    for (s, at) in placed { s.position = CGPoint(x: at - x / 2, y: 0) }
  }
}
