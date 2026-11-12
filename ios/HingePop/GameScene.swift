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
  private var skyVariant = -1
  private var arenaKey = ""
  /// Darkens the art toward the hinge and calms it behind play, so bubbles are the brightest thing on screen.
  private let calmNode = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
  private let calmLine = SKUniform(name: "u_line", float: 0.5)
  private let calmAxis = SKUniform(name: "u_axis", float: 0)
  /// The biome bubbles are dressed for (`Art.bubble(..., biome:)`).
  private var skin: ArenaKind?
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
  /// Coral Drift: faint motes that ride the current, so you can see which way it flows.
  private var motes: [SKSpriteNode] = []
  /// Every other world twist and boss style is drawn here (TwistLayer.swift).
  private var twists: TwistLayer!
  /// Easter eggs: a twinkle on the level's secret bubble, and taps counted on the world's hidden spot.
  private let glint = SKLabelNode(text: "✦")
  private var spotTaps: [Double] = []
  /// The last touch beside the crease, for spotting a clap: one finger on each page at once.
  private var creaseTouch: (side: Int, at: Double)?
  private var lastTime: TimeInterval = 0
  private var pulse = 0.0
  private var clock = 0.0
  private var lastBump = 0.0
  private var generation = -1
  private var prewarmedFor = -1.0
  /// One finger on the screen: what it landed on, where it last was, and what this stroke has already hit.
  private struct Stroke { var bubble: Bubble?; var start: CGPoint; var last: CGPoint; var slicing = false; var skip = Set<Int>(); var onLine = false }
  private var active: [ObjectIdentifier: Stroke] = [:]
  private let displayScale: CGFloat
  /// Game feel: hit-stop, slow motion, camera, screen light, callouts, combo counter, confetti (Juice.swift).
  private var feel: FeelLayer!
  /// Where bubbles split this frame, so their pieces can burst out of the middle.
  private var recentSplits: [(CGPoint, CGFloat)] = []
  private var lastPopPoint = CGPoint.zero
  private var comboTiers = [0, 0]
  private var bossIntroFor: ObjectIdentifier?
  private var bossDownFor: ObjectIdentifier?
  private var bossDownAt = -10.0
  private var lastOneFor: ObjectIdentifier?
  /// Frame time as the game sees it: zero in a hit-stop, slowed in slow motion.
  private var visualDt = 1.0 / 60
  /// Floating points that fly up from a pop and into the score.
  private struct Flight { let node: ScoreNode; let start: CGPoint; var age = 0.0 }
  private var flights: [Flight] = []
  /// Overtime step reached this level (0 = none) and how hot fever is, both from the rules.
  private var overtime = 0
  private var feverNow = 0.0
  /// The snap's ripple running along the line: where it started (0...1 along the ribbon) and its age.
  private let ribbonSnap = SKUniform(name: "u_sp", vectorFloat2: .init(0.5, 1))
  private var snapAge = 1.0
  private var snapAt: Float = 0.5

  init(scale: CGFloat) {
    displayScale = scale
    super.init(size: CGSize(width: 10, height: 10))
    backgroundColor = UIColor(red: 0.08, green: 0.04, blue: 0.18, alpha: 1)
    scaleMode = .resizeFill
    anchorPoint = .zero
    addChild(arenaNode)
    addChild(calmNode)
    addChild(skyNode)
    addChild(world)
    arenaNode.zPosition = -20
    arenaNode.anchorPoint = .zero
    // The sky: two aurora curtains hung in the halves either side of the hinge, never on it, with slow broad
    // rays. Time arrives already wrapped (see drawSky) and every phase speed is a multiple of 0.1, so the
    // numbers stay small: large sine arguments lose precision on the GPU and step the light into bands.
    let sky = SKShader(source: """
    float wave(vec2 p, float t, float s, float f, float ph) { return sin(p.x * f + t * s + ph + 1.6 * sin(p.x * f * 0.37 - t * s * 0.5 + ph)); }
    float ring(vec3 r, vec2 p, float aspect) {
      if (r.z >= 1.0) { return 0.0; }
      float l = length(p - vec2(r.x * aspect, r.y));
      float d = (l - r.z * 0.62) * 11.0;
      return exp(-d * d) * (1.0 - r.z);
    }
    float curtain(float y, float c) {
      float d = y - c;
      return d > 0.0 ? exp(-d * d * 18.0) : exp(-d * d * 90.0);
    }
    void main() {
      vec2 uv = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y);
      vec2 p = vec2(uv.x * u_aspect, uv.y);
      float rip = ring(u_r0, p, u_aspect) + ring(u_r1, p, u_aspect) + ring(u_r2, p, u_aspect) + ring(u_r3, p, u_aspect);
      p.y += rip * 0.045;
      float t = u_t;
      vec3 col = vec3(0.0);
      float c0 = u_hinge * 0.32 + 0.035 * wave(p, t, 0.2, 2.2, 0.0);
      col += u_c1 * curtain(p.y, c0) * (0.78 + 0.22 * sin(p.x * 7.0 + 1.2 * wave(p, t, 0.4, 3.0, 0.0) + t * 0.2));
      float c1 = u_hinge + (1.0 - u_hinge) * 0.64 + 0.045 * wave(p, t, 0.2, 2.9, 4.2);
      col += u_c2 * curtain(p.y, c1) * (0.78 + 0.22 * sin(p.x * 9.0 + 1.2 * wave(p, t, 0.4, 3.0, 2.0) + t * 0.2));
      // The third colour glows faintly along the top and bottom edges, framing the play.
      col += u_c3 * (exp(-uv.y * uv.y * 40.0) + exp(-(1.0 - uv.y) * (1.0 - uv.y) * 40.0)) * 0.35;
      // Quiet near the hinge, where the play is decided; the combo brightens it, but never to a wash.
      col *= (0.2 + u_energy * 0.22) * (0.25 + 0.75 * smoothstep(0.06, 0.4, abs(uv.y - u_hinge)));
      col += (u_c1 * 0.5 + u_c2 * 0.5) * rip * 0.5;
      float luma = dot(col, vec3(0.34));
      col = mix(col, vec3(1.0, 0.24, 0.32) * luma * 1.6, clamp(u_heat, 0.0, 1.0) * 0.8);
      float n = fract(sin(dot(v_tex_coord, vec2(12.9898, 78.233)) * 43.7585) * 1000.0);
      col = max(col + (n - 0.5) * (2.0 / 255.0), vec3(0.0));
      gl_FragColor = vec4(col, 0.0);
    }
    """)
    sky.uniforms = [skyTime, skyHeat, skyEnergy, skyAspect, skyHinge] + skyTints + skyRipples
    skyNode.shader = sky
    skyNode.blendMode = .add
    skyNode.zPosition = -10
    let calm = SKShader(source: """
    void main() {
      vec2 uv = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y);
      float d = u_axis > 0.5 ? abs(uv.x - u_line) : abs(uv.y - u_line);
      float near = 1.0 - smoothstep(0.0, 0.45, d);
      float a = 0.2 + 0.32 * near * near;
      gl_FragColor = vec4(vec3(0.02, 0.01, 0.06) * a, a);
    }
    """)
    calm.uniforms = [calmLine, calmAxis]
    calmNode.shader = calm
    calmNode.zPosition = -15
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
      // A snap sends a kink racing both ways along the line from where it was pulled.
      float sd = abs(uv.y - u_sp.x) - u_sp.y * 1.4;
      float sw = exp(-sd * sd * 700.0) * (1.0 - u_sp.y) * (1.0 - u_sp.y);
      off += sw * 0.16 * sin(sd * 90.0);
      float dc = (uv.x - 0.5 - off) * u_core;
      float core = exp(-dc * dc) * (1.0 + sw * 1.5);
      col = col * a + vec3(1.0) * core * 0.95;
      gl_FragColor = vec4(col, min(1.0, a + core));
    }
    """)
    shader.uniforms = [ribbonTime, ribbonGlow, ribbonColor, ribbonAmp, ribbonCore, ribbonSnap]
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
    twists = TwistLayer(parent: world, dot: dot, host: .init(
      sparks: { [unowned self] p, r, n, color in self.sparks(at: p, r: r, count: n, color: color) },
      shockwave: { [unowned self] p, r in self.shockwave(at: p, r: r) },
      ripple: { [unowned self] p in self.ripple(p) }))
    for _ in 0..<14 {
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
    feel = FeelLayer(scene: self, dot: dot, scale: scale)
    feel.onHeartbeat = { [unowned self] danger in
      Haptics.shared.play(.heartbeat)
      Sound.shared.blip(danger >= 1 ? 62 : 55, 0.14, .sine, gain: 0.12, fall: 0.3)
    }
    // Pools filled up front, so the first busy moment of a level never makes a node.
    for _ in 0..<48 { spareSprites.append(SKSpriteNode()) }
    for _ in 0..<32 { let n = ScoreNode(); n.reserve(8); spareScores.append(n) }
    for _ in 0..<24 { sparePuppets.append(BubbleNode()) }
    feel.counter.reserve(6)
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
  private var safe: CGSize { CGSize(width: max(1, size.width - insets.left - insets.right), height: max(1, size.height - insets.top - insets.bottom)) }
  /// Where play happens inside the safe area (UIKit coordinates). Solo it's all of it; two players each keep a
  /// scoreboard band at their own edge, so play sits between them.
  private var play: CGRect {
    guard let r = session?.playRect, r.width > 1, r.height > 1 else { return CGRect(origin: .zero, size: safe) }
    return r
  }
  /// The play area's size. Game coordinates run from its top-left corner, y down.
  private var area: CGSize { play.size }
  private func y(_ gameY: Double) -> CGFloat { area.height - CGFloat(gameY) }
  /// The play area's bottom-left corner in the scene, where `world` sits.
  private var worldOrigin: CGPoint { CGPoint(x: insets.left + play.minX, y: insets.bottom + safe.height - play.maxY) }
  private func placeWorld() { world.position = worldOrigin }
  /// Which way something at this world point faces: toward the player whose half it's on (two players only).
  private func facing(at p: CGPoint) -> CGFloat {
    guard let game = session?.game, game.versus else { return 0 }
    let near = game.vertical ? Double(p.x) < game.hinge : Double(y(Double(p.y))) < game.hinge
    return Seat.radians(near ? 0 : 1, vertical: game.vertical)
  }
  private func facing(player: Int) -> CGFloat {
    guard let game = session?.game, game.versus else { return 0 }
    return Seat.radians(player, vertical: game.vertical)
  }
  /// The middle of a player's half, in world space.
  private func halfMiddle(_ player: Int, _ game: Game) -> CGPoint {
    let lineAt = game.vertical ? CGFloat(game.hinge) : y(game.hinge)
    let edge: CGFloat = game.vertical ? (player == 0 ? 0 : area.width) : (player == 0 ? area.height : 0)
    let mid = (lineAt + edge) / 2
    return game.vertical ? CGPoint(x: mid, y: area.height / 2) : CGPoint(x: area.width / 2, y: mid)
  }
  /// "Up" as a player turned by `angle` reads it (toward the hinge from their edge), in world space.
  private func up(_ angle: CGFloat) -> CGVector { CGVector(dx: -sin(angle), dy: cos(angle)) }

  // MARK: Frame

  override func update(_ currentTime: TimeInterval) {
    let dt = lastTime == 0 ? 1.0 / 60 : currentTime - lastTime
    lastTime = currentTime
    #if DEBUG
    perfSample(dt)
    let workStart = CACurrentMediaTime()
    lapAt = workStart
    defer { perfWork(CACurrentMediaTime() - workStart) }
    #endif
    guard let session else { return }
    let rdt = min(0.05, dt)
    feel.reduceMotion = reduceMotion
    feel.area = area
    feel.step(rdt)
    // Hit-stop and slow motion run the rules slower; everything else keeps real time.
    session.tick(dt * feel.simScale)
    #if DEBUG
    lap(0)
    #endif
    visualDt = rdt * feel.simScale
    guard let game = session.game else { return }
    clock += dt
    #if DEBUG
    demoSwipe(game)
    demoSnap(game)
    demoFX(game)
    #endif
    if session.generation != generation {
      generation = session.generation
      resetFor(game)
    }
    liveIDs = nil
    for e in session.pendingEvents { effect(e) }
    #if DEBUG
    lap(1)
    #endif
    session.pendingEvents.removeAll(keepingCapacity: true)
    pulse = max(0, pulse - dt * 3)
    snapFlare = max(0, snapFlare - dt * 2)
    snapAge = min(1, snapAge + rdt / 0.42)
    ribbonSnap.vectorFloat2Value = .init(snapAt, Float(snapAge))
    // The camera: shake, shoves and zoom punches, all from the feel layer. The backdrop stays put.
    let (at, zoom) = feel.camera(origin: worldOrigin)
    world.position = at
    world.setScale(zoom)
    // Actions (bursts, fly-ups, spawns) freeze in a hit-stop and slow with slow motion.
    world.speed = CGFloat(feel.simScale)
    let alpha = session.stepAlpha
    drawSky(game, dt: dt, session: session)
    drawRush(game, dt: dt)
    drawCurrent(game, dt: dt)
    twists.update(game, area: area, clock: clock, dt: dt, reduceMotion: reduceMotion)
    drawGlint(game, alpha: alpha)
    drawHinge(game)
    drawGates(game)
    #if DEBUG
    lap(2)
    #endif
    drawBubbles(game, alpha: alpha)
    #if DEBUG
    lap(3)
    #endif
    drawVisitors(game, alpha: alpha)
    drawPickups(game)
    #if DEBUG
    lap(4)
    #endif
    drawFeel(game, session: session, dt: rdt)
    #if DEBUG
    lap(5)
    #endif
    recentSplits.removeAll(keepingCapacity: true)
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
    motes.forEach { $0.removeFromParent() }
    motes.removeAll()
    rushNode.isHidden = true
    dashLine.isHidden = true
    feel.reset()
    for f in flights { f.node.removeFromParent(); spareScores.append(f.node) }
    flights.removeAll()
    comboTiers = [0, 0]
    overtime = 0; feverNow = 0
    recentSplits.removeAll()
    world.setScale(1); world.speed = 1
    twists.reset(game, arena: session?.arena ?? game.spec.arena)
    prewarm(game)
    placeBackdrop()
  }

  /// Every sprite this screen could need is drawn ahead of time, off the main thread, so a split never
  /// waits for artwork in the middle of play.
  private func prewarm(_ game: Game) {
    let biome = ArenaKind(rawValue: (session?.arena ?? .classic).rawValue)
    guard game.scale != prewarmedFor || biome != skin else { return }
    prewarmedFor = game.scale
    skin = biome
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
      for (k, px) in bubbles { _ = Art.bubble(k, size: px, scale: scale, biome: biome) }
      for k in CameoKind.allCases { _ = Art.cameo(k, size: cameo, scale: scale) }
      for k in PowerKind.allCases { _ = Art.power(k, size: power, scale: scale) }
      for k in [FXKind.popBurst, .particleStar] { _ = Art.fx(k, size: 96, scale: scale) }
      _ = Art.fx(.shockwave, size: 128, scale: scale)
      for i in 0..<Art.confettiVariants { _ = Art.fx(.confetti(i), size: 24, scale: scale) }
      // The art is cached now, so these textures are cheap to make on the main thread.
      await MainActor.run { [weak self] in
        guard let self else { return }
        let bits = (0..<Art.confettiVariants).map { self.fxTexture(.confetti($0), size: 24) }
        self.feel.dress(confetti: bits, ring: self.fxTexture(.shockwave, size: 128))
        _ = self.fxTexture(.popBurst, size: 96)
      }
    }
  }

  private func placeBackdrop() {
    guard size.width > 1, size.height > 1, let session else { return }
    let arena = session.game == nil ? Arena.classic : session.arena
    let variant = session.game == nil ? 0 : session.variant
    skyNode.size = size
    skyNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
    calmNode.size = size
    calmNode.position = skyNode.position
    skyAspect.floatValue = Float(size.width / size.height)
    if skyArena != arena || skyVariant != variant {
      skyArena = arena
      skyVariant = variant
      for (uniform, color) in zip(skyTints, arena.skyColors(variant: variant)) { uniform.vectorFloat3Value = color }
    }
    let key = "\(arena.rawValue)-\(variant)-\(Int(size.width))x\(Int(size.height))"
    guard key != arenaKey, let art = ArenaKind(rawValue: arena.rawValue) else { return }
    arenaKey = key
    let box = size, scale = min(displayScale, 2)
    Task.detached(priority: .userInitiated) { [weak self] in
      let image = Art.arena(art, variant: variant, size: box, scale: scale)
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
    // The clock runs faster with the combo here rather than in the shader, and wraps at 20π: every phase
    // speed in the sky is a multiple of 0.1, so the wrap is seamless and the numbers stay small.
    if !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled {
      skyClock += dt * (session.isHeld ? 0.35 : 1) * (1 + min(1.6, energy + bloom) * 1.6)
    }
    skyClock = skyClock.truncatingRemainder(dividingBy: 20 * .pi)
    skyTime.floatValue = Float(skyClock)
    let windup = game.bubbles.contains { $0.bossWindup > 0 } ? 0.6 : 0
    skyHeat.floatValue = Float(max(session.heat, windup))
    skyEnergy.floatValue = Float(min(1.6, energy + bloom + hingeGlow() * 0.25 + feverNow * 0.7))
    // Where the hinge sits on screen, 0...1 from the top (or the left).
    let screenLine = game.vertical ? (CGFloat(game.hinge) + worldOrigin.x) / max(1, size.width) : 1 - (y(game.hinge) + worldOrigin.y) / max(1, size.height)
    skyHinge.floatValue = game.vertical ? 0.5 : Float(screenLine)
    calmAxis.floatValue = game.vertical ? 1 : 0
    calmLine.floatValue = Float(screenLine)
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

  private func drawGlint(_ game: Game, alpha: Double) {
    if glint.parent == nil {
      glint.fontSize = 18; glint.fontColor = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
      glint.blendMode = .add; glint.zPosition = 6; glint.verticalAlignmentMode = .center
      world.addChild(glint)
    }
    guard let id = game.secretBubble, let b = game.bubbles.first(where: { $0.id == id }) else { glint.isHidden = true; return }
    glint.isHidden = false
    let x = b.prevX + (b.x - b.prevX) * alpha, gy = b.prevY + (b.y - b.prevY) * alpha
    glint.position = CGPoint(x: CGFloat(x + b.r * 0.55), y: y(gy + -b.r * 0.55))
    // A slow twinkle: easy to miss, easy to spot once you know.
    let t = reduceMotion ? 0.6 : 0.35 + 0.65 * max(0, sin(clock * 2.3))
    glint.alpha = CGFloat(t)
    glint.setScale(CGFloat(0.8 + t * 0.4))
  }

  /// Three taps on a world's hidden spot, close together, wakes its secret.
  private func tapSpot(_ p: CGPoint, game: Game) -> Bool {
    guard let session, size.width > 1 else { return false }
    let arena = session.arena
    let s = Secrets.spot(arena, width: Double(size.width), height: Double(size.height))
    guard hypot(Double(p.x) - s.x, Double(p.y) - s.y) <= s.r else { return false }
    spotTaps = spotTaps.filter { clock - $0 < 2 } + [clock]
    let at = CGPoint(x: CGFloat(s.x) - worldOrigin.x, y: size.height - CGFloat(s.y) - worldOrigin.y)
    sparks(at: at, r: 24, count: 8)
    guard spotTaps.count >= 3 else { return true }
    spotTaps.removeAll()
    let secret = Secrets.spotSecret(arena)
    shockwave(at: at, r: 90)
    burst(at: at, r: 50, particles: 14)
    bloom = 1
    let label = SKLabelNode(text: secret.emoji)
    label.fontSize = 64; label.position = at; label.zPosition = 20; label.verticalAlignmentMode = .center
    world.addChild(label)
    label.run(.sequence([.group([.moveBy(x: 0, y: 70, duration: 1.4), .sequence([.scale(to: 1.4, duration: 0.25), .scale(to: 1, duration: 0.3)]), .sequence([.wait(forDuration: 1), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
    let sound = Sound.shared
    sound.blip(660, 0.1); sound.blip(990, 0.14); sound.blip(1320, 0.24, .sine, gain: 0.14)
    session.reveal(secret)
    return true
  }

  private func drawCurrent(_ game: Game, dt: Double) {
    guard game.spec.current != 0 else { motes.forEach { $0.isHidden = true }; return }
    if motes.isEmpty {
      var d = SystemRandomNumberGenerator()
      for _ in 0..<18 {
        let m = SKSpriteNode(color: UIColor(red: 0.8, green: 1, blue: 1, alpha: 1), size: CGSize(width: 3, height: 3))
        m.blendMode = .add
        m.zPosition = -4
        m.alpha = CGFloat.random(in: 0.15...0.4, using: &d)
        m.position = CGPoint(x: CGFloat.random(in: 0...max(1, area.width), using: &d), y: CGFloat.random(in: 0...max(1, area.height), using: &d))
        world.addChild(m)
        motes.append(m)
      }
    }
    // The same flow the rules use, drawn a little faster so it reads at a glance.
    let flow = game.spec.current * game.scale * sin(game.time * 2 * .pi / game.tuning.currentPeriod)
    let step = CGFloat(flow * dt * (reduceMotion ? 0 : 2.2))
    for m in motes {
      m.isHidden = false
      if game.vertical {
        m.position.y -= step
        m.xScale = 1; m.yScale = 1 + min(5, abs(step) * 1.5)
        if m.position.y < 0 { m.position.y += area.height } else if m.position.y > area.height { m.position.y -= area.height }
      } else {
        m.position.x += step
        m.yScale = 1; m.xScale = 1 + min(5, abs(step) * 1.5)
        if m.position.x < 0 { m.position.x += area.width } else if m.position.x > area.width { m.position.x -= area.width }
      }
    }
  }

  /// A pop shakes the sky: a ring of light runs out through the curtains from where it happened.
  private func ripple(_ p: CGPoint) {
    guard !reduceMotion, size.width > 1 else { return }
    ripples[nextRipple] = .init(Float((p.x + worldOrigin.x) / size.width), Float(1 - (p.y + worldOrigin.y) / size.height), 0)
    skyRipples[nextRipple].vectorFloat3Value = ripples[nextRipple]
    nextRipple = (nextRipple + 1) % ripples.count
  }

  private func meterColor(_ game: Game) -> UIColor {
    let m = game.players.map(\.meter).max() ?? 0
    if m >= game.meterMax - 1 { return UIColor(red: 1, green: 0.3, blue: 0.38, alpha: 1) }
    if m >= game.meterMax - 2 { return UIColor(red: 0.72, green: 0.48, blue: 1, alpha: 1) }
    // Overdrive runs the hinge hot: amber instead of cyan while it's calm.
    if game.difficulty == .overdrive { return UIColor(red: 1, green: 0.62, blue: 0.22, alpha: 1) }
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
    ribbonGlow.floatValue = Float((0.85 + pulse * 0.7 + meter * 0.12 + glow * 0.4) * cooling + snapFlare * 1.6 + twists.hingeBoost)
    let width = (84 + CGFloat(pulse) * 60 + CGFloat(glow) * 34 + CGFloat(snapFlare) * 150) * CGFloat(max(1, min(1.6, game.scale)))
    // The light runs edge to edge, past the safe area. Only play stops there.
    let length = game.vertical ? area.height - CGFloat(game.top) + worldOrigin.y : size.width
    ribbon.size = CGSize(width: width, height: length)
    ribbonAmp.floatValue = reduceMotion ? 0 : Float((1.5 + pulse * 6 + meter * 0.7) / Double(width))
    ribbonCore.floatValue = Float(width / (1.4 + CGFloat(pulse) * 0.8))
    if game.vertical {
      ribbon.zRotation = 0
      ribbon.position = CGPoint(x: at, y: length / 2 - worldOrigin.y)
    } else {
      ribbon.zRotation = .pi / 2
      ribbon.position = CGPoint(x: length / 2 - worldOrigin.x, y: at)
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
    let key = "\(kind.rawValue)-\(skin?.rawValue ?? "")-\(Int(px))"
    if let t = textures[key] { return t }
    let t = SKTexture(cgImage: Art.bubble(kind, size: px, scale: displayScale, biome: skin))
    textures[key] = t
    return t
  }

  private func drawBubbles(_ game: Game, alpha: Double) {
    var seen = Set<Int>(minimumCapacity: game.bubbles.count)
    var winding: (Bubble, CGPoint)?
    var bosses: [BubbleNode] = []
    for b in game.bubbles {
      seen.insert(b.id)
      let kind = artKind(b)
      let draw = CGFloat(b.r * 2) / Art.bodyFraction(kind)
      // Physics runs in fixed steps. Drawing lands between the last two, so motion stays even at any frame rate.
      let px = b.prevX + (b.x - b.prevX) * alpha, py = b.prevY + (b.y - b.prevY) * alpha
      let at = CGPoint(x: px, y: y(py))
      let node: BubbleNode
      if let n = bubbleNodes[b.id] {
        node = n
      } else {
        node = sparePuppets.popLast() ?? BubbleNode()
        node.zPosition = 5
        node.setScale(1)
        node.alpha = 1
        node.isHidden = false
        node.flash = 0
        node.birth = .zero
        node.birthT = 1
        // Born facing its owner. Only a crossing turns it after that.
        let f = facing(player: game.playerIndex(of: b))
        node.face = f; node.faceFrom = f; node.faceTo = f; node.flipT = 1
        world.addChild(node)
        bubbleNodes[b.id] = node
        if b.grace > 0 && !reduceMotion {
          // Split pieces: a squeezed beat at the parent's centre, then they spring out to where the rules put them.
          node.setScale(0.4)
          node.run(Self.spawnAction)
          let parent = recentSplits.min { hypot($0.0.x - at.x, $0.0.y - at.y) < hypot($1.0.x - at.x, $1.0.y - at.y) }
          if let (c, r) = parent, hypot(c.x - at.x, c.y - at.y) < r * 4 {
            node.birth = CGVector(dx: c.x - at.x, dy: c.y - at.y)
            node.birthT = 0
          }
        }
      }
      if node.kind != kind || node.drawSize != draw {
        node.kind = kind; node.drawSize = draw
        let t = texture(kind, size: draw)
        node.sprite.texture = t
        node.sprite.size = CGSize(width: draw, height: draw)
        node.glare.texture = t
        node.glare.size = node.sprite.size
      }
      if node.birthT < 1 {
        node.birthT = min(1, node.birthT + visualDt / 0.13)
        // Hold for the first quarter (the anticipation), then ease out fast.
        let k = max(0, (node.birthT - 0.25) / 0.75)
        let left = CGFloat(pow(1 - k, 3))
        node.position = CGPoint(x: at.x + node.birth.dx * left, y: at.y + node.birth.dy * left)
      } else {
        node.position = at
      }
      // Fog, the dark and ghosts dim a bubble; springs, regrowth and phasing tint it.
      let look = twists.look(b, game: game)
      node.sprite.alpha = (b.grace > 0 ? 0.78 : 1) * look.alpha
      if b.kind == .boss {
        // A wind-up flushes red and swells, which is the player's cue to hit it.
        let flush = b.bossWindup > 0 ? 0.35 + 0.35 * sin(clock * 22) : (b.bossGuard > 0 ? 0.5 : 0)
        node.sprite.color = b.bossWindup > 0 ? .red : .white
        node.sprite.colorBlendFactor = CGFloat(flush)
        if b.bossWindup > 0 && !reduceMotion { node.setScale(1 + 0.05 * sin(clock * 22)) } else if !node.hasActions() { node.setScale(1) }
        if b.bossWindup > 0 { winding = (b, node.position) }
      } else if let tint = look.tint {
        node.sprite.color = tint
        node.sprite.colorBlendFactor = look.amount
        if !node.hasActions() { node.setScale(reduceMotion ? 1 : look.scale) }
      } else if node.sprite.colorBlendFactor != 0 || node.xScale != 1 {
        node.sprite.colorBlendFactor = 0
        if !node.hasActions() { node.setScale(1) }
      }
      // Two players: the face turns toward whoever's half it's on. Crossing the hinge spins it round to face
      // the other player; with Reduce Motion it just turns.
      var flipDip: CGFloat = 0
      if game.versus {
        let want = facing(player: game.playerIndex(of: b))
        if abs(atan2(sin(want - node.faceTo), cos(want - node.faceTo))) > 0.01 {
          node.faceFrom = node.face
          // Spin the way it's travelling, so it reads as tumbling over the line.
          var to = want
          while to - node.faceFrom > .pi + 0.01 { to -= 2 * .pi }
          while node.faceFrom - to > .pi + 0.01 { to += 2 * .pi }
          if abs(abs(to - node.faceFrom) - .pi) < 0.01 { to = node.faceFrom + (b.vx + b.vy >= 0 ? -1 : 1) * .pi }
          node.faceTo = to
          node.flipT = reduceMotion ? 1 : 0
          #if DEBUG
          if b.size < 3 { freeze("flip", after: Debug.string("-freezeAfter").flatMap(Double.init) ?? 0.12) }
          #endif
        }
        if node.flipT < 1 {
          var flipTime = 0.3
          #if DEBUG
          // `-flipTime s` slows the turn so a capture can catch one halfway.
          flipTime = Debug.string("-flipTime").flatMap(Double.init) ?? flipTime
          #endif
          node.flipT = min(1, node.flipT + visualDt / flipTime)
          let t = node.flipT, e = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
          node.face = node.faceFrom + (node.faceTo - node.faceFrom) * CGFloat(e)
          flipDip = CGFloat(sin(t * .pi)) * 0.22
        } else {
          node.face = node.faceTo
        }
      }
      // Squash along the direction of the hit, keeping the face upright (or turned to its player).
      let q = reduceMotion ? 0 : CGFloat(b.sq) * 0.16
      node.squash.zRotation = -CGFloat(b.sqA)
      node.squash.xScale = (1 - q) * (1 - flipDip)
      node.squash.yScale = (1 + q) * (1 - flipDip * 0.4)
      node.sprite.zRotation = CGFloat(b.sqA) + node.face
      // A hit flashes the bubble white for a moment (bosses, armour).
      if node.flash > 0 {
        node.flash = max(0, node.flash - visualDt * 7)
        node.glare.isHidden = node.flash <= 0
        node.glare.alpha = CGFloat(min(1, node.flash))
        node.glare.zRotation = node.sprite.zRotation
      }
      if b.kind == .boss { bosses.append(node) }
    }
    bossIntro(game, nodes: bosses)
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
      node.zRotation = facing(at: CGPoint(x: p.x, y: y(p.y)))
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

  private func sparks(at p: CGPoint, r: CGFloat, count: Int, color: UIColor? = nil, fast: Bool = false) {
    guard !reduceMotion else { return }
    let palette = (session?.arena ?? .classic).sparkColors
    let e = emitters[nextEmitter]
    nextEmitter = (nextEmitter + 1) % emitters.count
    e.resetSimulation()
    e.position = p
    e.particleColor = color ?? palette[.random(in: 0..<palette.count)]
    // Fast sparks are small white-hot glitter that outruns the coloured cloud.
    e.particleSpeed = r * (fast ? 4.4 : 2.6)
    e.particleSpeedRange = r * (fast ? 2.4 : 2)
    e.particleScale = fast ? 0.32 : 0.55
    e.particleLifetime = fast ? 0.38 : 0.6
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
  /// The popped bubble itself: squashes flat on the hit, then blows out and fades.
  private static let ghostAction = SKAction.sequence([
    .scaleX(to: 1.24, y: 0.78, duration: 0.04),
    .group([.scale(to: 1.55, duration: 0.13), .fadeOut(withDuration: 0.13)]),
  ])
  /// A white-hot core at the centre of a pop.
  private static let coreAction = SKAction.group([.scale(to: 2.2, duration: 0.12), .fadeOut(withDuration: 0.12)])
  /// Split pieces: squeezed for a beat, then out with an overshoot.
  private static let spawnAction = SKAction.sequence([
    .wait(forDuration: 0.03),
    .scale(to: 1.16, duration: 0.08),
    .scale(to: 0.96, duration: 0.05),
    .scale(to: 1, duration: 0.04),
  ])
  private static let bossSlamAction = SKAction.sequence([
    .scale(to: 0.84, duration: 0.17),
    .scale(to: 1.08, duration: 0.07),
    .scale(to: 1, duration: 0.08),
  ])
  private static let bossHitAction = SKAction.sequence([.scale(to: 0.9, duration: 0.03), .scale(to: 1.04, duration: 0.06), .scale(to: 1, duration: 0.05)])

  /// Every pop is layered: the bubble squashes and blows out, a white core flashes, the burst ring and the
  /// biome's sparks fly, and bigger bubbles add glitter and a tinted shockwave. All of it scales with size.
  private func popFX(at p: CGPoint, r: CGFloat, size: Int) {
    guard !reduceMotion else { return }
    let palette = (session?.arena ?? .classic).sparkColors
    ghost(at: p, r: r)
    let core = sprite(fxTextures["softDot"], size: CGSize(width: r * 1.3, height: r * 1.3), at: p, z: 6.5, add: true)
    play(core, Self.coreAction)
    let pop = sprite(fxTexture(.popBurst, size: 96), size: CGSize(width: r * 2.3, height: r * 2.3), at: p, z: 6)
    pop.zRotation = .random(in: 0...(2 * .pi))
    play(pop, Self.popAction)
    let counts = [30, 20, 13, 10]
    sparks(at: p, r: r, count: counts[max(0, min(3, size))], color: palette[size % palette.count])
    if size <= 1 { sparks(at: p, r: r, count: size == 0 ? 16 : 9, color: .white, fast: true) }
    if size <= 2 { shockwave(at: p, r: r * (size == 0 ? 2.1 : size == 1 ? 1.5 : 1.1), tint: palette[(size + 1) % palette.count]) } else { ripple(p) }
  }

  /// Bubbles that left the game this frame, found by id once per frame.
  private var liveIDs: Set<Int>?
  /// The node of a bubble that was just removed near `p`, still on screen until `drawBubbles` recycles it.
  private func goneNode(near p: CGPoint, r: CGFloat) -> BubbleNode? {
    guard let game = session?.game else { return nil }
    if liveIDs == nil { liveIDs = Set(game.bubbles.map(\.id)) }
    var best: (BubbleNode, CGFloat)?
    for (id, n) in bubbleNodes where !(liveIDs?.contains(id) ?? true) {
      let d = hypot(n.position.x - p.x, n.position.y - p.y)
      if d < r * 1.6, d < (best?.1 ?? .infinity) { best = (n, d) }
    }
    return best?.0
  }
  /// The live node nearest `p` (a boss or armour that was hit and stays).
  private func liveNode(near p: CGPoint, r: CGFloat) -> BubbleNode? {
    var best: (BubbleNode, CGFloat)?
    for n in bubbleNodes.values {
      let d = hypot(n.position.x - p.x, n.position.y - p.y)
      if d < r * 2, d < (best?.1 ?? .infinity) { best = (n, d) }
    }
    return best?.0
  }

  private func ghost(at p: CGPoint, r: CGFloat) {
    guard let n = goneNode(near: p, r: r), let t = n.sprite.texture else { return }
    n.isHidden = true
    let g = sprite(t, size: n.sprite.size, at: n.position, z: 5.5)
    g.zRotation = n.squash.zRotation
    play(g, Self.ghostAction)
  }

  /// A swipe leaves a ribbon of aurora light behind the finger. The colour drifts along the stroke.
  private func trail(from a: CGPoint, to b: CGPoint) {
    guard !reduceMotion else { return }
    let palette = (session?.trailArena ?? .classic).sparkColors
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
  private var perfWorks: [Double] = []
  private var demoSliceClock = 0.0
  /// CPU time spent in `update` (rules, effects and drawing setup), which the 60 Hz simulator cap can't hide.
  private func perfWork(_ seconds: Double) {
    guard Debug.has("-perf"), clock > 3, perfWorks.count < 900 else { laps = [0, 0, 0, 0, 0, 0]; return }
    perfWorks.append(seconds * 1000)
    // Keep the section times of the slowest frame, so a spike can be traced to rules, effects or drawing.
    if seconds * 1000 >= (perfWorks.max() ?? 0) { slowestLaps = laps }
    laps = [0, 0, 0, 0, 0, 0]
  }
  private var lapAt = 0.0
  private var laps = [Double](repeating: 0, count: 6)
  private var slowestLaps = [Double](repeating: 0, count: 6)
  private func lap(_ i: Int) {
    let now = CACurrentMediaTime()
    laps[i] += (now - lapAt) * 1000
    lapAt = now
  }
  private func perfSample(_ dt: Double) {
    guard Debug.has("-perf"), clock > 3 else { return }
    perfTimes.append(dt * 1000)
    guard perfTimes.count == 900 else { return }
    let sorted = perfTimes.sorted()
    let at = { (q: Double) in sorted[min(sorted.count - 1, Int(Double(sorted.count) * q))] }
    let long = perfTimes.filter { $0 > 25 }.count
    let work = perfWorks.sorted()
    let w = { (q: Double) in work.isEmpty ? 0 : work[min(work.count - 1, Int(Double(work.count) * q))] }
    Debug.ready(String(format: "perf frames=900 p50=%.1f p95=%.1f p99=%.1f max=%.1f over25ms=%d nodes=%d update_p50=%.2fms update_p95=%.2fms update_max=%.2fms slowest[tick,fx,sky..,bubbles,..,feel]=%@", at(0.5), at(0.95), at(0.99), sorted.last ?? 0, long, world.children.count, w(0.5), w(0.95), work.last ?? 0, slowestLaps.map { String(format: "%.2f", $0) }.joined(separator: ",")))
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

  private func shockwave(at p: CGPoint, r: CGFloat, tint: UIColor? = nil) {
    if reduceMotion { return }
    let n = sprite(fxTexture(.shockwave, size: 128), size: CGSize(width: r * 2, height: r * 2), at: p, z: 4, add: true)
    if let tint { n.color = tint; n.colorBlendFactor = 0.7 }
    play(n, Self.waveAction)
    ripple(p)
  }

  /// Numbers are built from pre-drawn glyphs. Changing a label's text re-renders it, which stutters at this rate.
  /// In solo play they pop up where the points were won, hang for a beat, then fly into the score.
  private func scoreText(_ value: Int, at p: CGPoint, color: UIColor = .white) {
    let unit = max(15, min(area.width, area.height) / 40)
    let grow = 1 + min(1.2, CGFloat(value) / 2500)
    let node = spareScores.popLast() ?? flights.first.map { f in flights.removeFirst(); f.node.removeFromParent(); return f.node } ?? ScoreNode()
    node.removeAllActions()
    node.show(value, glyphs: glyphs, height: unit * grow, color: color)
    node.position = p
    node.zPosition = 9
    node.alpha = 1
    node.setScale(1)
    // Two players: the points read the right way up for whoever won them, and rise away from the hinge.
    let turn = facing(at: p)
    node.zRotation = turn
    world.addChild(node)
    if session?.versus == true || reduceMotion {
      node.run(reduceMotion ? Self.scoreStill : Self.scoreRise(up(turn))) { [weak self, weak node] in
        guard let node else { return }
        node.removeFromParent()
        self?.spareScores.append(node)
      }
      return
    }
    node.setScale(0.5)
    flights.append(Flight(node: node, start: p))
  }
  private static var rises: [Int: SKAction] = [:]
  /// Floats a score 34 points "up" for its reader (one cached action per direction).
  private static func scoreRise(_ up: CGVector) -> SKAction {
    let key = Int((atan2(up.dy, up.dx) * 100).rounded())
    if let a = rises[key] { return a }
    let a = SKAction.group([.moveBy(x: up.dx * 34, y: up.dy * 34, duration: 0.8), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])])
    rises[key] = a
    return a
  }
  private static let scoreStill = SKAction.sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])

  /// Where the HUD's score sits, in world coordinates.
  /// Just inside the HUD's bottom edge under the score, so the number slides up under the panel as it lands.
  private func scoreTarget(_ game: Game) -> CGPoint { CGPoint(x: area.width - 48, y: y(game.top) + 10) }

  private func drawFlights(_ game: Game) {
    guard !flights.isEmpty else { return }
    let target = scoreTarget(game)
    var i = 0
    while i < flights.count {
      flights[i].age += visualDt
      let f = flights[i], n = f.node, t = f.age
      if t < 0.16 {
        // Pop in with an overshoot and rise.
        let k = t / 0.16
        n.setScale(CGFloat(0.5 + 0.75 * sin(k * .pi * 0.75)))
        n.position = CGPoint(x: f.start.x, y: f.start.y + CGFloat(1 - pow(1 - k, 3)) * 24)
      } else if t < 0.5 {
        n.setScale(1)
        n.position = CGPoint(x: f.start.x, y: f.start.y + 24 + CGFloat(t - 0.16) * 12)
      } else if t < 0.86 {
        // Then accelerate into the score and shrink as it lands.
        let k = (t - 0.5) / 0.36, e = CGFloat(k * k * k)
        let from = CGPoint(x: f.start.x, y: f.start.y + 28)
        n.position = CGPoint(x: from.x + (target.x - from.x) * e, y: from.y + (target.y - from.y) * e + CGFloat(sin(k * .pi)) * 30)
        n.setScale(1 - 0.55 * e)
        n.alpha = 1 - 0.3 * e
      } else {
        feel.scoreLanded(at: CGPoint(x: target.x, y: target.y))
        n.removeFromParent()
        spareScores.append(n)
        flights.remove(at: i)
        continue
      }
      i += 1
    }
  }

  // MARK: Feel, every frame

  private func drawFeel(_ game: Game, session: Session, dt: Double) {
    drawFlights(game)
    let solo = !game.versus && game.mode != .sandbox
    let p0 = game.players[0]
    // The last shield: a heartbeat in the vignette (and the hands), faster when one crossing would end it.
    feel.danger = solo && game.status == .playing && !session.isHeld && p0.shields == 1 ? (p0.meter >= game.meterMax - 1 ? 1 : 0.5) : 0
    // A boss winding up rims the screen in red; overtime keeps a low amber glow at the edges.
    let winding = game.bubbles.contains { $0.bossWindup > 0 }
    if winding { feel.warnColor = UIColor(red: 1, green: 0.22, blue: 0.28, alpha: 1); feel.warnHold = 0.55 }
    else if overtime > 0 { feel.warnColor = UIColor(red: 1, green: 0.62, blue: 0.2, alpha: 1); feel.warnHold = min(0.5, 0.14 + Double(overtime) * 0.07) }
    else { feel.warnHold = 0 }
    // Fever from the rules: full while it runs, fading over its last moment.
    let feverLeft = game.players.map(\.fever).max() ?? 0
    var ruled = true
    #if DEBUG
    ruled = Debug.string("-fx") != "fever"
    #endif
    if ruled { feverDrive(feverLeft > 0 ? min(1, feverLeft / 0.6) : 0) }
    feel.fever = feverNow
    drawLastOne(game, session: session)
    let combo: (Double, Double, Double)? = solo && session.overlay != .tour ? (p0.combo, p0.comboT, game.tuning.comboWindow) : nil
    feel.update(dt: dt, area: area, scene: size, origin: worldOrigin, combo: combo, top: CGFloat(game.top))
  }

  /// The level's final bubble wears a gold ring, so the finish is a moment you see coming.
  private func drawLastOne(_ game: Game, session: Session) {
    let finite: Bool
    switch game.mode { case .campaign, .daily: finite = true; default: finite = false }
    guard finite, game.status == .playing, game.bubbles.count == 1, game.bubblesToCome == 0,
          let b = game.bubbles.first, b.kind != .boss, b.size == 3, let node = bubbleNodes[b.id] else {
      feel.spotlight.isHidden = true
      return
    }
    if feel.spotlight.parent == nil { world.addChild(feel.spotlight) }
    feel.spotlight.isHidden = false
    let beat = reduceMotion ? 0.5 : 0.5 + 0.5 * sin(clock * 9)
    let d = CGFloat(b.r) * (2.9 + 0.35 * CGFloat(beat))
    feel.spotlight.size = CGSize(width: d, height: d)
    feel.spotlight.position = node.position
    feel.spotlight.alpha = CGFloat(0.55 + 0.35 * beat)
    if lastOneFor != ObjectIdentifier(game) {
      lastOneFor = ObjectIdentifier(game)
      feel.callout(.lastOne, at: CGPoint(x: node.position.x, y: node.position.y + CGFloat(b.r) + 40), color: UIColor(red: 1, green: 0.88, blue: 0.4, alpha: 1), size: 0.8)
      Haptics.shared.play(.lastOne)
      #if DEBUG
      freeze("lastone", after: 0.2)
      #endif
      Sound.shared.blip(1320, 0.1, .sine, gain: 0.1)
    }
  }

  /// A boss arrives with a slam: it drops in big, lands with a shockwave and shake, and its name crosses the
  /// screen. Waits until any card is closed, and plays once per level.
  private func bossIntro(_ game: Game, nodes: [BubbleNode]) {
    guard let session, !nodes.isEmpty, bossIntroFor != ObjectIdentifier(game), !session.isHeld, session.overlay != .tour else { return }
    bossIntroFor = ObjectIdentifier(game)
    feel.banner(game.spec.boss)
    Haptics.shared.play(.bossIntro)
    #if DEBUG
    freeze("boss", after: 0.45)
    #endif
    Sound.shared.blip(90, 0.3, .saw, gain: 0.1, fall: -0.6)
    guard !reduceMotion else { return }
    for n in nodes {
      n.removeAllActions()
      n.setScale(2.3)
      n.run(Self.bossSlamAction)
    }
    feel.after(0.17) { [weak self] in
      guard let self else { return }
      for n in nodes where n.parent != nil {
        self.shockwave(at: n.position, r: n.drawSize * 1.1, tint: UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1))
        self.sparks(at: n.position, r: n.drawSize * 0.5, count: 30)
      }
      self.feel.shake(0.85)
      self.feel.flash(0.25, UIColor(red: 1, green: 0.5, blue: 0.5, alpha: 1))
      self.feel.hitStop(0.07, force: true)
      self.pulse = 1.4
      Haptics.shared.play(.bossSlam)
      Sound.shared.thump(50, gain: 0.28)
    }
  }

  /// The finale: time nearly stops, the boss blows apart in rings, and the sky lights up.
  private func bossDown(at p: CGPoint, r: CGFloat, game: Game) {
    guard bossDownFor != ObjectIdentifier(game) else { return }
    bossDownFor = ObjectIdentifier(game)
    bossDownAt = clock
    let palette = (session?.arena ?? .classic).sparkColors
    feel.hitStop(0.13, force: true)
    feel.slowMo(0.2, for: 1.4)
    feel.flash(0.85)
    feel.shake(1)
    feel.punch(0.07, at: p)
    bloom = 1.6
    popFX(at: p, r: r, size: 0)
    for (i, c) in palette.prefix(3).enumerated() { sparks(at: p, r: r * CGFloat(1 + i), count: 40, color: c) }
    sparks(at: p, r: r * 1.4, count: 40, color: .white, fast: true)
    for (k, delay) in [0.0, 0.12, 0.26].enumerated() {
      feel.after(delay) { [weak self] in
        self?.shockwave(at: p, r: r * CGFloat(2 + k * 2), tint: palette[k % palette.count])
      }
    }
    feel.callout(.bossDown, at: CGPoint(x: area.width / 2, y: area.height * 0.58), color: UIColor(red: 1, green: 0.84, blue: 0.36, alpha: 1), size: 1.2)
    Haptics.shared.play(.bossDown)
    #if DEBUG
    freeze("bossdown", after: 0.35)
    #endif
    let sound = Sound.shared
    sound.crack(big: true); sound.thump(45, gain: 0.3); sound.sting([0, 4, 7, 12, 16], root: 392, gap: 0.08)
  }

  /// Snap the Hinge: a whip crack. The line kinks from where it was pulled, red, green and blue copies tear
  /// off it, the screen flashes and jolts away from the line, and time catches for a beat.
  private func snapFX(along: Double, flung: Int, clap: Bool, player: Int = 0) {
    guard let game = session?.game else { return }
    let length = game.vertical ? area.height - CGFloat(game.top) + worldOrigin.y : size.width
    let lineAt = game.vertical ? CGFloat(game.hinge) : y(game.hinge)
    feel.chroma(vertical: game.vertical, at: lineAt, length: max(length, game.vertical ? size.height : size.width), strength: clap ? 1.4 : 1)
    if !clap {
      snapAge = 0
      snapAt = game.vertical ? Float((y(along) + worldOrigin.y) / max(1, length)) : Float(1 - (CGFloat(along) + worldOrigin.x) / max(1, length))
    } else {
      snapAge = 0; snapAt = 0.5
    }
    feel.flash(clap ? 0.5 : 0.32, UIColor(red: 0.75, green: 0.95, blue: 1, alpha: 1))
    feel.shake(clap ? 0.75 : 0.45)
    let push: CGFloat = clap ? 14 : 9
    feel.shove(game.vertical ? CGVector(dx: push * (Bool.random() ? 1 : -1), dy: 0) : CGVector(dx: 0, dy: push * (Bool.random() ? 1 : -1)))
    feel.hitStop(clap ? 0.08 : 0.05, force: true)
    if flung >= 2 || clap {
      if game.versus {
        // The snapper's word, on their own half and facing them.
        let turn = facing(player: player), lift = up(turn)
        let base = game.vertical ? CGPoint(x: lineAt, y: y(along)) : CGPoint(x: CGFloat(along), y: lineAt)
        feel.callout(.snap, at: CGPoint(x: base.x + lift.dx * 64, y: base.y + lift.dy * 64), color: UIColor(red: 0.55, green: 0.95, blue: 1, alpha: 1), size: 0.85, facing: turn)
      } else {
        let at = game.vertical ? CGPoint(x: lineAt + 70, y: area.height * 0.62) : CGPoint(x: game.vertical ? 0 : CGFloat(along), y: lineAt + 64)
        feel.callout(clap ? .clap : .snap, at: at, color: UIColor(red: 0.55, green: 0.95, blue: 1, alpha: 1), size: clap ? 1 : 0.85)
      }
    }
    Haptics.shared.play(clap ? .clap : .snap)
    #if DEBUG
    freeze(clap ? "clap" : "snap", after: 0.09)
    #endif
    Sound.shared.crack(big: clap)
  }

  /// A rising combo: a callout at each threshold, with its own colour, a chime and a tap.
  private func comboCheck(at p: CGPoint) {
    guard let game = session?.game else { return }
    for i in game.players.indices where i < comboTiers.count {
      let tier = ComboTier.tier(game.players[i].combo)
      if tier > comboTiers[i] {
        let step = ComboTier.steps[tier - 1]
        // Two players: the word faces the player who earned it, above the pop as they see it.
        let turn = facing(player: i), lift = up(turn)
        feel.callout(step.word, at: CGPoint(x: p.x + lift.dx * 70, y: p.y + lift.dy * 70), color: step.color, size: 0.8 + CGFloat(tier) * 0.06, facing: turn)
        feel.flash(0.05 + Double(tier) * 0.015, step.color)
        bloom = max(bloom, 0.3 + Double(tier) * 0.1)
        Haptics.shared.play(tier == ComboTier.steps.count ? .comboTop : .combo)
        #if DEBUG
        freeze("combo\(tier)", after: 0.16)
        freeze("combo", after: 0.16)
        #endif
        Sound.shared.sting(tier >= 5 ? [0, 4, 7, 12] : [0, 7, 12], root: 523 * Sound.ladder(game.players[i].combo) / 2)
      }
      comboTiers[i] = tier
    }
  }

  /// The red half of the screen that belongs to one player in versus; nil means the whole screen.
  private func half(_ player: Int) -> vector_float4? {
    guard let game = session?.game, game.versus, size.width > 1 else { return nil }
    let line = game.vertical ? Float((CGFloat(game.hinge) + worldOrigin.x) / size.width) : Float(1 - (y(game.hinge) + worldOrigin.y) / size.height)
    return vector_float4(game.vertical ? 1 : 0, line, player == 0 ? -1 : 1, 1)
  }

  private var maxCombo: Double { session?.game?.players.map(\.combo).max() ?? 1 }

  // MARK: Hooks for the rules agent's overtime and fever

  /// Overtime: the level dragged on and bubbles just sped up a step. Amber edges, a callout and a two-note horn.
  func overtimeStep(_ step: Int) {
    overtime = max(overtime, step)
    let amber = UIColor(red: 1, green: 0.62, blue: 0.2, alpha: 1)
    feel.warnPulse(0.75, color: amber)
    feel.callout(step <= 1 ? .overtime : .faster, at: CGPoint(x: area.width / 2, y: area.height * 0.6), color: amber, size: step <= 1 ? 1 : 0.85)
    feel.shake(0.25)
    pulse = max(pulse, 1)
    Haptics.shared.play(.overtime)
    #if DEBUG
    freeze("overtime", after: 0.25)
    #endif
    Sound.shared.blip(330 + Double(step) * 40, 0.16, .square, gain: 0.08); Sound.shared.blip(495 + Double(step) * 60, 0.22, .square, gain: 0.08)
  }

  /// Fever starts: a rainbow flash, the sky lights up and the edges start cycling colour (see `feverDrive`).
  func feverBegan(player: Int = 0) {
    feverNow = max(feverNow, 1)
    let gold = UIColor(red: 1, green: 0.82, blue: 0.3, alpha: 1)
    feel.flash(0.55, gold)
    if let game = session?.game, game.versus {
      feel.callout(.fever, at: halfMiddle(player, game), color: gold, size: 1.1, facing: facing(player: player))
    } else {
      feel.callout(.fever, at: CGPoint(x: area.width / 2, y: area.height * 0.6), color: gold, size: 1.25)
    }
    feel.shake(0.4)
    bloom = 1.6
    ripple(CGPoint(x: area.width / 2, y: area.height / 2))
    Haptics.shared.play(.fever)
    #if DEBUG
    freeze("fever", after: 1.2)
    #endif
    Sound.shared.sting([0, 4, 7, 12, 16, 19], root: 523, gap: 0.05)
  }

  /// Fever's over: the colour drains away.
  func feverEnded() {
    feverNow = 0
    Sound.shared.blip(660, 0.2, .sine, gain: 0.08, fall: 0.6)
  }

  /// Per frame while fever runs: 0...1, how hot it is. Brightens the sky and cycles the screen edges.
  func feverDrive(_ value: Double) { feverNow = max(0, min(1, value)) }

  // MARK: Events

  private func effect(_ e: GameEvent) {
    if twists.effect(e, game: session?.game) { return }
    let sound = Sound.shared, haptic = Haptics.shared
    switch e {
    case let .split(x, gy, r, size, points, kind):
      let p = CGPoint(x: x, y: y(gy))
      recentSplits.append((p, CGFloat(r)))
      popFX(at: p, r: CGFloat(r), size: size)
      scoreText(points, at: p, color: kind == .golden ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1) : .white)
      sound.pop(size: size, combo: maxCombo)
      haptic.play(size == 0 ? .bigSplit : .split)
      // Big splits land with a freeze-frame and a knock; medium ones just a nudge.
      if size == 0 { feel.hitStop(0.045); feel.shake(0.3) } else if size == 1 { feel.shake(0.12) }
      #if DEBUG
      freeze("pop", after: 0.06)
      #endif
      lastPopPoint = p
      comboCheck(at: p)
    case let .pop(x, gy, r, size, points, kind):
      let p = CGPoint(x: x, y: y(gy))
      popFX(at: p, r: CGFloat(r) * 1.2, size: size)
      scoreText(points, at: p, color: kind == .golden ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1) : .white)
      sound.pop(size: size, combo: maxCombo)
      haptic.play(.pop)
      lastPopPoint = p
      comboCheck(at: p)
    case let .zap(x, gy, r, points):
      let p = CGPoint(x: x, y: y(gy))
      ghost(at: p, r: CGFloat(r))
      shockwave(at: p, r: CGFloat(r) * 1.6, tint: UIColor(red: 0.5, green: 0.9, blue: 1, alpha: 1))
      sparks(at: p, r: CGFloat(r), count: 10, color: UIColor(red: 0.5, green: 0.9, blue: 1, alpha: 1), fast: true)
      scoreText(points, at: p, color: UIColor(red: 0.5, green: 0.9, blue: 1, alpha: 1))
      sound.blip(1200, 0.1, .sine, gain: 0.16)
      haptic.play(.chain)
      lastPopPoint = p
    case let .chainPop(x, gy, r, points, count):
      let link = CGPoint(x: x, y: y(gy))
      if let last = lastChain, clock - lastChainClock < 0.05 { arc(from: last, to: link) }
      lastChain = link; lastChainClock = clock
      popFX(at: link, r: CGFloat(r) * 1.3, size: 3)
      scoreText(points, at: link, color: UIColor(red: 0.55, green: 1, blue: 0.75, alpha: 1))
      sound.blip((880 * Sound.ladder(1 + Double(min(count, 12)) * 0.5)).rounded(), 0.08)
      haptic.play(.chain)
      if count >= 5 { feel.shake(0.2) }
      lastPopPoint = link
      comboCheck(at: link)
    case let .crossed(x, gy, r, _, player):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r), tint: UIColor(red: 1, green: 0.4, blue: 0.45, alpha: 1))
      pulse = 1
      feel.shake(0.28)
      feel.vignette(0.3, mask: half(player))
      sound.blip(150, 0.17, .saw, gain: 0.16); sound.thump(110, gain: 0.12)
      haptic.play(.crossing)
    case let .gatePass(x, gy, r):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r) * 0.7, tint: UIColor(red: 0.3, green: 1, blue: 0.62, alpha: 1))
      sound.blip(760, 0.09, .sine, gain: 0.14)
    case let .armorCrack(x, gy, r, points):
      let p = CGPoint(x: x, y: y(gy))
      burst(at: p, r: CGFloat(r) * 0.6, particles: 6)
      sparks(at: p, r: CGFloat(r) * 0.7, count: 12, color: UIColor(white: 0.85, alpha: 1), fast: true)
      liveNode(near: p, r: CGFloat(r))?.flash = 1
      scoreText(points, at: p)
      feel.shake(0.18)
      sound.blip(280, 0.12, .square, gain: 0.12); sound.blip(3000, 0.03, .noise, gain: 0.1, fall: 0)
      haptic.play(.bigSplit)
      comboCheck(at: p)
    case let .bossHit(x, gy, r, points, _):
      let p = CGPoint(x: x, y: y(gy))
      if let n = liveNode(near: p, r: CGFloat(r)) { n.flash = 1; if !reduceMotion { n.run(Self.bossHitAction) } }
      burst(at: p, r: CGFloat(r) * 0.5, particles: 5)
      sparks(at: p, r: CGFloat(r) * 0.6, count: 14, color: .white, fast: true)
      scoreText(points, at: CGPoint(x: x, y: y(gy) + CGFloat(r) * 0.5))
      feel.hitStop(0.05, force: true)
      feel.shake(0.32)
      sound.blip(240, 0.11, .square, gain: 0.14); sound.thump(160, gain: 0.14)
      haptic.play(.bossHit)
      #if DEBUG
      freeze("bosshit", after: 0.07)
      #endif
    case let .bossPhase(x, gy, r, phase):
      let p = CGPoint(x: x, y: y(gy))
      guard let game = session?.game else { break }
      if phase >= max(1, game.spec.bossPhases) { bossDown(at: p, r: CGFloat(r), game: game); break }
      // A new phase: a double shockwave, a flash, a freeze, and the phase called out.
      shockwave(at: p, r: CGFloat(r) * 2.2, tint: UIColor(red: 1, green: 0.45, blue: 0.4, alpha: 1))
      feel.after(0.1) { [weak self] in self?.shockwave(at: p, r: CGFloat(r) * 3.4, tint: nil) }
      sparks(at: p, r: CGFloat(r), count: 36)
      feel.flash(0.45)
      feel.shake(0.85)
      feel.hitStop(0.1, force: true)
      feel.punch(0.035, at: p)
      bloom = max(bloom, 0.8)
      let next = phase + 1, total = max(1, game.spec.bossPhases)
      let word: Callout = next >= total ? .finalPhase : next == 2 ? .phase2 : next == 3 ? .phase3 : .phase4
      feel.callout(word, at: CGPoint(x: area.width / 2, y: area.height * 0.6), color: UIColor(red: 1, green: 0.5, blue: 0.45, alpha: 1))
      sound.blip(110, 0.35, .saw, gain: 0.2); sound.thump(55, gain: 0.26)
      haptic.play(.bossPhase)
      #if DEBUG
      freeze("phase", after: 0.14)
      #endif
    case let .bossSlam(x, gy, r, player):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r), tint: UIColor(red: 1, green: 0.35, blue: 0.35, alpha: 1))
      pulse = 1.4
      feel.shake(0.6)
      feel.vignette(0.4, mask: half(player))
      sound.blip(90, 0.25, .square, gain: 0.18); sound.thump(60)
      haptic.play(.bossSlam)
    case let .hingeSnap(along, snapper, flung):
      snapFlare = 1
      pulse = 1.6
      if let game = session?.game {
        let spots = stride(from: 0.1, through: 0.9, by: 0.2)
        for u in spots {
          let at = game.vertical ? CGPoint(x: CGFloat(game.hinge), y: area.height * CGFloat(u)) : CGPoint(x: area.width * CGFloat(u), y: y(game.hinge))
          sparks(at: at, r: 46, count: 18)
        }
        ripple(game.vertical ? CGPoint(x: CGFloat(game.hinge), y: y(along)) : CGPoint(x: CGFloat(along), y: y(game.hinge)))
      }
      snapFX(along: along, flung: flung, clap: false, player: snapper)
    case .snapReady:
      sound.blip(880, 0.08, .sine, gain: 0.08)
    case let .rushStart(side):
      rushFlash = 1
      if let game = session?.game {
        let across = (Double(side) < 0 ? game.hinge / 2 : game.hinge + ((game.vertical ? game.w : game.h) - game.hinge) / 2)
        ripple(game.vertical ? CGPoint(x: across, y: y((game.top + game.h) / 2)) : CGPoint(x: game.w / 2, y: y(across)))
      }
      sound.blip(520, 0.12, .triangle, gain: 0.12); sound.blip(780, 0.2, .triangle, gain: 0.1)
      haptic.play(.power)
    case let .secretBubble(_, x, gy):
      let at = CGPoint(x: x, y: y(gy))
      sparks(at: at, r: 40, count: 26)
      shockwave(at: at, r: 70)
      bloom = max(bloom, 0.7)
      sound.blip(1046, 0.08, .sine, gain: 0.1); sound.blip(1568, 0.16, .sine, gain: 0.1)
      haptic.good()
    case .rushOver:
      sound.blip(330, 0.14, .sine, gain: 0.06)
    case let .crossfold(x, gy, combo):
      if let game = session?.game {
        let at = game.vertical ? CGPoint(x: CGFloat(game.hinge), y: y(gy)) : CGPoint(x: x, y: y(game.hinge))
        sparks(at: at, r: 30, count: 14)
        comboCheck(at: at)
      }
      bloom = max(bloom, 0.35)
      sound.blip(600 + min(8, combo) * 60, 0.08, .sine, gain: 0.1)
    case let .creaseClap(flung):
      snapFlare = 1.4
      pulse = 1.8
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
      snapFX(along: 0, flung: flung, clap: true)
      sound.blip(1200 + Double(min(flung, 6)) * 80, 0.16, .square, gain: 0.08)
    case let .bossWindup(x, gy, r):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: CGFloat(r), tint: UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1))
      feel.warnPulse(0.9, color: UIColor(red: 1, green: 0.22, blue: 0.28, alpha: 1))
      sound.blip(140, 0.5, .saw, gain: 0.14, fall: -0.5)
      haptic.play(.windup)
    case let .bossStagger(x, gy, r, points):
      let p = CGPoint(x: x, y: y(gy))
      liveNode(near: p, r: CGFloat(r))?.flash = 1.4
      burst(at: p, r: CGFloat(r), particles: 10)
      shockwave(at: p, r: CGFloat(r) * 1.6, tint: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1))
      scoreText(points, at: CGPoint(x: x, y: y(gy) + CGFloat(r) * 0.5), color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1))
      feel.callout(.stagger, at: CGPoint(x: p.x, y: p.y + CGFloat(r) + 30), color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 0.9)
      feel.flash(0.3, UIColor(red: 1, green: 0.9, blue: 0.6, alpha: 1))
      feel.hitStop(0.08, force: true)
      feel.shake(0.55)
      feel.punch(0.03, at: p)
      bloom = 0.6
      sound.blip(520, 0.14, .square, gain: 0.16); sound.blip(780, 0.2); sound.crack()
      haptic.play(.bossStagger)
      #if DEBUG
      freeze("stagger", after: 0.1)
      #endif
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
      feel.flash(0.15, UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1))
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
    case let .shieldLost(player):
      // The one hit you must not miss: a red pulse from the edges, a freeze, a hard shake and a heavy thud.
      feel.vignette(1, mask: half(player))
      feel.flash(0.22, UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1))
      feel.shake(0.95)
      feel.hitStop(0.12, force: true)
      pulse = 1.6
      if let game = session?.game, game.players.indices.contains(player), game.players[player].shields > 0 {
        let red = UIColor(red: 1, green: 0.38, blue: 0.42, alpha: 1)
        if game.versus {
          // In the middle of the loser's half, facing them.
          feel.callout(.shieldDown, at: halfMiddle(player, game), color: red, size: 0.9, facing: facing(player: player))
        } else {
          feel.callout(.shieldDown, at: CGPoint(x: area.width / 2, y: area.height * 0.62), color: red, size: 0.9)
        }
      }
      sound.blip(80, 0.4, .square, gain: 0.2); sound.thump(48, gain: 0.3)
      haptic.play(.shieldLost)
      #if DEBUG
      freeze("shield", after: 0.12)
      #endif
    case .recharge, .cooled:
      feel.flash(0.14, UIColor(red: 0.4, green: 0.9, blue: 1, alpha: 1))
      sound.blip(520, 0.12); sound.blip(990, 0.26, .triangle, gain: 0.16)
      haptic.play(.power)
    case let .collected(kind, x, gy, _):
      shockwave(at: CGPoint(x: x, y: y(gy)), r: kind == .chainBurst ? 120 : 44)
      if kind == .chainBurst { feel.shake(0.7); feel.hitStop(0.06) }
      feel.flash(0.12, UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1))
      sound.blip(660, 0.1); sound.blip(1100, 0.18, .sine, gain: 0.15)
      haptic.play(.power)
    case .dropped: sound.blip(1320, 0.08, .sine, gain: 0.12)
    case .wave: sound.blip(330, 0.2, .triangle, gain: 0.14)
    case .finished:
      finale()
    // The rules' pressure events: overtime, fever, champions, surges, and a last-phase boss shedding.
    case let .overtime(step): overtimeStep(step)
    case let .feverStart(player): feverBegan(player: player)
    case .feverEnd: feverEnded()
    case let .championCrack(x, gy, r, points, armorLeft):
      let p = CGPoint(x: x, y: y(gy))
      let gold = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
      liveNode(near: p, r: CGFloat(r))?.flash = 1
      burst(at: p, r: CGFloat(r) * 0.7, particles: 6)
      sparks(at: p, r: CGFloat(r) * 0.8, count: 18, color: gold, fast: true)
      shockwave(at: p, r: CGFloat(r) * 1.4, tint: gold)
      scoreText(points, at: p, color: gold)
      feel.shake(armorLeft == 0 ? 0.35 : 0.2)
      if armorLeft == 0 { feel.hitStop(0.05) }
      sound.blip(320 + Double(armorLeft) * 60, 0.12, .square, gain: 0.12); sound.blip(3200, 0.03, .noise, gain: 0.1, fall: 0)
      haptic.play(.bigSplit)
      comboCheck(at: p)
    case .surgeWarning:
      feel.warnPulse(0.9, color: UIColor(red: 1, green: 0.5, blue: 0.3, alpha: 1))
      feel.callout(.surge, at: CGPoint(x: area.width / 2, y: area.height * 0.62), color: UIColor(red: 1, green: 0.6, blue: 0.35, alpha: 1), size: 0.85)
      sound.blip(220, 0.4, .saw, gain: 0.1, fall: -0.6)
      haptic.play(.windup)
    case .surge:
      feel.shake(0.4)
      feel.flash(0.18, UIColor(red: 1, green: 0.6, blue: 0.4, alpha: 1))
      ripple(CGPoint(x: area.width / 2, y: area.height / 2))
      sound.thump(70, gain: 0.2)
      haptic.play(.bossSlam)
    case let .bossShed(x, gy, r):
      let p = CGPoint(x: x, y: y(gy))
      sparks(at: p, r: CGFloat(r) * 0.6, count: 20)
      shockwave(at: p, r: CGFloat(r) * 0.9, tint: UIColor(red: 1, green: 0.45, blue: 0.4, alpha: 1))
      sound.blip(300, 0.12, .saw, gain: 0.1)
    default: break
    }
  }

  /// The level's over. A win slows time on the last pop, zooms in on it, then fires confetti and lights the sky.
  private func finale() {
    guard let session, let game = session.game else { return }
    if game.status == .won || session.versus {
      feel.slowMo(0.22, for: 1.1)
      feel.hitStop(0.06, force: true)
      feel.punch(0.07, at: lastPopPoint)
      feel.flash(0.45)
      if session.versus {
        // Each player gets their own verdict, facing them.
        let gold = UIColor(red: 1, green: 0.86, blue: 0.4, alpha: 1)
        for i in game.players.indices {
          let won = game.winner == i
          feel.callout(game.winner == nil ? .draw : won ? .youWin : .soClose, at: halfMiddle(i, game), color: won || game.winner == nil ? gold : UIColor(red: 0.75, green: 0.8, blue: 1, alpha: 1), size: 0.95, facing: facing(player: i))
        }
      } else if clock - bossDownAt > 1.5 {
        feel.callout(game.cleanBonus ? .flawless : .clear, at: CGPoint(x: area.width / 2, y: area.height * 0.58),
                     color: game.cleanBonus ? UIColor(red: 0.6, green: 1, blue: 0.85, alpha: 1) : UIColor(red: 1, green: 0.86, blue: 0.4, alpha: 1), size: 1.2)
      }
      Haptics.shared.play(.win)
      #if DEBUG
      freeze("win", after: 0.7)
      #endif
      Sound.shared.sting([0, 4, 7, 12, 16], root: 523, gap: 0.07)
      feel.after(0.22) { [weak self] in
        guard let self else { return }
        self.bloom = 1.6
        for p in [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.2, y: 0.3), CGPoint(x: 0.8, y: 0.7), CGPoint(x: 0.5, y: 0.15)] {
          self.ripple(CGPoint(x: self.area.width * p.x, y: self.area.height * p.y))
        }
        self.feel.confetti()
      }
    } else {
      feel.vignette(1)
      feel.flash(0.25, UIColor(red: 1, green: 0.2, blue: 0.3, alpha: 1))
      feel.slowMo(0.35, for: 0.8)
      feel.shake(0.6)
      Haptics.shared.play(.lose)
      Sound.shared.blip(70, 0.6, .saw)
    }
  }

  #if DEBUG
  /// `-freezeOn tag [-freezeAfter s]`: pauses the scene a moment after that effect fires, so a slow simulator
  /// can screenshot a moment that lasts a fraction of a second. Writes "frozen" to the ready file.
  private var frozen = false
  private func freeze(_ tag: String, after: Double = 0.1) {
    guard !frozen, Debug.string("-freezeOn") == tag else { return }
    frozen = true
    let wait = Debug.string("-freezeAfter").flatMap(Double.init) ?? after
    feel.after(wait) { [weak self] in
      self?.isPaused = true
      Debug.ready("frozen")
    }
  }
  /// `-fx boss|shield|fever|overtime`: plays a moment over and over for captures. `boss` hits the real boss.
  private var fxClock = 0.0
  private var fxStep = 0
  private func demoFX(_ game: Game) {
    guard let kind = Debug.string("-fx"), game.status == .playing, session?.isHeld == false else { return }
    fxClock += visualDt
    switch kind {
    case "boss":
      guard fxClock > 0.9, let b = game.bubbles.first(where: { $0.kind == .boss }), b.bossGuard <= 0 else { return }
      fxClock = 0
      game.tap(b)
    case "shield":
      guard fxClock > 2.6 else { return }
      fxClock = 0
      effect(.shieldLost(player: 0))
    case "fever":
      if fxClock > 0.8 && feverNow == 0 { feverBegan() }
      if feverNow > 0 { feverDrive(max(0.001, 1 - (fxClock - 0.8) / 5)) }
      if fxClock > 6 { feverEnded(); fxClock = 0 }
    case "overtime":
      guard fxClock > 3 else { return }
      fxClock = 0; fxStep += 1
      overtimeStep(fxStep)
    default: break
    }
  }
  #endif

  // MARK: Touch

  private var inputOn: Bool {
    guard let session else { return false }
    if session.overlay == .tour { return session.tourInput }
    return session.overlay == .none && session.tip == nil
  }

  private func gamePoint(_ touch: UITouch, in view: UIView) -> CGPoint {
    let p = touch.location(in: view)
    return CGPoint(x: p.x - insets.left - play.minX, y: p.y - insets.top - play.minY)
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
      // An empty tap on the world's hidden spot counts toward its Easter egg (and still plays normally).
      if b == nil, session.overlay != .tour, !game.onHinge(x: p.x, y: p.y) { _ = tapSpot(touch.location(in: view), game: game) }
      // One finger on each page beside the fold, together, claps the crease.
      if b == nil, session.overlay != .tour, let side = game.besideCrease(x: p.x, y: p.y) {
        if let last = creaseTouch, last.side != side, clock - last.at <= game.tuning.clapWindow, game.clap() {
          creaseTouch = nil
          continue
        }
        creaseTouch = (side, clock)
      }
      if !game.flick && session.overlay != .tour {
        if let b { game.tap(b, atX: p.x, atY: p.y) }
        game.illuminate(x: p.x, y: p.y)
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
        // In the dark a finger carries its own light, just behind the stroke.
        game.illuminate(x: p.x, y: p.y)
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
      if !stroke.slicing, let b = stroke.bubble { game.tap(b, atX: stroke.start.x, atY: stroke.start.y) }
      // A touch in the dark leaves a pool of light behind it.
      game.illuminate(x: stroke.last.x, y: stroke.last.y)
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches { active[ObjectIdentifier(touch)] = nil }
  }
}

final class BubbleNode: SKNode {
  let squash = SKNode()
  let sprite = SKSpriteNode()
  /// The same art added on top, shown only while a hit flashes it white.
  let glare = SKSpriteNode()
  var kind: BubbleKind?
  var drawSize: CGFloat = 0
  var flash = 0.0
  /// A split piece starts at its parent's centre and springs out by this much as `birthT` runs 0...1.
  var birth = CGVector.zero
  var birthT = 1.0
  /// Two players: the way the face turns, toward whoever's half it's on. A crossing spins it round to face the
  /// other player (`flipT` runs 0...1 from `faceFrom` to `faceTo`).
  var face: CGFloat = 0
  var faceFrom: CGFloat = 0
  var faceTo: CGFloat = 0
  var flipT = 1.0
  override init() {
    super.init()
    addChild(squash)
    squash.addChild(sprite)
    glare.blendMode = .add
    glare.isHidden = true
    squash.addChild(glare)
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
    for ch in "+,.x0123456789" {
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
  /// The glyphs it draws with, kept from the last `show` so the combo counter can just pass text.
  private static var shared: ScoreGlyphs?
  /// Makes the glyph sprites ahead of time, so showing a number never makes a node.
  func reserve(_ n: Int) {
    while parts.count < n {
      let s = SKSpriteNode()
      s.colorBlendFactor = 1
      s.isHidden = true
      parts.append(s)
      addChild(s)
    }
  }
  func show(_ value: Int, glyphs: ScoreGlyphs, height: CGFloat, color: UIColor) {
    Self.shared = glyphs
    showText("+\(value.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US"))))", glyphs: glyphs, height: height, color: color)
  }
  func showText(_ text: String, height: CGFloat, color: UIColor) {
    guard let g = Self.shared else { return }
    showText(text, glyphs: g, height: height, color: color)
  }
  func showText(_ text: String, glyphs: ScoreGlyphs, height: CGFloat, color: UIColor) {
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
