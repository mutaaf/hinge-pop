import CoreGraphics
import Foundation

/// Paints a biome. The first seven are the original worlds, re-lit for variants 1-3 by `relight`; the nine
/// new biomes paint each variant natively (Biomes.swift). Every arena then gets the same finish: a calm
/// central haze so the play band stays quiet, edge darkening, and a fine dither so nothing bands.
func drawArena(_ k: ArenaKind, _ v: Int, _ c: CGContext, size: CGSize) {
    switch k {
    case .classic: drawClassic(c, size)
    case .neon: drawNeon(c, size)
    case .forest: drawForest(c, size)
    case .space: drawSpace(c, size)
    case .frost: drawFrost(c, size)
    case .reef: drawReef(c, size)
    case .magma: drawMagma(c, size)
    case .candy: drawCandy(c, size, v)
    case .dunes: drawDunes(c, size, v)
    case .storm: drawStorm(c, size, v)
    case .crystal: drawCrystal(c, size, v)
    case .haunted: drawHaunted(c, size, v)
    case .circuit: drawCircuit(c, size, v)
    case .jungle: drawJungle(c, size, v)
    case .clouds: drawClouds(c, size, v)
    case .clockwork: drawClockwork(c, size, v)
    }
    if v > 0, let look = relight(k, v) { look.apply(c, size) }
    grain(c, size)
}

/// One small tile of faint black and white specks. Over a full screen it breaks up the
/// banding 8-bit gradients get on dark colours. Drawn pixel for pixel.
private let grainTile: CGImage = {
    let n = 256
    var d = Dice(99)
    var px = [UInt8](repeating: 0, count: n * n * 4)
    for i in 0..<(n * n) {
        let r = d.next()
        let a = UInt8(r % 7)            // alpha 0...6 of 255
        let v: UInt8 = (r >> 8) & 1 == 0 ? 0 : a   // premultiplied black or white
        px[i * 4] = v; px[i * 4 + 1] = v; px[i * 4 + 2] = v; px[i * 4 + 3] = a
    }
    let provider = CGDataProvider(data: Data(px) as CFData)!
    return CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4, space: sRGB,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}()

func grain(_ c: CGContext, _ s: CGSize) {
    let t = c.ctm
    let sx = max(abs(t.a), 0.0001), sy = max(abs(t.d), 0.0001)
    c.with {
        c.interpolationQuality = .none
        c.draw(grainTile, in: CGRect(x: 0, y: 0, width: 256 / sx, height: 256 / sy), byTiling: true)
    }
}

/// Paints soft, featureless layers at one pixel per point, then scales them up. Gradients
/// are expensive per pixel and have no detail to lose, and the grain hides any stepping.
/// This is what keeps a retina arena inside its time budget.
func backdrop(_ c: CGContext, _ s: CGSize, _ draw: (CGContext) -> Void) {
    let pixelScale = abs(c.ctm.a)
    guard pixelScale > 1.25 else { draw(c); return }
    let w = Int(s.width.rounded(.up)), h = Int(s.height.rounded(.up))
    let img = makeImage(pxW: w, pxH: h, opaque: true, unitsX: s.width, unitsY: s.height, draw)
    c.with {
        c.translateBy(x: 0, y: s.height)
        c.scaleBy(x: 1, y: -1)
        c.draw(img, in: CGRect(origin: .zero, size: s))
    }
}

/// Edge darkening. Keeps eyes in the middle, where the gameplay is.
func vignette(_ c: CGContext, _ s: CGSize, _ strength: CGFloat = 0.5) {
    let m = hypot(s.width, s.height) / 2
    c.radial(grad([(0, C(0x05001A, 0)), (0.55, C(0x05001A, 0)), (1, C(0x05001A, strength))]), P(s.width / 2, s.height / 2), m, extend: true)
}

/// Stars scale with area, not with stretching. They stay out of a soft central oval.
func stars(_ c: CGContext, _ s: CGSize, seed: UInt64, density: CGFloat, tints: [C], maxR: CGFloat = 1.6, keepOut: CGFloat = 0.5) {
    var d = Dice(seed)
    let count = Int(s.width * s.height * density)
    let cx = s.width / 2, cy = s.height / 2
    let rx = s.width * 0.5, ry = s.height * 0.5
    for _ in 0..<count {
        let x = d.range(0, s.width), y = d.range(0, s.height)
        let dn = hypot((x - cx) / rx, (y - cy) / ry)
        let fade = max(0.3, min(1, (dn - keepOut * 0.3) / keepOut))
        let t = tints[Int(d.unit() * CGFloat(tints.count)) % tints.count]
        let size = pow(d.unit(), 4) * maxR + 0.35
        c.setFillColor(t.alpha(d.range(0.3, 0.8) * fade * (size > 1 ? 0.75 : 1)).cg)
        c.fillEllipse(in: CGRect(x: x - size, y: y - size, width: size * 2, height: size * 2))
    }
}

func flare(_ c: CGContext, _ at: CGPoint, _ r: CGFloat, _ col: C, _ peak: CGFloat = 1) {
    c.glow(col, at, r * 0.6, 0.5 * peak)
    c.fill(polygon(starPoints(at, r, r * 0.045, 4)), C.white.alpha(0.85 * peak))
    c.fill(polygon(starPoints(at, r * 0.4, r * 0.03, 4, rot: 45)), col.alpha(0.6 * peak))
    c.glow(.white, at, r * 0.13, peak)
}

// MARK: - Classic

private func drawClassic(_ c: CGContext, _ s: CGSize) {
    let u = min(s.width, s.height)
    backdrop(c, s) { c in
        c.linear(grad([(0, C(0x07103F)), (0.5, C(0x0D1F6E)), (1, C(0x08124C))]), P(0, 0), P(0, s.height))
        // Soft pools of blue, placed from the shape of the screen.
        c.blob(softGrad(C(0x2452D8), 0.55), P(s.width * 0.5, s.height * 0.5), max(s.width, u) * 0.85, s.height * 0.42)
        c.blob(softGrad(C(0x3A2AC8), 0.4), P(s.width * 0.12, s.height * 0.86), u * 0.7, u * 0.5)
        c.blob(softGrad(C(0x1A78E0), 0.32), P(s.width * 0.88, s.height * 0.12), u * 0.7, u * 0.5)
        vignette(c, s, 0.42)
    }
    stars(c, s, seed: 11, density: 0.0016, tints: [C(0xFFFFFF), C(0xA8C8FF), C(0x80B0FF)], maxR: 1.05)
    flare(c, P(s.width * 0.80, max(s.height * 0.09, u * 0.12)), u * 0.095, C(0x70B0FF), 0.8)
    flare(c, P(s.width * 0.14, min(s.height * 0.92, s.height - u * 0.1)), u * 0.075, C(0x70B0FF), 0.75)
    flare(c, P(s.width * 0.09, s.height * 0.20), u * 0.045, C(0x70B0FF), 0.6)
}

// MARK: - Neon

private func drawNeon(_ c: CGContext, _ s: CGSize) {
    let u = min(s.width, s.height)
    let horizon = s.height - max(u * 0.30, s.height * 0.20)
    backdrop(c, s) { c in
        c.linear(grad([(0, C(0x110640)), (0.55, C(0x2A0C7E)), (1, C(0x7A1CB8))]), P(0, 0), P(0, horizon))
        c.blob(softGrad(C(0x5A22E0), 0.4), P(s.width * 0.5, s.height * 0.26), max(s.width, u), s.height * 0.3)
        // Low sun glow behind the peaks.
        c.blob(softGrad(C(0xFF3CC8), 0.85), P(s.width * 0.5, horizon), max(s.width * 0.8, u), u * 0.5)
    }
    stars(c, CGSize(width: s.width, height: horizon * 0.8), seed: 21, density: 0.0008, tints: [C(0xFFFFFF), C(0xE0A8FF)], maxR: 1.2, keepOut: 0.2)

    // Floor.
    c.with {
        c.clip(to: CGRect(x: 0, y: horizon, width: s.width, height: s.height - horizon))
        c.linear(grad([(0, C(0x2A0870)), (1, C(0x0C0230))]), P(0, horizon), P(0, s.height))
        let lines = CGMutablePath()
        let vp = P(s.width / 2, horizon)
        let span = s.width * 3
        let columns = max(10, Int(s.width / (u * 0.09)))
        for i in -columns...columns {
            lines.move(to: vp)
            lines.addLine(to: P(s.width / 2 + span * CGFloat(i) / CGFloat(columns), s.height + 4))
        }
        let depth = s.height - horizon
        for i in 1...9 {
            let t = CGFloat(i) / 9
            let y = horizon + depth * t * t
            lines.move(to: P(0, y)); lines.addLine(to: P(s.width, y))
        }
        c.stroke(lines, C(0xFF4FE0, 0.3), max(u * 0.003, 0.7), cap: .butt)
        c.linear(grad([(0, C(0xFF3CC8, 0.32)), (0.35, C(0xFF3CC8, 0)), (1, C(0x0C0230, 0))]), P(0, horizon), P(0, s.height))
    }

    // Peaks: tallest at the outside so the centre stays open. Each is its own shape,
    // with a jagged ridge and a lit right face, then a neon edge on the front range.
    var d = Dice(31)
    func peak(_ x: CGFloat, _ w: CGFloat, _ h: CGFloat, base: CGFloat, dark: C, darkLow: C, lit: C, line: C, lineW: CGFloat) {
        let top = P(x + w * d.range(-0.08, 0.08), base - h)
        func walk(_ from: CGPoint, _ to: CGPoint, _ n: Int, _ jitter: CGFloat) -> [CGPoint] {
            (0...n).map { i in
                let t = CGFloat(i) / CGFloat(n)
                let wob = (i == 0 || i == n) ? 0 : d.range(-jitter, jitter)
                return P(from.x + (to.x - from.x) * t + wob, from.y + (to.y - from.y) * t + wob * 0.7)
            }
        }
        let left = walk(P(x - w / 2, base), top, 4, w * 0.045)
        let right = walk(top, P(x + w / 2, base), 4, w * 0.045)
        let ridge = walk(top, P(x + w * 0.06, base), 4, w * 0.05)
        c.fillLinear(polygon(left + right.dropFirst()), grad([(0, dark), (1, darkLow)]), P(0, base - h), P(0, base))
        c.fillLinear(polygon(right + ridge.reversed().dropLast()), grad([(0, lit), (1, lit.alpha(0.1))]), P(0, base - h), P(0, base))
        c.stroke(polyline(left + right.dropFirst()), line, lineW)
    }
    let span = s.width + u * 0.3
    let backN = max(3, Int(s.width / (u * 0.34)))
    for i in 0...backN {
        let t = CGFloat(i) / CGFloat(backN)
        let edge = abs(t - 0.5) * 2
        peak(-u * 0.15 + span * t, u * 0.62, u * (0.13 + 0.25 * edge * edge) * d.range(0.85, 1.1), base: horizon + 1,
             dark: C(0x3A1490), darkLow: C(0x5A1CA8), lit: C(0x8A3CD8, 0.5), line: C(0xB04CFF, 0.38), lineW: max(u * 0.003, 0.7))
    }
    let frontN = max(4, Int(s.width / (u * 0.27)))
    for i in 0...frontN {
        let t = (CGFloat(i) + 0.5 * CGFloat(i % 2)) / CGFloat(frontN)
        let edge = min(abs(t - 0.5) * 2, 1)
        peak(-u * 0.15 + span * t, u * 0.42, u * (0.07 + 0.16 * edge * edge) * d.range(0.85, 1.15), base: horizon + 2,
             dark: C(0x22096A), darkLow: C(0x140448), lit: C(0xC83CD8, 0.34), line: C(0xFF5CE0, 0.62), lineW: max(u * 0.004, 0.9))
    }
    c.fill(CGPath(rect: CGRect(x: 0, y: horizon, width: s.width, height: max(u * 0.004, 1)), transform: nil), C(0xFFB8F4, 0.85))
    vignette(c, s, 0.4)
}

// MARK: - Forest

/// A cartoon tree: tapered trunk, one lobed canopy silhouette, then hard-edged lit lobes on top.
func tree(_ c: CGContext, x: CGFloat, base: CGFloat, h: CGFloat, leaf: C, leafLow: C, leafHi: C, trunk: C, d: inout Dice) {
    let tw = h * 0.05
    c.fill(polygon([P(x - tw * 0.55, base - h * 0.55), P(x + tw * 0.55, base - h * 0.55), P(x + tw * 0.8, base - h * 0.08), P(x + tw * 1.5, base + h * 0.04), P(x - tw * 1.5, base + h * 0.04), P(x - tw * 0.8, base - h * 0.08)], round: tw * 0.2), trunk)
    let spec: [(CGFloat, CGFloat, CGFloat)] = [
        (0, -0.88, 0.17), (-0.17, -0.78, 0.16), (0.18, -0.79, 0.16), (-0.28, -0.60, 0.17), (0.29, -0.61, 0.17),
        (-0.14, -0.50, 0.17), (0.14, -0.50, 0.17), (0, -0.68, 0.2),
    ]
    let balls = spec.map { (P(x + $0.0 * h + d.range(-0.012, 0.012) * h, base + $0.1 * h), $0.2 * h * d.range(0.95, 1.08)) }
    let canopy = CGMutablePath()
    for (at, r) in balls { canopy.addPath(circle(at, r)) }
    let top = base - h, bottom = base - h * 0.33
    c.fillLinear(canopy, grad([(0, leaf), (1, leafLow)]), P(0, top), P(0, bottom))
    c.with {
        c.clip(canopy)
        // A crescent of light on each upper lobe.
        for (at, r) in balls where at.y < base - h * 0.55 {
            c.fill(circle(P(at.x - r * 0.18, at.y - r * 0.22), r * 0.72), leafHi)
        }
        for (at, r) in balls where at.y < base - h * 0.55 {
            c.fill(circle(P(at.x + r * 0.05, at.y + r * 0.34), r * 0.8), leaf)
        }
    }
}

/// Three stacked tiers, each lit down its left side, on a trunk that runs into the hill.
func fir(_ c: CGContext, x: CGFloat, base: CGFloat, h: CGFloat, col: C, hi: C) {
    let w = h * 0.3
    c.fill(polygon([P(x - w * 0.1, base - h * 0.3), P(x + w * 0.1, base - h * 0.3), P(x + w * 0.13, base + h * 0.03), P(x - w * 0.13, base + h * 0.03)]), C(0x170F2E))
    c.fill(ellipse(P(x, base + h * 0.03), w * 0.55, h * 0.022), C(0x0A1A30, 0.55))
    let tiers: [(tip: CGFloat, foot: CGFloat, half: CGFloat)] = [(0.46, 0.08, 1.0), (0.72, 0.32, 0.78), (1.0, 0.56, 0.56)]
    for t in tiers {
        let tip = P(x, base - h * t.tip), fy = base - h * t.foot, half = w * t.half
        c.fill(polygon([tip, P(x + half, fy), P(x, fy + h * 0.025), P(x - half, fy)], round: h * 0.01), col)
        c.fill(polygon([tip, P(x, fy + h * 0.025), P(x - half, fy)], round: h * 0.006), hi)
    }
}

func hill(_ c: CGContext, _ s: CGSize, y: CGFloat, amp: CGFloat, waves: Int, phase: CGFloat, top: C, bottom: C) {
    var pts = [CGPoint]()
    let n = max(waves * 4, 8)
    for i in 0...n {
        let t = CGFloat(i) / CGFloat(n)
        let edge = abs(t - 0.5) * 2
        let lift = edge * edge * amp * 0.8
        pts.append(P(-20 + (s.width + 40) * t, y - lift + sin(t * CGFloat(waves) * .pi * 2 + phase) * amp * 0.45))
    }
    let p = smooth(pts)
    p.addLine(to: P(s.width + 20, s.height + 10))
    p.addLine(to: P(-20, s.height + 10))
    p.closeSubpath()
    c.fillLinear(p, grad([(0, top), (1, bottom)]), P(0, y - amp), P(0, s.height))
}

private func drawForest(_ c: CGContext, _ s: CGSize) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    // Dusk sky: deep violet down to a warm low band.
    c.linear(grad([(0, C(0x120A3E)), (0.46, C(0x241058)), (0.7, C(0x46206E)), (0.86, C(0x74345E))]), P(0, 0), P(0, H))
    stars(c, CGSize(width: W, height: H * 0.42), seed: 41, density: 0.0005, tints: [C(0xFFF4D8), C(0xD8C8FF)], maxR: 1.1, keepOut: 0.1)
    // Moon, muted and off to a corner.
    let moon = P(W * 0.70, H * 0.10)
    let mr = u * 0.06
    c.glow(C(0xFFE8B0), moon, mr * 4.5, 0.2)
    c.fillRadial(circle(moon, mr), grad([(0, C(0xE8D8B8)), (1, C(0xB8A080))]), moon, mr, from: P(moon.x - mr * 0.3, moon.y - mr * 0.3))
    c.fill(circle(P(moon.x + mr * 0.28, moon.y - mr * 0.2), mr * 0.17), C(0xA08868, 0.5))
    c.fill(circle(P(moon.x - mr * 0.3, moon.y + mr * 0.3), mr * 0.12), C(0xA08868, 0.45))
    // Long haze clouds.
    c.blob(softGrad(C(0xA05CA8), 0.22), P(W * 0.3, H * 0.30), W * 0.6, u * 0.05)
    c.blob(softGrad(C(0xE8807C), 0.22), P(W * 0.65, H * 0.60), W * 0.7, u * 0.07)

    let ground = H - max(u * 0.26, H * 0.16)
    hill(c, s, y: ground - u * 0.10, amp: u * 0.18, waves: 2, phase: 0.7, top: C(0x3E2470), bottom: C(0x2A1858))
    var d = Dice(43)

    // Far tree line: a scalloped band that thickens toward the sides.
    let scallops = CGMutablePath()
    let bumps = max(12, Int(W / (u * 0.05)))
    for i in 0...bumps {
        let t = CGFloat(i) / CGFloat(bumps)
        let edge = abs(t - 0.5) * 2
        let r = u * d.range(0.035, 0.06) * (1 + edge)
        scallops.addPath(circle(P(W * t, ground - u * 0.015 - edge * edge * u * 0.07 + d.range(-1, 1) * u * 0.01), r))
    }
    scallops.addRect(CGRect(x: 0, y: ground - u * 0.01, width: W, height: H))
    c.fillLinear(scallops, grad([(0, C(0x2A2E6A)), (1, C(0x1C2850))]), P(0, ground - u * 0.15), P(0, ground + u * 0.1))

    hill(c, s, y: ground + u * 0.03, amp: u * 0.10, waves: 3, phase: 2.2, top: C(0x1C3A5A), bottom: C(0x142A48))

    // Mid firs, near trees: all kept to the two sides, sized from the short edge.
    for (t, k) in [(0.20, 0.34), (0.27, 0.27), (0.76, 0.3), (0.84, 0.38)] as [(CGFloat, CGFloat)] {
        fir(c, x: W * t, base: ground + u * 0.06, h: u * k, col: C(0x10304A), hi: C(0x173F54))
    }
    let scale = u + min(max(W, H) - u, u) * 0.14
    let near: [(CGFloat, CGFloat)] = [(-0.02, 0.66), (0.09, 0.42), (0.93, 0.46), (1.03, 0.70)]
    for (t, k) in near {
        tree(c, x: W * t, base: ground + u * 0.11, h: scale * k, leaf: C(0x0E3A3C), leafLow: C(0x082430), leafHi: C(0x175248), trunk: C(0x170F2E), d: &d)
    }
    hill(c, s, y: ground + u * 0.15, amp: u * 0.07, waves: 2, phase: 4.1, top: C(0x12403A), bottom: C(0x081E28))

    // A few fireflies, low down.
    for _ in 0..<max(5, Int(W / 110)) {
        let x = d.range(0, W), y = d.range(ground + u * 0.02, H - u * 0.02)
        let r = u * d.range(0.0028, 0.0048)
        c.glow(C(0xE8FF8A), P(x, y), r * 5, 0.38)
        c.fill(circle(P(x, y), r * 0.7), C(0xF8FFC8, 0.8))
    }
    vignette(c, s, 0.45)
}

// MARK: - Space

func planet(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, light: C, base: C, deep: C, band: C?, ring: C?) {
    c.glow(base, o, r * 1.6, 0.45)
    func ringPart(front: Bool) {
        guard let ring else { return }
        c.with {
            c.translateBy(x: o.x, y: o.y); c.rotate(by: rad(-18))
            c.clip(to: CGRect(x: -r * 3, y: front ? 0 : -r * 3, width: r * 6, height: r * 3))
            let e = CGMutablePath()
            e.addEllipse(in: CGRect(x: -r * 1.75, y: -r * 0.46, width: r * 3.5, height: r * 0.92))
            e.addEllipse(in: CGRect(x: -r * 1.4, y: -r * 0.30, width: r * 2.8, height: r * 0.60))
            c.addPath(e); c.clip(using: .evenOdd)
            c.linear(grad([(0, ring.alpha(ring.a * 0.25)), (0.3, ring), (0.7, ring.alpha(ring.a * 0.75)), (1, ring.alpha(ring.a * 0.2))]), P(-r * 1.75, 0), P(r * 1.75, 0))
        }
    }
    ringPart(front: false)
    c.with {
        c.clip(circle(o, r))
        c.radial(grad([(0, light), (0.5, base), (1, deep)]), P(o.x + r * 0.1, o.y + r * 0.1), r * 1.1, from: P(o.x - r * 0.4, o.y - r * 0.5), extend: true)
        if let band {
            let g = softGrad(band, band.a * 1.6)
            c.blob(g, P(o.x, o.y - r * 0.40), r * 1.3, r * 0.17, rot: -8)
            c.blob(g, P(o.x, o.y + r * 0.04), r * 1.3, r * 0.26, rot: -8)
            c.blob(g, P(o.x, o.y + r * 0.46), r * 1.3, r * 0.15, rot: -8)
        }
        // Terminator shadow, then a thin lit crescent.
        c.radial(grad([(0, C(0x05001A, 0)), (0.5, C(0x05001A, 0)), (1, C(0x05001A, 0.85))]), P(o.x - r * 0.32, o.y - r * 0.32), r * 1.55, extend: true)
    }
    c.blob(grad([(0, C.white.alpha(0.55)), (1, C.white.alpha(0))]), P(o.x - r * 0.42, o.y - r * 0.52), r * 0.34, r * 0.15, rot: -32)
    c.strokeLinear(circle(o, r * 0.985), r * 0.02, grad([(0, C.white.alpha(0.45)), (0.5, C.white.alpha(0)), (1, light.alpha(0.2))]), P(o.x - r, o.y - r), P(o.x + r, o.y + r))
    ringPart(front: true)
}

private func drawSpace(_ c: CGContext, _ s: CGSize) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    backdrop(c, s) { c in
        c.linear(grad([(0, C(0x0C0638)), (0.5, C(0x180A52)), (1, C(0x0A0634))]), P(0, 0), P(0, H))
        // Nebula: overlapping colour clouds kept to the corners, faint across the middle.
        c.blob(softGrad(C(0x8E2CD8), 0.5), P(W * 0.05, H * 0.30), u * 0.95, u * 0.65, rot: 30)
        c.blob(softGrad(C(0xE02C9C), 0.32), P(W * 0.20, H * 0.14), u * 0.65, u * 0.38, rot: 20)
        c.blob(softGrad(C(0x2452D8), 0.5), P(W * 0.95, H * 0.74), u * 0.95, u * 0.65, rot: -30)
        c.blob(softGrad(C(0x28B0D8), 0.28), P(W * 0.80, H * 0.88), u * 0.65, u * 0.36, rot: -16)
        c.blob(softGrad(C(0x4A28C8), 0.2), P(W * 0.5, H * 0.5), W * 0.7, H * 0.25, rot: -18)
        vignette(c, s, 0.4)
    }
    stars(c, s, seed: 51, density: 0.0015, tints: [C(0xFFFFFF), C(0xC8D8FF), C(0xFFD8F0)], maxR: 1.0)
    flare(c, P(W * 0.90, H * 0.32), u * 0.05, C(0xC090FF), 0.7)
    flare(c, P(W * 0.08, H * 0.62), u * 0.04, C(0x90C0FF), 0.6)
    // Planets near the corners.
    planet(c, P(W * 0.16, H * 0.11 + u * 0.02), u * 0.115, light: C(0x8CA8FF), base: C(0x3A50D8), deep: C(0x180E70), band: C(0xC0D0FF, 0.13), ring: nil)
    planet(c, P(W * 0.80, H * 0.87), u * 0.15, light: C(0xE090E8), base: C(0x8A38C0), deep: C(0x2C0C60), band: C(0xFFC8E8, 0.14), ring: C(0xD8B8FF, 0.65))
}

// MARK: - Frost

/// A fir with snow on each tier: the plain fir, then a white cap along the top of every tier.
private func snowyFir(_ c: CGContext, x: CGFloat, base: CGFloat, h: CGFloat) {
    fir(c, x: x, base: base, h: h, col: C(0x15385E), hi: C(0x1E4A74))
    let w = h * 0.3
    let tiers: [(tip: CGFloat, half: CGFloat)] = [(0.46, 1.0), (0.72, 0.78), (1.0, 0.56)]
    for t in tiers {
        let tip = P(x, base - h * t.tip), half = w * t.half
        c.fill(polygon([tip, P(x + half * 0.42, tip.y + h * 0.1), P(x + half * 0.16, tip.y + h * 0.085), P(x, tip.y + h * 0.11), P(x - half * 0.2, tip.y + h * 0.08), P(x - half * 0.45, tip.y + h * 0.1)], round: h * 0.006), C(0xEAF6FF, 0.92))
    }
}

/// Frost Fair: a clear winter night, green aurora over snowy hills and firs.
private func drawFrost(_ c: CGContext, _ s: CGSize) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    backdrop(c, s) { c in
        c.linear(grad([(0, C(0x05122E)), (0.5, C(0x0C2C5C)), (1, C(0x1C4C86))]), P(0, 0), P(0, H))
        // Aurora curtains, kept high so the middle stays calm.
        c.blob(softGrad(C(0x2EF0B4), 0.34), P(W * 0.32, H * 0.16), max(W, u) * 0.55, u * 0.12, rot: -12)
        c.blob(softGrad(C(0x46C8FF), 0.26), P(W * 0.62, H * 0.1), max(W, u) * 0.5, u * 0.1, rot: 8)
        c.blob(softGrad(C(0x8A6CFF), 0.22), P(W * 0.85, H * 0.2), u * 0.5, u * 0.14, rot: -20)
        vignette(c, s, 0.38)
    }
    stars(c, CGSize(width: W, height: H * 0.5), seed: 61, density: 0.0012, tints: [C(0xFFFFFF), C(0xC8F0FF)], maxR: 1.1, keepOut: 0.2)
    let ground = H - max(u * 0.26, H * 0.16)
    hill(c, s, y: ground - u * 0.06, amp: u * 0.16, waves: 2, phase: 1.3, top: C(0x6E9AD0), bottom: C(0x3E6AA4))
    for (t, k) in [(0.06, 0.3), (0.16, 0.42), (0.25, 0.28), (0.75, 0.3), (0.85, 0.44), (0.95, 0.32)] as [(CGFloat, CGFloat)] {
        snowyFir(c, x: W * t, base: ground + u * 0.05, h: u * k)
    }
    hill(c, s, y: ground + u * 0.1, amp: u * 0.08, waves: 3, phase: 0.4, top: C(0xB4D4F4), bottom: C(0x7CA2D2))
    // Snowflakes: soft dots, thicker toward the sides.
    var d = Dice(67)
    for _ in 0..<max(40, Int(W * H / 9000)) {
        let x = d.range(0, W), y = d.range(0, H)
        let edge = abs(x / W - 0.5) * 2
        guard d.unit() < 0.35 + edge * 0.65 else { continue }
        let r = u * d.range(0.002, 0.0055)
        c.glow(C(0xE8F8FF), P(x, y), r * 3, 0.25)
        c.fill(circle(P(x, y), r), C(0xFFFFFF, 0.8))
    }
    vignette(c, s, 0.35)
}

// MARK: - Reef

/// A coral fan: branches that fork as they climb, drawn as thick round strokes.
private func coral(_ c: CGContext, x: CGFloat, base: CGFloat, h: CGFloat, col: C, d: inout Dice) {
    func branch(_ from: CGPoint, _ angle: CGFloat, _ len: CGFloat, _ width: CGFloat, _ depth: Int) {
        let to = P(from.x + cos(angle) * len, from.y - sin(angle) * len)
        let p = CGMutablePath(); p.move(to: from); p.addLine(to: to)
        c.stroke(p, col, width, cap: .round)
        guard depth > 0 else { c.fill(circle(to, width * 0.8), col); return }
        branch(to, angle + d.range(0.25, 0.5), len * 0.72, width * 0.72, depth - 1)
        branch(to, angle - d.range(0.25, 0.5), len * 0.72, width * 0.72, depth - 1)
    }
    branch(P(x, base), .pi / 2 + d.range(-0.15, 0.15), h * 0.34, h * 0.07, 3)
}

/// Coral Drift: sunlight shafts down a teal sea, coral and kelp at the edges, bubbles rising.
private func drawReef(_ c: CGContext, _ s: CGSize) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    backdrop(c, s) { c in
        c.linear(grad([(0, C(0x0A6A8A)), (0.4, C(0x07476E)), (1, C(0x041C3C))]), P(0, 0), P(0, H))
        c.blob(softGrad(C(0x3CE0E8), 0.36), P(W * 0.5, 0), max(W, u) * 0.7, u * 0.3)
        // Light shafts fanning down from the surface.
        for (x0, spread, a) in [(0.18, 0.1, 0.07), (0.38, 0.14, 0.06), (0.6, 0.12, 0.07), (0.82, 0.1, 0.05)] as [(CGFloat, CGFloat, CGFloat)] {
            let top = W * x0
            c.fillLinear(polygon([P(top - u * 0.03, 0), P(top + u * 0.03, 0), P(top + W * spread, H * 0.85), P(top - W * spread * 0.4, H * 0.85)]),
                         grad([(0, C(0xC8FAFF, a)), (1, C(0xC8FAFF, 0))]), P(0, 0), P(0, H * 0.85))
        }
        vignette(c, s, 0.42)
    }
    let floor = H - max(u * 0.2, H * 0.12)
    hill(c, s, y: floor, amp: u * 0.08, waves: 2, phase: 2.0, top: C(0x2E6E80), bottom: C(0x123A50))
    var d = Dice(71)
    // Kelp: tall wavy ribbons at the far edges.
    for t in [0.02, 0.07, 0.94, 0.985] as [CGFloat] {
        let x = W * t
        var pts: [CGPoint] = []
        for i in 0...10 { let k = CGFloat(i) / 10; pts.append(P(x + sin(k * 7 + t * 9) * u * 0.025, floor + u * 0.04 - k * u * d.range(0.55, 0.8))) }
        c.stroke(smooth(pts), C(0x1E9A72, 0.85), u * 0.022, cap: .round)
        c.stroke(smooth(pts), C(0x5CE0A0, 0.35), u * 0.007, cap: .round)
    }
    let corals: [(CGFloat, CGFloat, C)] = [(0.08, 0.42, C(0xFF6E9C)), (0.18, 0.3, C(0xFFA05C)), (0.27, 0.22, C(0xB46CFF)),
                                         (0.74, 0.24, C(0xFF8A5C)), (0.83, 0.34, C(0xFF5C8A)), (0.93, 0.4, C(0xB46CFF))]
    for (t, k, col) in corals { coral(c, x: W * t, base: floor + u * 0.05, h: u * k, col: col, d: &d) }
    hill(c, s, y: floor + u * 0.1, amp: u * 0.05, waves: 3, phase: 0.6, top: C(0x1C5468), bottom: C(0x0A2A40))
    // Rising bubbles, mostly at the sides.
    for _ in 0..<max(18, Int(W / 30)) {
        let x = d.unit() < 0.5 ? d.range(0, W * 0.28) : d.range(W * 0.72, W)
        let y = d.range(H * 0.1, floor), r = u * d.range(0.004, 0.012)
        c.stroke(circle(P(x, y), r), C(0xD8FAFF, 0.45), max(0.8, r * 0.18))
        c.fill(circle(P(x - r * 0.3, y - r * 0.3), r * 0.25), C(0xFFFFFF, 0.5))
    }
    vignette(c, s, 0.4)
}

// MARK: - Magma

/// Magma Run: a smouldering sky, volcanoes at the edges, lava cracks and embers.
private func drawMagma(_ c: CGContext, _ s: CGSize) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    let horizon = H - max(u * 0.3, H * 0.2)
    backdrop(c, s) { c in
        c.linear(grad([(0, C(0x14040E)), (0.55, C(0x3A0A1C)), (1, C(0x8A2418))]), P(0, 0), P(0, horizon))
        c.blob(softGrad(C(0xFF5A1E), 0.5), P(W * 0.5, horizon), max(W * 0.9, u), u * 0.4)
        // Smoke banks, dark and slow.
        c.blob(softGrad(C(0x2A0812), 0.6), P(W * 0.25, H * 0.2), u * 0.8, u * 0.18, rot: 10)
        c.blob(softGrad(C(0x2A0812), 0.5), P(W * 0.8, H * 0.3), u * 0.7, u * 0.16, rot: -8)
        vignette(c, s, 0.45)
    }
    // Volcanoes at the sides: jagged cones, a glowing crater and a lava flow down the near face.
    var v = Dice(79)
    for (t, k) in [(0.03, 0.36), (0.97, 0.4), (0.2, 0.22), (0.8, 0.24)] as [(CGFloat, CGFloat)] {
        let x = W * t, h = u * k, w = h * 1.25, lip = h * 0.1
        func slope(_ a: CGPoint, _ b: CGPoint) -> [CGPoint] {
            (0...6).map { i in
                let f = CGFloat(i) / 6, wob = (i == 0 || i == 6) ? 0 : v.range(-h * 0.03, h * 0.03)
                return P(a.x + (b.x - a.x) * f + wob, a.y + (b.y - a.y) * f)
            }
        }
        let outline = slope(P(x - w / 2, horizon + 2), P(x - lip, horizon - h)) + slope(P(x + lip, horizon - h), P(x + w / 2, horizon + 2))
        c.fillLinear(polygon(outline), grad([(0, C(0x4A1220)), (1, C(0x1A050C))]), P(0, horizon - h), P(0, horizon))
        c.stroke(polyline(Array(outline.prefix(7))), C(0xFF7A3A, 0.35), max(0.8, u * 0.003))
        var flow = [P(x + v.range(-lip, lip) * 0.5, horizon - h)]
        for i in 1...6 { flow.append(P(flow[i - 1].x + v.range(-h * 0.06, h * 0.06), horizon - h + h * CGFloat(i) / 6)) }
        c.stroke(smooth(flow), C(0xFF4A12, 0.45), max(1.5, h * 0.06), cap: .round)
        c.stroke(smooth(flow), C(0xFFC060, 0.9), max(0.8, h * 0.018), cap: .round)
        c.glow(C(0xFF8A30), P(x, horizon - h), lip * 4, 0.6)
    }
    // Rock floor with lava cracks.
    c.with {
        c.clip(to: CGRect(x: 0, y: horizon, width: W, height: H - horizon))
        c.linear(grad([(0, C(0x2A0A12)), (1, C(0x0E0308))]), P(0, horizon), P(0, H))
    }
    var d = Dice(83)
    for _ in 0..<max(8, Int(W / 90)) {
        var x = d.range(0, W), y = horizon + d.range(0.15, 0.9) * (H - horizon)
        var pts = [P(x, y)]
        for _ in 0..<5 { x += d.range(-u * 0.08, u * 0.08); y += d.range(-u * 0.02, u * 0.03); pts.append(P(x, y)) }
        c.stroke(polyline(pts), C(0xFF5A1E, 0.35), u * 0.012)
        c.stroke(polyline(pts), C(0xFFB050, 0.85), max(0.8, u * 0.003))
    }
    c.fill(CGPath(rect: CGRect(x: 0, y: horizon, width: W, height: max(u * 0.004, 1)), transform: nil), C(0xFF9A50, 0.7))
    // Embers drifting up, kept to the sides and the floor.
    for _ in 0..<max(45, Int(W / 12)) {
        let x = d.range(0, W), y = d.range(H * 0.2, H)
        guard abs(x / W - 0.5) > 0.22 || y > horizon else { continue }
        let r = u * d.range(0.002, 0.005)
        c.glow(C(0xFF8A30), P(x, y), r * 4, 0.4)
        c.fill(circle(P(x, y), r * 0.7), C(0xFFD08A, 0.9))
    }
    vignette(c, s, 0.42)
}
