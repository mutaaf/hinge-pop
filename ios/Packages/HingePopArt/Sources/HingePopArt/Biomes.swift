import CoreGraphics
import Foundation

// The nine biomes of the worlds expansion. Each is an original genre nod, painted far to near, with its
// landmark (where the world's secret hides) at the spot `landmarkSpot` names. Variants 0-3 are four takes
// on the same place: the landmark never moves, the light and the weather do.

// MARK: - Candy: Sugar Rush (candy-coloured cartoons)

private func lollipop(_ c: CGContext, _ o: CGPoint, r: CGFloat, base: CGFloat, a: C, b: C, glow: CGFloat) {
    // Stick, then the swirl disc with a glossy bulge.
    let sw = r * 0.16
    c.fill(CGPath(roundedRect: CGRect(x: o.x - sw / 2, y: o.y, width: sw, height: base - o.y), cornerWidth: sw / 2, cornerHeight: sw / 2, transform: nil), C(0xF4ECF4))
    c.fill(CGPath(rect: CGRect(x: o.x - sw / 2, y: o.y, width: sw * 0.3, height: base - o.y), transform: nil), C(0xC8B0C8, 0.7))
    if glow > 0 { c.glow(a, o, r * 2.4, glow * 0.4) }
    c.fill(circle(o, r * 1.04), a.lit(-0.45))
    c.fill(circle(o, r), a)
    let spiral = CGMutablePath()
    for i in 0...90 {
        let t = CGFloat(i) / 90
        let ang = t * .pi * 5.2, rr = r * 0.95 * t
        let pt = P(o.x + cos(ang) * rr, o.y + sin(ang) * rr)
        if i == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
    }
    c.with { c.clip(circle(o, r)); c.stroke(spiral, b, r * 0.2) }
    c.fillRadial(circle(o, r), grad([(0, C.white.alpha(0.35)), (0.5, C.white.alpha(0)), (1, C(0x2A0838, 0.35))]), o, r * 1.05, from: P(o.x - r * 0.35, o.y - r * 0.4))
    c.blob(grad([(0, C.white.alpha(0.75)), (1, C.white.alpha(0))]), P(o.x - r * 0.4, o.y - r * 0.5), r * 0.28, r * 0.12, rot: -35)
}

private func cane(_ c: CGContext, x: CGFloat, base: CGFloat, h: CGFloat, w: CGFloat, stripe: C, flip: Bool) {
    let p = CGMutablePath()
    let top = base - h, hook = w * 1.6
    p.move(to: P(x, base + 4)); p.addLine(to: P(x, top + hook))
    p.addArc(center: P(x + (flip ? -hook : hook), top + hook), radius: hook, startAngle: .pi, endAngle: 0, clockwise: !flip)
    let body = p.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 4)
    c.fill(body, C(0xF8F0F4))
    stripes(c, body, stripe, width: w * 0.45, angle: 40)
    c.with { c.clip(body); c.fill(CGPath(rect: CGRect(x: x + w * 0.15, y: top - hook, width: w, height: h + hook * 2), transform: nil), C(0x3A0A40, 0.18)) }
}

func drawCandy(_ c: CGContext, _ s: CGSize, _ v: Int) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    let ground = H - max(u * 0.24, H * 0.15)
    let looks: [Look] = [
        // Bubblegum afternoon, Sunset taffy, Sprinkle squall, Licorice night.
        Look(top: C(0x4A2298), mid: C(0x9A3AA8), low: C(0xD06A9E), haze: C(0xD07AB8), far: C(0xC860B0), near: C(0x8A3AA0), deep: C(0x4A1A70), light: C(0xFFE0A0), accent: C(0xFF6EC8)),
        Look(top: C(0x3A1A78), mid: C(0xC84A78), low: C(0xFFA060), haze: C(0xF08A80), far: C(0xD0607A), near: C(0x8A2A68), deep: C(0x481448), light: C(0xFFB060), accent: C(0xFF8A50)),
        Look(top: C(0x2A1E5A), mid: C(0x5A4A98), low: C(0x9A80C0), haze: C(0xA090C8), far: C(0x7A60A8), near: C(0x503A88), deep: C(0x2A1A58), light: C(0xD8D0FF), accent: C(0x80E0FF), night: 0.3),
        Look(top: C(0x0C0628), mid: C(0x2A0E50), low: C(0x5A1A6A), haze: C(0x6A2A80), far: C(0x4A1A68), near: C(0x2E0C4A), deep: C(0x14062A), light: C(0xFFD0F0), accent: C(0xFF5AD0), night: 1),
    ]
    let k = looks[v]
    backdrop(c, s) { c in
        sky(c, s, k, horizon: ground)
        c.blob(softGrad(k.light, 0.35), P(W * 0.62, ground - u * 0.1), max(W, u) * 0.7, u * 0.35)
        c.fill(CGPath(rect: CGRect(x: 0, y: ground, width: W, height: H - ground), transform: nil), k.low)
    }
    switch v {
    case 0:
        // A faint rainbow over the far hills, and a soft sun.
        let o = P(W * 0.5, ground + u * 0.1), R = max(W, u) * 0.62
        for (i, col) in [C(0xFF6A8A), C(0xFFB05A), C(0xFFF07A), C(0x7AF0A0), C(0x6AC8FF), C(0xA07AFF)].enumerated() {
            c.stroke(circle(o, R - CGFloat(i) * u * 0.018), col.alpha(0.07), u * 0.018, cap: .butt)
        }
        disc(c, P(W * 0.72, H * 0.2), u * 0.06, C(0xFFE8B0), glow: 0.6)
    case 1: disc(c, P(W * 0.6, ground - u * 0.06), u * 0.11, C(0xFFB060), glow: 0.8)
    case 3: moon(c, P(W * 0.74, H * 0.16), u * 0.055, C(0xFFD8F0), glow: 0.7)
    default: break
    }
    if k.night > 0.5 { stars(c, CGSize(width: W, height: ground * 0.7), seed: 101, density: 0.0012, tints: [C(0xFFFFFF), C(0xFFC8F0)], maxR: 1.2, keepOut: 0.2) }
    // Cotton-candy clouds, high and to the sides.
    let cloudBody = k.haze.mix(.white, k.night > 0.5 ? 0.05 : 0.3)
    puff(c, P(W * 0.16, H * 0.16), w: u * 0.42, h: u * 0.12, body: cloudBody.alpha(0.85), shade: k.far.alpha(0.8), lit: cloudBody.lit(0.35), seed: 1)
    puff(c, P(W * 0.86, H * 0.24), w: u * 0.36, h: u * 0.1, body: cloudBody.alpha(0.8), shade: k.far.alpha(0.75), lit: cloudBody.lit(0.3), seed: 2)
    if v != 3 { puff(c, P(W * 0.55, H * 0.08), w: u * 0.26, h: u * 0.07, body: cloudBody.alpha(0.5), shade: k.far.alpha(0.5), lit: cloudBody.lit(0.2), seed: 3) }
    // Far gumdrop hills, hazed.
    var d = Dice(110)
    let farBase = ground - u * 0.02
    let drops = max(6, Int(W / (u * 0.16)))
    let tints = [k.far, k.far.mix(k.accent, 0.3), k.far.mix(k.light, 0.25)]
    for i in 0...drops {
        let t = CGFloat(i) / CGFloat(drops)
        let edge = abs(t - 0.5) * 2
        let x = W * t + d.range(-u * 0.03, u * 0.03)
        let w = u * d.range(0.16, 0.24), h = u * (0.06 + 0.12 * edge) * d.range(0.8, 1.15)
        let p = CGMutablePath()
        p.move(to: P(x - w / 2, farBase + 2))
        p.addCurve(to: P(x, farBase - h), control1: P(x - w / 2, farBase - h * 0.6), control2: P(x - w * 0.3, farBase - h))
        p.addCurve(to: P(x + w / 2, farBase + 2), control1: P(x + w * 0.3, farBase - h), control2: P(x + w / 2, farBase - h * 0.6))
        let col = tints[i % 3].mix(k.haze, 0.35)
        layer(c, p, col, col.lit(-0.2), farBase - h, farBase)
        c.blob(grad([(0, C.white.alpha(0.3)), (1, C.white.alpha(0))]), P(x - w * 0.15, farBase - h * 0.7), w * 0.16, h * 0.14, rot: -30)
    }
    hazeBand(c, s, y: farBase, h: u * 0.06, k.haze, 0.35)
    // Ice-cream hills rising at the sides, each with a whipped-cream cap.
    let cream = v == 3 ? C(0xC890D8) : C(0xFFF0F4)
    for (side, seed) in [(CGFloat(-1), UInt64(140)), (1, 141)] {
        let x0 = side < 0 ? -u * 0.1 : W + u * 0.1
        let hw = u * 0.5, top = ground - u * 0.34
        let hillP = CGMutablePath()
        hillP.move(to: P(x0 - hw, ground + u * 0.08))
        hillP.addCurve(to: P(x0, top), control1: P(x0 - hw * 0.8, top + u * 0.05), control2: P(x0 - hw * 0.45, top))
        hillP.addCurve(to: P(x0 + hw, ground + u * 0.08), control1: P(x0 + hw * 0.45, top), control2: P(x0 + hw * 0.8, top + u * 0.05))
        hillP.closeSubpath()
        let col = (side < 0 ? k.near.mix(C(0xFF8AC0), 0.3) : k.near.mix(C(0x8AE0D0), 0.3)).mix(k.haze, 0.2)
        layer(c, hillP, col, col.lit(-0.3), top, ground)
        // Cream cap: a scalloped band hugging the top of the hill.
        var e = Dice(seed)
        c.with {
            c.clip(hillP)
            let capY = top + u * 0.07
            let cap = CGMutablePath()
            cap.addRect(CGRect(x: x0 - hw, y: top - u * 0.1, width: hw * 2, height: capY - top + u * 0.1))
            var x = x0 - hw
            while x < x0 + hw { let r = u * e.range(0.02, 0.035); cap.addPath(circle(P(x, capY), r)); x += r * 1.6 }
            c.fill(cap, cream.alpha(0.92))
            c.fill(CGPath(rect: CGRect(x: x0 - hw, y: top - u * 0.1, width: hw * 2, height: u * 0.12), transform: nil), C.white.alpha(0.12))
        }
        c.stroke(hillP, k.deep.alpha(0.25), max(0.8, u * 0.003))
        _ = seed
    }
    // Candy canes and the small lollipops on the right.
    cane(c, x: W * 0.9, base: ground + u * 0.04, h: u * 0.34, w: u * 0.034, stripe: v == 3 ? C(0x8A2AE0) : C(0xE8305A), flip: true)
    cane(c, x: W * 0.28, base: ground + u * 0.05, h: u * 0.18, w: u * 0.024, stripe: C(0x30B070), flip: false)
    lollipop(c, P(W * 0.78, ground - u * 0.2), r: u * 0.07, base: ground + u * 0.04, a: C(0x50C8F0), b: C(0xF8F8FF), glow: k.night)
    lollipop(c, P(W * 0.34 + u * 0.08, ground - u * 0.12), r: u * 0.045, base: ground + u * 0.04, a: C(0xFFC040), b: C(0xFF6A3A), glow: k.night)
    // The landmark: the biggest lollipop, on the left.
    let lm = landmarkSpot(.candy, s)
    lollipop(c, P(lm.x, lm.y), r: u * 0.12, base: ground + u * 0.06, a: C(0xFF4A9A), b: C(0xFFF0F6), glow: 0.3 + k.night * 0.5)
    // Frosting ground with drips over the front edge.
    let front = CGMutablePath()
    var pts: [CGPoint] = []
    let n = max(10, Int(W / (u * 0.07)))
    for i in 0...n {
        let t = CGFloat(i) / CGFloat(n)
        pts.append(P(-20 + (W + 40) * t, ground + u * 0.05 + sin(t * 9) * u * 0.012))
    }
    front.addPath(smooth(pts))
    front.addLine(to: P(W + 20, H + 10)); front.addLine(to: P(-20, H + 10)); front.closeSubpath()
    let frost = v == 3 ? C(0x7A3A9A) : [C(0xFFB8D8), C(0xFFC0B0), C(0xC8B8F0)][v]
    layer(c, front, frost, frost.lit(-0.25), ground, ground + u * 0.2)
    let choc = ridge(s, base: ground + u * 0.13, amp: u * 0.025, seed: 120, bumps: 5, lift: 0.3)
    layer(c, choc, k.deep.mix(C(0x6A2A20), 0.5), k.deep.lit(-0.4), ground + u * 0.1, H)
    // Drips of icing over the chocolate.
    for i in 0..<max(8, Int(W / (u * 0.09))) {
        let x = W * (CGFloat(i) + d.range(0.2, 0.8)) / CGFloat(max(8, Int(W / (u * 0.09))))
        let y0 = ground + u * 0.11 + sin(x / W * 9) * u * 0.012, len = u * d.range(0.03, 0.08), w = u * d.range(0.014, 0.024)
        c.fill(CGPath(roundedRect: CGRect(x: x - w / 2, y: y0 - w, width: w, height: len), cornerWidth: w / 2, cornerHeight: w / 2, transform: nil), frost.lit(-0.1))
    }
    rimLight(c, front, C.white.alpha(v == 3 ? 0.2 : 0.45), u * 0.004)
    // Sprinkles on the frosting.
    let sprinkleCols = [C(0xFF5A8A), C(0x5AD0FF), C(0xFFE05A), C(0x8AF07A), C(0xB07AFF)]
    for _ in 0..<max(30, Int(W / 10)) {
        let x = d.range(0, W), y = d.range(ground + u * 0.05, ground + u * 0.1)
        let a = d.range(0, .pi), l = u * 0.012
        c.stroke(polyline([P(x - cos(a) * l / 2, y - sin(a) * l / 2), P(x + cos(a) * l / 2, y + sin(a) * l / 2)]), sprinkleCols[Int(d.unit() * 5) % 5], u * 0.006)
    }
    switch v {
    case 2:
        // Sprinkle squall: sprinkles blowing across, thick at the edges.
        var e = Dice(130)
        for _ in 0..<max(60, Int(W * H / 5000)) {
            let x = e.range(0, W), y = e.range(0, ground)
            guard e.unit() < 0.2 + abs(x / W - 0.5) * 1.6 else { continue }
            let l = u * 0.014
            c.stroke(polyline([P(x, y), P(x + l, y + l * 0.35)]), sprinkleCols[Int(e.unit() * 5) % 5].alpha(0.7), u * 0.005)
        }
    case 3:
        motes(c, s, seed: 131, C(0xFF8AE0), count: 26, in: CGRect(x: 0, y: H * 0.3, width: W, height: H * 0.6), size: u * 0.002...u * 0.004, glow: 0.35)
    default:
        motes(c, s, seed: 132, C(0xFFF4C8), count: 18, in: CGRect(x: 0, y: H * 0.1, width: W, height: ground), size: u * 0.0015...u * 0.003, glow: 0.25)
    }
    calmCentre(c, s, k.haze.lit(-0.35), 0.18)
    vignette(c, s, 0.42)
}

// MARK: - Dunes: Dune Sea (desert epics)

func drawDunes(_ c: CGContext, _ s: CGSize, _ v: Int) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    let horizon = H - max(u * 0.42, H * 0.3)
    let looks: [Look] = [
        // Twin-sun noon, Dusk on the dunes, Oasis night, Sandstorm.
        Look(top: C(0x2A3A8A), mid: C(0xD0786A), low: C(0xFFC078), haze: C(0xF0A070), far: C(0xD07A4A), near: C(0xB0582E), deep: C(0x6A2A1A), light: C(0xFFF0C0), accent: C(0xFFB040)),
        Look(top: C(0x1E1450), mid: C(0x8A2A6A), low: C(0xF0603A), haze: C(0xC04A5A), far: C(0x9A3A50), near: C(0x6A2240), deep: C(0x30102A), light: C(0xFF8A40), accent: C(0xFF6A30)),
        Look(top: C(0x060A28), mid: C(0x122458), low: C(0x2A4A88), haze: C(0x2A3E78), far: C(0x2A3060), near: C(0x1E2248), deep: C(0x0E1028), light: C(0xD8E8FF), accent: C(0x5AD0E0), night: 1),
        Look(top: C(0x4A2420), mid: C(0x9A5030), low: C(0xC8783E), haze: C(0xC88048), far: C(0xA86034), near: C(0x804424), deep: C(0x40200E), light: C(0xFFD890), accent: C(0xFF9A40), night: 0.2),
    ]
    let k = looks[v]
    backdrop(c, s) { c in
        sky(c, s, k, horizon: horizon)
        c.fill(CGPath(rect: CGRect(x: 0, y: horizon, width: W, height: H - horizon), transform: nil), k.near)
        c.blob(softGrad(k.light, v == 2 ? 0.25 : 0.55), P(W * 0.7, horizon - u * 0.05), max(W, u) * 0.8, u * 0.3)
    }
    if v == 2 { stars(c, CGSize(width: W, height: horizon), seed: 201, density: 0.0018, tints: [C(0xFFFFFF), C(0xC8D8FF)], maxR: 1.2, keepOut: 0.15) }
    // The suns, or the moon.
    switch v {
    case 0:
        disc(c, P(W * 0.72, H * 0.12 + u * 0.04), u * 0.05, C(0xFFE8A0), glow: 0.9)
        disc(c, P(W * 0.84, H * 0.08 + u * 0.08), u * 0.03, C(0xFFB070), glow: 0.7)
    case 1: disc(c, P(W * 0.3, horizon - u * 0.04), u * 0.09, C(0xFF7A40), glow: 0.9)
    case 2: moon(c, P(W * 0.24, H * 0.12 + u * 0.04), u * 0.05, C(0xE0E8FF), glow: 0.6)
    default: disc(c, P(W * 0.62, H * 0.16), u * 0.07, C(0xFFD8A0).alpha(0.5), glow: 0.5)
    }
    // Mesas far off, hazed into the sky.
    for (t, w, h) in [(0.1, 0.34, 0.16), (0.82, 0.4, 0.2), (0.5, 0.18, 0.08)] as [(CGFloat, CGFloat, CGFloat)] {
        let x = W * t, ww = u * w, hh = u * h
        let p = polygon([P(x - ww / 2, horizon + 4), P(x - ww * 0.36, horizon - hh * 0.85), P(x - ww * 0.3, horizon - hh), P(x + ww * 0.28, horizon - hh), P(x + ww * 0.34, horizon - hh * 0.8), P(x + ww / 2, horizon + 4)], round: u * 0.006)
        let col = k.far.mix(k.haze, 0.55)
        layer(c, p, col, col.lit(-0.1), horizon - hh, horizon)
        c.with { c.clip(p); c.fill(CGPath(rect: CGRect(x: x + ww * 0.05, y: horizon - hh, width: ww, height: hh), transform: nil), k.deep.alpha(0.12)) }
        for i in 1...3 { c.fill(CGPath(rect: CGRect(x: x - ww / 2, y: horizon - hh + hh * CGFloat(i) * 0.24, width: ww, height: max(0.6, u * 0.002)), transform: nil), k.deep.alpha(0.08)) }
    }
    hazeBand(c, s, y: horizon, h: u * 0.05, k.haze, 0.5)
    // Dune ranges: each a sweeping crest with a lit face and a shadow face.
    func dune(base: CGFloat, amp: CGFloat, seed: UInt64, crests: Int, lit: C, shade: C) {
        var e = Dice(seed)
        let n = crests * 2 + 1
        var tops: [CGPoint] = []
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let edge = abs(t - 0.5) * 2
            let up = i % 2 == 1
            tops.append(P(-40 + (W + 80) * t + e.range(-u * 0.03, u * 0.03), base - (up ? amp * (0.6 + 0.6 * edge) * e.range(0.8, 1.2) : amp * 0.1)))
        }
        let edgeP = smooth(tops)
        let body = edgeP.mutableCopy()!
        body.addLine(to: P(W + 40, H + 10)); body.addLine(to: P(-40, H + 10)); body.closeSubpath()
        layer(c, body, lit, lit.lit(-0.25), base - amp, H)
        // Shadow faces: the leeward side of each crest.
        c.with {
            c.clip(body)
            for i in stride(from: 1, through: n, by: 2) {
                let top = tops[i], next = tops[min(i + 1, n)]
                // The leeward face: from the crest, a curve sweeping down and right, closed along the edge.
                let reach = max(next.x - top.x, u * 0.1)
                let sh = CGMutablePath()
                sh.move(to: P(top.x, top.y - 2))
                sh.addQuadCurve(to: P(top.x + reach * 1.6, H + 10), control: P(top.x + reach * 0.1, top.y + amp * 1.4))
                sh.addLine(to: P(top.x + reach * 4, H + 10))
                sh.addLine(to: next)
                sh.closeSubpath()
                c.with { c.clip(sh); c.linear(grad([(0, shade.alpha(0.6)), (1, shade.alpha(0.25))]), P(0, top.y), P(0, H)) }
            }
        }
        c.with { c.clip(body); c.stroke(edgeP, lit.lit(0.35).alpha(0.7), max(0.8, u * 0.003)) }
    }
    dune(base: horizon + u * 0.06, amp: u * 0.1, seed: 220, crests: 2, lit: k.far.mix(k.haze, 0.25), shade: k.deep.mix(k.haze, 0.3))
    hazeBand(c, s, y: horizon + u * 0.06, h: u * 0.03, k.haze, 0.25)
    // Ruined pillars on the mid dune, left side.
    for (t, h) in [(0.1, 0.22), (0.17, 0.14), (0.24, 0.07)] as [(CGFloat, CGFloat)] {
        let x = W * t, w = u * 0.035, top = horizon + u * 0.08 - u * h
        let p = CGPath(rect: CGRect(x: x - w / 2, y: top, width: w, height: u * h + u * 0.02), transform: nil)
        c.fill(p, k.near.mix(k.haze, 0.2))
        c.fill(CGPath(rect: CGRect(x: x - w / 2, y: top, width: w * 0.3, height: u * h + u * 0.02), transform: nil), k.light.alpha(0.18))
        c.fill(CGPath(rect: CGRect(x: x - w * 0.7, y: top - u * 0.012, width: w * 1.4, height: u * 0.014), transform: nil), k.near.mix(k.haze, 0.1))
    }
    if v == 2 {
        // Oasis: a pool catching the moon, with palms.
        let py = horizon + u * 0.15
        c.fill(ellipse(P(W * 0.66, py), u * 0.2, u * 0.03), C(0x1A3A70))
        c.fill(ellipse(P(W * 0.66, py - u * 0.003), u * 0.16, u * 0.018), C(0x3A6AB0, 0.6))
        c.fill(ellipse(P(W * 0.6, py - u * 0.004), u * 0.04, u * 0.004), C(0xE0F0FF, 0.6))
        for (dx, h, lean) in [(-0.18, 0.2, -0.3), (-0.1, 0.15, 0.2), (0.16, 0.22, 0.35)] as [(CGFloat, CGFloat, CGFloat)] {
            let b = P(W * 0.66 + u * dx, py), top = P(b.x + u * h * lean * 0.5, b.y - u * h)
            c.stroke(quad(b, P(b.x + u * h * lean * 0.1, b.y - u * h * 0.5), top), C(0x0A0A1E), u * 0.012)
            for a in stride(from: CGFloat(0), to: 360, by: 60) {
                let ang = rad(a + 20), l = u * 0.07
                let tip = P(top.x + cos(ang) * l, top.y + sin(ang) * l * 0.55 + l * 0.25)
                c.fill(taper(top, tip, width: u * 0.03, at: 0.4), C(0x0A0E22))
            }
        }
    }
    dune(base: H - max(u * 0.2, H * 0.12), amp: u * 0.12, seed: 230, crests: 2, lit: k.near, shade: k.deep)
    // The landmark: a lamp half buried at the near dune's foot, glinting.
    let lm = landmarkSpot(.dunes, s)
    let lr = u * 0.045
    c.glow(k.accent, P(lm.x, lm.y), lr * 4, 0.45)
    let lamp = CGMutablePath()
    lamp.addEllipse(in: CGRect(x: lm.x - lr, y: lm.y - lr * 0.45, width: lr * 2, height: lr * 0.9))
    lamp.addPath(taper(P(lm.x + lr * 0.8, lm.y - lr * 0.1), P(lm.x + lr * 2.1, lm.y - lr * 0.55), width: lr * 0.35, at: 0.2))
    lamp.addEllipse(in: CGRect(x: lm.x - lr * 0.35, y: lm.y - lr * 0.75, width: lr * 0.7, height: lr * 0.4))
    layer(c, lamp, C(0xFFE08A), C(0xB0701A), lm.y - lr, lm.y + lr * 0.5)
    c.stroke(quad(P(lm.x - lr * 0.9, lm.y - lr * 0.2), P(lm.x - lr * 1.7, lm.y - lr * 0.1), P(lm.x - lr * 0.9, lm.y + lr * 0.3)), C(0xC08020), lr * 0.18)
    c.fill(ellipse(P(lm.x, lm.y + lr * 0.4), lr * 1.6, lr * 0.32), k.near.lit(-0.05))
    flare(c, P(lm.x - lr * 0.3, lm.y - lr * 0.35), u * 0.04, k.accent, 0.9)
    // Wind ripples on the near sand.
    var r = Dice(240)
    let floor = H - max(u * 0.2, H * 0.12)
    for _ in 0..<max(8, Int(W / 60)) {
        let x = r.range(0, W), y = r.range(floor + u * 0.02, H), w = u * r.range(0.08, 0.16)
        c.stroke(quad(P(x - w, y), P(x, y - u * 0.012), P(x + w, y)), k.deep.alpha(0.3), max(0.7, u * 0.003))
    }
    switch v {
    case 3:
        streaks(c, s, seed: 250, k.haze.lit(0.2).alpha(0.22), count: max(80, Int(W * H / 3000)), len: u * 0.12, angle: 80, width: max(0.8, u * 0.003))
        hazeBand(c, s, y: H * 0.45, h: H * 0.35, k.haze, 0.35)
    case 2: motes(c, s, seed: 251, C(0xA0E8FF), count: 14, in: CGRect(x: 0, y: horizon, width: W, height: H - horizon), size: u * 0.002...u * 0.003)
    default: motes(c, s, seed: 252, k.light, count: 20, in: CGRect(x: 0, y: H * 0.2, width: W, height: H * 0.7), size: u * 0.0012...u * 0.0025, glow: 0.2)
    }
    calmCentre(c, s, k.haze.lit(-0.4), 0.2)
    vignette(c, s, 0.45)
}

