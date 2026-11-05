import CoreGraphics
import Foundation

func drawArena(_ k: ArenaKind, _ c: CGContext, size: CGSize) {
    switch k {
    case .classic: drawClassic(c, size)
    case .neon: drawNeon(c, size)
    case .forest: drawForest(c, size)
    case .space: drawSpace(c, size)
    }
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
        let a = UInt8(r % 5)            // alpha 0...4 of 255
        let v: UInt8 = (r >> 8) & 1 == 0 ? 0 : a   // premultiplied black or white
        px[i * 4] = v; px[i * 4 + 1] = v; px[i * 4 + 2] = v; px[i * 4 + 3] = a
    }
    let provider = CGDataProvider(data: Data(px) as CFData)!
    return CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4, space: sRGB,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}()

private func grain(_ c: CGContext, _ s: CGSize) {
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
private func backdrop(_ c: CGContext, _ s: CGSize, _ draw: (CGContext) -> Void) {
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
private func vignette(_ c: CGContext, _ s: CGSize, _ strength: CGFloat = 0.5) {
    let m = hypot(s.width, s.height) / 2
    c.radial(grad([(0, C(0x05001A, 0)), (0.55, C(0x05001A, 0)), (1, C(0x05001A, strength))]), P(s.width / 2, s.height / 2), m, extend: true)
}

/// Stars scale with area, not with stretching. They stay out of a soft central oval.
private func stars(_ c: CGContext, _ s: CGSize, seed: UInt64, density: CGFloat, tints: [C], maxR: CGFloat = 1.6, keepOut: CGFloat = 0.5) {
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

private func flare(_ c: CGContext, _ at: CGPoint, _ r: CGFloat, _ col: C, _ peak: CGFloat = 1) {
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
private func tree(_ c: CGContext, x: CGFloat, base: CGFloat, h: CGFloat, leaf: C, leafLow: C, leafHi: C, trunk: C, d: inout Dice) {
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
private func fir(_ c: CGContext, x: CGFloat, base: CGFloat, h: CGFloat, col: C, hi: C) {
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

private func hill(_ c: CGContext, _ s: CGSize, y: CGFloat, amp: CGFloat, waves: Int, phase: CGFloat, top: C, bottom: C) {
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

private func planet(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, light: C, base: C, deep: C, band: C?, ring: C?) {
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
