import CoreGraphics
import Foundation

// Shared scenery for the biome painters: skies, silhouettes, haze, weather. Everything is y down, in
// points, and placed from the short side `u` so a scene composes for its shape instead of stretching.
//
// The rules every biome follows, so bubbles stay the brightest thing on screen:
// - Depth: far layers are mixed toward the haze colour, near layers are darker and richer.
// - The middle of the screen (the play band) stays low in contrast: the busy art lives at the edges.
// - Highlights are small. Large areas sit in the lower half of the value range.

/// One take on a biome's light: sky, haze, the silhouettes' tones and the glow of its light source.
struct Look {
    var top: C, mid: C, low: C      // sky, top to horizon
    var haze: C                     // atmospheric haze, also the calm tint over the play band
    var far: C, near: C, deep: C    // silhouettes: far range, near range, foreground
    var light: C                    // the sun, moon or lamp light the scene is lit by
    var accent: C                   // the biome's signature glow
    var night: CGFloat = 0          // 0 day ... 1 full night: stars and glow strength
}

extension C {
    /// Lighter or darker by mixing toward white or black.
    func lit(_ t: CGFloat) -> C { t >= 0 ? mix(.white, t) : mix(C(0x05010F), -t) }
}

/// The sky: three stops down to the horizon, and the low colour below it.
func sky(_ c: CGContext, _ s: CGSize, _ k: Look, horizon: CGFloat) {
    c.linear(grad([(0, k.top), (0.55, k.mid), (1, k.low)]), P(0, 0), P(0, max(horizon, 1)))
}

/// A soft horizontal band of haze. Drawn over a layer, it pushes everything behind it back.
func hazeBand(_ c: CGContext, _ s: CGSize, y: CGFloat, h: CGFloat, _ col: C, _ a: CGFloat) {
    c.blob(softGrad(col, a), P(s.width / 2, y), max(s.width, s.height) * 0.9, h)
}

/// The finishing calm: a broad, faint veil of the haze colour through the middle, where the play is.
func calmCentre(_ c: CGContext, _ s: CGSize, _ col: C, _ a: CGFloat = 0.22) {
    c.blob(softGrad(col, a), P(s.width / 2, s.height * 0.5), max(s.width, s.height) * 0.75, s.height * 0.42)
}

/// A silhouette edge from left to right: smooth hills, or jagged peaks when `jag` > 0. Rises toward the
/// sides by `lift`, so the middle stays open. Closed down to the bottom of the screen.
func ridge(_ s: CGSize, base: CGFloat, amp: CGFloat, seed: UInt64, bumps: Int, jag: CGFloat = 0, lift: CGFloat = 0.6) -> CGMutablePath {
    var d = Dice(seed)
    let n = max(bumps * 3, 6)
    var pts = [CGPoint]()
    for i in 0...n {
        let t = CGFloat(i) / CGFloat(n)
        let edge = abs(t - 0.5) * 2
        var y = base - edge * edge * amp * lift - amp * 0.5 * (0.5 + 0.5 * sin(t * CGFloat(bumps) * .pi * 2 + CGFloat(seed % 7)))
        if jag > 0 { y -= d.range(0, amp * jag) }
        pts.append(P(-30 + (s.width + 60) * t, y))
    }
    let p = jag > 0 ? { let m = CGMutablePath(); m.addLines(between: pts); return m }() : smooth(pts)
    p.addLine(to: P(s.width + 30, s.height + 10))
    p.addLine(to: P(-30, s.height + 10))
    p.closeSubpath()
    return p
}

func layer(_ c: CGContext, _ p: CGPath, _ top: C, _ bottom: C, _ y0: CGFloat, _ y1: CGFloat) {
    c.fillLinear(p, grad([(0, top), (1, bottom)]), P(0, y0), P(0, y1))
}

/// A bright rim along a silhouette's top edge, as if lit from behind.
func rimLight(_ c: CGContext, _ p: CGPath, _ col: C, _ w: CGFloat) {
    c.with { c.clip(p); c.stroke(p, col, w * 2) }
}

func disc(_ c: CGContext, _ at: CGPoint, _ r: CGFloat, _ col: C, glow: CGFloat) {
    if glow > 0 { c.glow(col, at, r * 5, glow * 0.45); c.glow(col, at, r * 2, glow * 0.6) }
    c.fill(circle(at, r), col.lit(0.55))
    c.fill(circle(at, r * 0.8), col.lit(0.75))
}

func moon(_ c: CGContext, _ at: CGPoint, _ r: CGFloat, _ col: C, glow: CGFloat = 0.5) {
    c.glow(col, at, r * 6, glow * 0.35)
    c.glow(col, at, r * 2.2, glow * 0.5)
    c.fillRadial(circle(at, r), grad([(0, col.lit(0.7)), (1, col.lit(0.2))]), at, r, from: P(at.x - r * 0.3, at.y - r * 0.3))
    c.fill(circle(P(at.x + r * 0.3, at.y - r * 0.15), r * 0.16), col.lit(-0.15).alpha(0.4))
    c.fill(circle(P(at.x - r * 0.25, at.y + r * 0.35), r * 0.11), col.lit(-0.15).alpha(0.35))
}

/// A cartoon cloud: a heap of circles with a flat-ish base, a lit crown and a shaded belly.
func puff(_ c: CGContext, _ at: CGPoint, w: CGFloat, h: CGFloat, body: C, shade: C, lit: C, seed: UInt64, flat: Bool = true) {
    var d = Dice(seed)
    let p = CGMutablePath()
    let n = 6
    var lobes: [(CGPoint, CGFloat)] = []
    for i in 0..<n {
        let t = CGFloat(i) / CGFloat(n - 1)
        let arch = sin(t * .pi)
        let r = h * (0.32 + 0.38 * arch) * d.range(0.85, 1.12)
        lobes.append((P(at.x - w / 2 + w * t, at.y - arch * h * 0.18 + r * 0.2), r))
    }
    for (o, r) in lobes { p.addPath(circle(o, r)) }
    if flat { p.addRect(CGRect(x: at.x - w / 2, y: at.y, width: w, height: h * 0.35)) } else {
        // A rounded belly: smaller lobes hanging under the crown.
        for (o, r) in lobes.dropFirst().dropLast() { p.addPath(circle(P(o.x + r * 0.3, at.y + h * 0.12), r * 0.6)) }
    }
    let cut = CGMutablePath(); cut.addRect(CGRect(x: at.x - w, y: at.y - h * 2, width: w * 2, height: flat ? h * 2 + h * 0.3 : h * 3))
    c.with {
        c.clip(cut)
        layer(c, p, body, shade, at.y - h * 0.6, at.y + h * 0.3)
        c.with {
            c.clip(p)
            for (o, r) in lobes { c.fill(circle(P(o.x - r * 0.2, o.y - r * 0.35), r * 0.62), lit) }
            for (o, r) in lobes { c.fill(circle(P(o.x + r * 0.1, o.y + r * 0.25), r * 0.75), body) }
            c.linear(grad([(0, shade.alpha(0)), (1, shade)]), P(0, at.y - h * 0.1), P(0, at.y + h * 0.3))
        }
    }
}

/// Slanted streaks, thicker toward the edges. Rain, sandstorm, wind.
func streaks(_ c: CGContext, _ s: CGSize, seed: UInt64, _ col: C, count: Int, len: CGFloat, angle: CGFloat, width: CGFloat) {
    var d = Dice(seed)
    let dx = sin(rad(angle)) * len, dy = cos(rad(angle)) * len
    let path = CGMutablePath()
    for _ in 0..<count {
        let x = d.range(-len, s.width + len), y = d.range(-len, s.height)
        let edge = abs(x / s.width - 0.5) * 2
        guard d.unit() < 0.3 + edge * 0.7 else { continue }
        let k = d.range(0.5, 1)
        path.move(to: P(x, y)); path.addLine(to: P(x + dx * k, y + dy * k))
    }
    c.stroke(path, col, width, cap: .round)
}

/// Glowing dots: fireflies, embers, sparkles, dust.
func motes(_ c: CGContext, _ s: CGSize, seed: UInt64, _ col: C, count: Int, in r: CGRect, size: ClosedRange<CGFloat>, edges: Bool = true, glow: CGFloat = 0.4) {
    var d = Dice(seed)
    for _ in 0..<count {
        let x = d.range(r.minX, r.maxX), y = d.range(r.minY, r.maxY)
        if edges {
            let e = abs(x / s.width - 0.5) * 2
            guard d.unit() < 0.25 + e * 0.75 else { continue }
        }
        let rr = d.range(size.lowerBound, size.upperBound)
        if glow > 0 { c.glow(col, P(x, y), rr * 4, glow) }
        c.fill(circle(P(x, y), rr), col.lit(0.5).alpha(0.85))
    }
}

/// A forked lightning bolt with a glow, from `a` toward `b`.
func bolt(_ c: CGContext, _ a: CGPoint, _ b: CGPoint, seed: UInt64, width w: CGFloat, _ col: C, glow: CGFloat = 1) {
    var d = Dice(seed)
    func path(_ from: CGPoint, _ to: CGPoint, _ n: Int, _ jit: CGFloat) -> [CGPoint] {
        (0...n).map { i in
            let t = CGFloat(i) / CGFloat(n)
            let j = (i == 0 || i == n) ? 0 : d.range(-jit, jit)
            return P(from.x + (to.x - from.x) * t + j, from.y + (to.y - from.y) * t)
        }
    }
    let len = hypot(b.x - a.x, b.y - a.y)
    let main = path(a, b, 9, len * 0.07)
    let forkAt = main[4]
    let fork = path(forkAt, P(forkAt.x + len * d.range(0.15, 0.3) * (d.unit() < 0.5 ? -1 : 1), forkAt.y + len * 0.35), 5, len * 0.04)
    let mid = P((a.x + b.x) / 2, (a.y + b.y) / 2)
    if glow > 0 {
        c.glow(col, mid, len * 0.75, 0.35 * glow)
        c.glow(col, a, len * 0.3, 0.4 * glow)
    }
    for (pts, k) in [(main, 1.0), (fork, 0.55)] as [([CGPoint], CGFloat)] {
        c.stroke(polyline(pts), col.alpha(0.35), w * 3.2 * k)
        c.stroke(polyline(pts), col.lit(0.4), w * 1.3 * k)
        c.stroke(polyline(pts), .white, w * 0.5 * k)
    }
}

/// Fills a path with diagonal stripes of `col` (candy canes, awnings, hazard paint).
func stripes(_ c: CGContext, _ p: CGPath, _ col: C, width w: CGFloat, angle: CGFloat = 35) {
    let b = p.boundingBoxOfPath
    c.with {
        c.clip(p)
        c.translateBy(x: b.midX, y: b.midY); c.rotate(by: rad(angle))
        let span = hypot(b.width, b.height)
        var x = -span
        let path = CGMutablePath()
        while x < span { path.addRect(CGRect(x: x, y: -span, width: w, height: span * 2)); x += w * 2 }
        c.fill(path, col)
    }
}

/// A soft cone of light from a point, fanning out by `spread` radians.
func beam(_ c: CGContext, from a: CGPoint, angle: CGFloat, length: CGFloat, spread: CGFloat, _ col: C, _ alpha: CGFloat) {
    let l = P(a.x + cos(angle - spread) * length, a.y + sin(angle - spread) * length)
    let r = P(a.x + cos(angle + spread) * length, a.y + sin(angle + spread) * length)
    c.fillLinear(polygon([a, l, r]), grad([(0, col.alpha(alpha)), (1, col.alpha(0))]), a, P(a.x + cos(angle) * length, a.y + sin(angle) * length))
}
