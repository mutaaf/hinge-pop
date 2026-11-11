import CoreGraphics
import Foundation

// Storm, crystal, haunted and circuit. See Biomes.swift for the rules every painter follows.

// MARK: - Storm: Thunderhead (caped heroes and storm gods)

func drawStorm(_ c: CGContext, _ s: CGSize, _ v: Int) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    let horizon = H - max(u * 0.3, H * 0.2)
    let looks: [Look] = [
        // Night storm, Bolt alley, Cape gale, Hammerfall sunset.
        Look(top: C(0x070A24), mid: C(0x16245A), low: C(0x2E4A8A), haze: C(0x3A5AA0), far: C(0x1E2C5A), near: C(0x121A3A), deep: C(0x080C1E), light: C(0xA8D8FF), accent: C(0x7AD8FF), night: 1),
        Look(top: C(0x0E0626), mid: C(0x2E1260), low: C(0x6A2A9A), haze: C(0x6A3AA8), far: C(0x34185E), near: C(0x200C40), deep: C(0x0E0420), light: C(0xF0B8FF), accent: C(0xE07AFF), night: 0.8),
        Look(top: C(0x1A2A3A), mid: C(0x3A5868), low: C(0x7A9AA0), haze: C(0x6A8A98), far: C(0x3A5060), near: C(0x22343E), deep: C(0x101A22), light: C(0xE8F4FF), accent: C(0xB8F0FF), night: 0.2),
        Look(top: C(0x120814), mid: C(0x4A1424), low: C(0xC8482A), haze: C(0x8A2A30), far: C(0x4A1A26), near: C(0x2A0E18), deep: C(0x12060A), light: C(0xFFC890), accent: C(0xFFB060), night: 0.5),
    ]
    let k = looks[v]
    backdrop(c, s) { c in
        sky(c, s, k, horizon: horizon)
        c.fill(CGPath(rect: CGRect(x: 0, y: horizon, width: W, height: H - horizon), transform: nil), k.near)
        c.blob(softGrad(k.low.lit(0.15), 0.5), P(W * 0.5, horizon), max(W, u) * 0.8, u * 0.22)
    }
    if v == 0 { stars(c, CGSize(width: W, height: H * 0.45), seed: 401, density: 0.0005, tints: [C(0xFFFFFF)], maxR: 1, keepOut: 0.2) }
    // Thunderheads: dark heaps across the top, lit underneath by the bolts.
    let cloud = k.far.lit(0.05), cloudLit = k.haze.mix(k.light, 0.25)
    var d = Dice(410)
    let banks = max(4, Int(W / (u * 0.3)))
    for i in 0...banks {
        let t = CGFloat(i) / CGFloat(banks)
        let x = W * t + d.range(-u * 0.05, u * 0.05)
        puff(c, P(x, H * 0.05 + u * d.range(0.02, 0.07)), w: u * d.range(0.5, 0.7), h: u * d.range(0.16, 0.22), body: cloud, shade: k.deep.alpha(0.9), lit: cloudLit.alpha(0.55), seed: UInt64(420 + i), flat: false)
    }
    c.linear(grad([(0, k.top.alpha(0.9)), (0.5, k.top.alpha(0.3)), (1, k.top.alpha(0))]), P(0, 0), P(0, H * 0.05 + u * 0.22))
    // A lower, lighter cloud shelf at the sides.
    for (x, y, w) in [(0.0, 0.3, 0.6), (1.0, 0.36, 0.55)] as [(CGFloat, CGFloat, CGFloat)] {
        puff(c, P(W * x, H * y), w: u * w, h: u * 0.12, body: k.far.mix(k.haze, 0.35).alpha(0.85), shade: k.far.alpha(0.6), lit: cloudLit.alpha(0.4), seed: UInt64(430 + Int(x * 10)), flat: false)
    }
    // The landmark: the brightest bolt, out of the thunderhead on the right.
    let lm = landmarkSpot(.storm, s)
    bolt(c, P(lm.x - u * 0.03, lm.y - u * 0.13), P(lm.x + u * 0.04, lm.y + u * 0.16), seed: 440, width: u * 0.012, k.accent, glow: 1.1)
    c.glow(.white, P(lm.x - u * 0.03, lm.y - u * 0.12), u * 0.05, 0.9)
    // Smaller, dimmer bolts elsewhere.
    if v != 2 {
        bolt(c, P(W * 0.14, H * 0.12), P(W * 0.08, H * 0.12 + u * 0.24), seed: 441, width: u * 0.006, k.accent.alpha(0.8), glow: 0.4)
    }
    // Far crags with the hero's lookout: a tall spire at the left, a small caped figure on top.
    let far = ridge(s, base: horizon, amp: u * 0.18, seed: 450, bumps: 3, jag: 0.25, lift: 0.9)
    layer(c, far, k.far.mix(k.haze, 0.4), k.far, horizon - u * 0.25, horizon)
    hazeBand(c, s, y: horizon, h: u * 0.05, k.haze, 0.35)
    let sx = W * 0.2, sb = horizon + u * 0.04, sh = max(u * 0.42, (horizon - H * 0.42))
    let bw = max(u * 0.16, sh * 0.32)
    let spire = polygon([P(sx - bw, sb), P(sx - bw * 0.7, sb - sh * 0.3), P(sx - bw * 0.42, sb - sh * 0.38), P(sx - bw * 0.38, sb - sh * 0.7), P(sx - bw * 0.2, sb - sh * 0.78), P(sx - u * 0.025, sb - sh), P(sx + u * 0.035, sb - sh), P(sx + bw * 0.22, sb - sh * 0.82), P(sx + bw * 0.3, sb - sh * 0.55), P(sx + bw * 0.55, sb - sh * 0.45), P(sx + bw * 0.62, sb - sh * 0.2), P(sx + bw * 1.1, sb)], round: u * 0.008)
    layer(c, spire, k.near.mix(k.haze, 0.15), k.near, sb - sh, sb)
    c.with { c.clip(spire); c.fill(polygon([P(sx, sb - sh), P(sx + bw * 1.2, sb - sh), P(sx + bw * 1.2, sb), P(sx + u * 0.02, sb)]), k.accent.alpha(0.1)); c.stroke(spire, k.accent.alpha(0.18), max(1, u * 0.006)) }
    // The figure: an original caped silhouette, cape blowing right.
    let fx = sx + u * 0.005, fy = sb - sh
    let fh = u * 0.08
    c.fill(polygon([P(fx - fh * 0.12, fy), P(fx - fh * 0.1, fy - fh * 0.55), P(fx + fh * 0.1, fy - fh * 0.55), P(fx + fh * 0.12, fy)]), k.deep)
    c.fill(circle(P(fx, fy - fh * 0.68), fh * 0.12), k.deep)
    let capeP = CGMutablePath()
    capeP.move(to: P(fx - fh * 0.08, fy - fh * 0.55))
    capeP.addCurve(to: P(fx + fh * 0.9, fy - fh * 0.15), control1: P(fx + fh * 0.3, fy - fh * 0.75), control2: P(fx + fh * 0.6, fy - fh * 0.5))
    capeP.addCurve(to: P(fx + fh * 0.08, fy - fh * 0.1), control1: P(fx + fh * 0.6, fy - fh * 0.05), control2: P(fx + fh * 0.3, fy))
    capeP.closeSubpath()
    c.fill(capeP, v == 3 ? C(0x2A0810) : C(0x6A1020))
    c.glow(k.accent, P(fx, fy - fh * 0.4), fh * 1.5, 0.25)
    // The city below: a skyline of lit windows, in the rain.
    var b = Dice(460)
    let cityTop = H - max(u * 0.2, H * 0.13)
    var x: CGFloat = -u * 0.05
    let windows = CGMutablePath()
    let city = CGMutablePath()
    while x < W + u * 0.05 {
        let bw = u * b.range(0.06, 0.12)
        let edge = abs((x + bw / 2) / W - 0.5) * 2
        let bh = u * b.range(0.04, 0.12) * (0.6 + edge)
        city.addRect(CGRect(x: x, y: cityTop - bh, width: bw, height: H - cityTop + bh))
        if b.unit() < 0.3 { city.addRect(CGRect(x: x + bw * 0.45, y: cityTop - bh - u * 0.03, width: max(1, u * 0.004), height: u * 0.03)) }
        var wy = cityTop - bh + u * 0.015
        while wy < H {
            var wx = x + u * 0.012
            while wx < x + bw - u * 0.012 {
                if b.unit() < 0.3 { windows.addRect(CGRect(x: wx, y: wy, width: u * 0.008, height: u * 0.011)) }
                wx += u * 0.02
            }
            wy += u * 0.025
        }
        x += bw + u * b.range(0, 0.012)
    }
    c.fill(city, k.deep)
    c.fill(windows, (v == 2 ? C(0xFFE8B0) : C(0xFFD27A)).alpha(v == 2 ? 0.35 : 0.6))
    c.with { c.clip(city); c.linear(grad([(0, k.haze.alpha(0.25)), (0.3, k.haze.alpha(0))]), P(0, cityTop - u * 0.1), P(0, cityTop + u * 0.1)) }
    switch v {
    case 2: streaks(c, s, seed: 470, k.light.alpha(0.25), count: max(60, Int(W * H / 4000)), len: u * 0.18, angle: 78, width: max(0.8, u * 0.0025))
    default: streaks(c, s, seed: 471, k.light.alpha(v == 3 ? 0.12 : 0.18), count: max(120, Int(W * H / 2400)), len: u * 0.06, angle: 10, width: max(0.7, u * 0.002))
    }
    calmCentre(c, s, k.deep, 0.22)
    vignette(c, s, 0.45)
}

// MARK: - Crystal: Crystal Deep (quest fantasy)

/// A six-sided crystal: lit left face, dark right face, a bright ridge and an inner glow.
private func crystalShard(_ c: CGContext, base: CGPoint, h: CGFloat, w: CGFloat, lean: CGFloat, col: C, glow: CGFloat) {
    let tip = P(base.x + lean * h, base.y - h)
    let shoulderL = P(base.x - w / 2 + lean * h * 0.8, base.y - h * 0.8)
    let shoulderR = P(base.x + w / 2 + lean * h * 0.8, base.y - h * 0.8)
    let mid = P(base.x + w * 0.08 + lean * h * 0.8, base.y - h * 0.78)
    let bl = P(base.x - w / 2, base.y + 2), br = P(base.x + w / 2, base.y + 2), bm = P(base.x + w * 0.08, base.y + 2)
    if glow > 0 { c.glow(col, P(base.x, base.y - h * 0.45), h * 0.7, glow * 0.35) }
    c.fill(polygon([bl, shoulderL, tip, mid, bm]), col.lit(0.1))
    c.fill(polygon([bm, mid, tip, shoulderR, br]), col.lit(-0.35))
    c.fillLinear(polygon([bl, shoulderL, tip, shoulderR, br]), grad([(0, C.white.alpha(0.0)), (0.6, col.lit(0.5).alpha(0.25)), (1, C.white.alpha(0))]), P(0, base.y), P(0, base.y - h))
    c.stroke(polyline([mid, tip]), C.white.alpha(0.55), max(0.6, w * 0.04))
    c.stroke(polyline([shoulderL, tip]), C.white.alpha(0.3), max(0.5, w * 0.025))
}

func drawCrystal(_ c: CGContext, _ s: CGSize, _ v: Int) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    let floor = H - max(u * 0.14, H * 0.08)
    let looks: [Look] = [
        // Gem hollow, Cocoa caverns, Echo grotto, Rune depths.
        Look(top: C(0x080622), mid: C(0x1A1048), low: C(0x2A1A60), haze: C(0x4A3A9A), far: C(0x221650), near: C(0x140C34), deep: C(0x08041A), light: C(0x8AF0FF), accent: C(0x5AE8F0)),
        Look(top: C(0x120806), mid: C(0x2E1610), low: C(0x48261A), haze: C(0x6A3A26), far: C(0x3A2018), near: C(0x24120C), deep: C(0x100604), light: C(0xFFC070), accent: C(0xFF9A3A)),
        Look(top: C(0x041210), mid: C(0x0C2A2A), low: C(0x14403C), haze: C(0x2A6A60), far: C(0x123A36), near: C(0x0A2422), deep: C(0x041010), light: C(0xA8FFD8), accent: C(0x5AF0B0)),
        Look(top: C(0x04061A), mid: C(0x0C1440), low: C(0x14205A), haze: C(0x26388A), far: C(0x101C4A), near: C(0x0A1032), deep: C(0x040818), light: C(0xFFE08A), accent: C(0x7A9AFF), night: 1),
    ]
    let k = looks[v]
    let palettes: [[C]] = [[C(0x5AE8F0), C(0xB07AFF), C(0x6A9AFF)], [C(0xFFA040), C(0xFF7A50), C(0xFFD070)], [C(0x5AF0B0), C(0x80E0FF), C(0xC0FF90)], [C(0x7A9AFF), C(0xC08AFF), C(0x5AD0FF)]]
    let cols = palettes[v]
    backdrop(c, s) { c in
        sky(c, s, k, horizon: floor)
        c.blob(softGrad(k.accent, 0.22), P(W * 0.5, H * 0.55), max(W, u) * 0.7, H * 0.35)
        c.fill(CGPath(rect: CGRect(x: 0, y: floor, width: W, height: H - floor), transform: nil), k.deep)
    }
    // Back wall: rock shelves and glowing veins.
    var d = Dice(510)
    for i in 0..<max(5, Int(W * H / (u * u * 0.18))) {
        let x = d.range(0, W), y = d.range(H * 0.1, floor)
        let e = abs(x / W - 0.5) * 2
        guard e > 0.6 else { continue }
        var pts = [P(x, y)]
        for _ in 0..<5 { pts.append(P(pts.last!.x + d.range(-u * 0.05, u * 0.05), pts.last!.y + d.range(-u * 0.01, u * 0.06))) }
        c.stroke(polyline(pts), cols[i % 3].alpha(0.12), u * 0.012)
        c.stroke(polyline(pts), cols[i % 3].lit(0.3).alpha(0.4), max(0.6, u * 0.0025))
    }
    if v == 3 {
        // Runes: faint gold circles carved in the walls.
        for (x, y) in [(0.12, 0.38), (0.88, 0.3), (0.1, 0.62), (0.9, 0.58)] as [(CGFloat, CGFloat)] {
            let o = P(W * x, H * y), r = u * 0.05
            c.glow(k.light, o, r * 2, 0.15)
            c.stroke(circle(o, r), k.light.alpha(0.45), max(0.8, u * 0.003))
            c.stroke(polygon(starPoints(o, r * 0.8, r * 0.35, 3)), k.light.alpha(0.35), max(0.6, u * 0.002))
        }
    }
    // Cave mouth: rock walls framing both sides, stalactites from the ceiling.
    func wall(_ left: Bool) {
        var e = Dice(left ? 520 : 521)
        var pts: [CGPoint] = []
        let n = 9
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let depth = u * (0.08 + 0.1 * sin(t * .pi * 1.3 + (left ? 0 : 1))) * e.range(0.8, 1.2) + u * 0.06 * (1 - sin(t * .pi))
            pts.append(P(left ? depth : W - depth, -10 + (H + 20) * t))
        }
        let p = smooth(pts)
        p.addLine(to: P(left ? -10 : W + 10, H + 10)); p.addLine(to: P(left ? -10 : W + 10, -10)); p.closeSubpath()
        c.fillLinear(p, grad([(0, k.deep.lit(-0.3)), (1, k.near)]), P(left ? 0 : W, 0), P(left ? u * 0.2 : W - u * 0.2, 0))
        c.with {
            c.clip(p)
            c.stroke(smooth(pts), k.accent.alpha(0.35), u * 0.008)
            // Gems set in the rock.
            for _ in 0..<6 {
                let y = e.range(H * 0.1, H * 0.85), x = left ? e.range(0, u * 0.1) : W - e.range(0, u * 0.1)
                let r = u * e.range(0.008, 0.016)
                c.glow(cols[Int(e.unit() * 3) % 3], P(x, y), r * 4, 0.35)
                c.fill(polygon([P(x, y - r * 1.4), P(x + r, y), P(x, y + r * 1.4), P(x - r, y)]), cols[Int(e.unit() * 3) % 3].lit(0.3))
            }
        }
    }
    wall(true); wall(false)
    var t = Dice(530)
    let ceiling = CGMutablePath()
    var x: CGFloat = -u * 0.02
    while x < W {
        let w = u * t.range(0.04, 0.09), e = abs(x / W - 0.5) * 2
        let h = u * t.range(0.05, 0.14) * (0.5 + e)
        ceiling.addPath(polygon([P(x, -2), P(x + w, -2), P(x + w * t.range(0.4, 0.6), h)], round: w * 0.1))
        x += w * t.range(0.6, 1.0)
    }
    ceiling.addRect(CGRect(x: 0, y: -2, width: W, height: u * 0.03))
    layer(c, ceiling, k.deep, k.near.mix(k.haze, 0.2), 0, u * 0.15)
    // Mid crystals along the floor, hazed.
    var m = Dice(540)
    for i in 0..<max(6, Int(W / (u * 0.1))) {
        let x = m.range(0, W)
        let e = abs(x / W - 0.5) * 2
        let h = u * m.range(0.06, 0.12) * (0.4 + e)
        crystalShard(c, base: P(x, floor + u * 0.02), h: h, w: h * 0.4, lean: m.range(-0.25, 0.25), col: cols[i % 3].mix(k.haze, 0.45), glow: 0.3)
    }
    hazeBand(c, s, y: floor, h: u * 0.05, k.haze, 0.3)
    // The landmark: the tallest crystal, on the right, with a sword set in its top.
    let lm = landmarkSpot(.crystal, s)
    let ch = (floor - lm.y) * 2.1
    let base = P(lm.x, floor + u * 0.02)
    crystalShard(c, base: P(base.x + u * 0.07, base.y), h: ch * 0.45, w: u * 0.06, lean: 0.18, col: cols[1], glow: 0.4)
    crystalShard(c, base: P(base.x - u * 0.07, base.y), h: ch * 0.55, w: u * 0.065, lean: -0.15, col: cols[2], glow: 0.4)
    let tip = P(base.x - ch * 0.04, base.y - ch)
    // The sword, drawn first so the crystal swallows its blade.
    let hilt = P(tip.x + ch * 0.02, tip.y - ch * 0.04)
    c.fill(CGPath(rect: CGRect(x: hilt.x - u * 0.006, y: hilt.y, width: u * 0.012, height: ch * 0.25), transform: nil), C(0xE0E8F0))
    crystalShard(c, base: base, h: ch, w: u * 0.1, lean: -0.04, col: cols[0], glow: 0.7)
    c.fill(CGPath(roundedRect: CGRect(x: hilt.x - u * 0.04, y: hilt.y - u * 0.008, width: u * 0.08, height: u * 0.014), cornerWidth: u * 0.006, cornerHeight: u * 0.006, transform: nil), C(0xFFD060))
    c.fill(CGPath(rect: CGRect(x: hilt.x - u * 0.007, y: hilt.y - u * 0.06, width: u * 0.014, height: u * 0.055), transform: nil), C(0x6A3A1A))
    c.fill(circle(P(hilt.x, hilt.y - u * 0.066), u * 0.012), C(0xFFD060))
    flare(c, P(hilt.x, hilt.y - u * 0.066), u * 0.05, k.light, 0.8)
    // Near crystals and rubble at the left foot.
    crystalShard(c, base: P(W * 0.1, floor + u * 0.03), h: u * 0.22, w: u * 0.07, lean: 0.2, col: cols[1], glow: 0.4)
    crystalShard(c, base: P(W * 0.04, floor + u * 0.03), h: u * 0.15, w: u * 0.06, lean: -0.1, col: cols[0], glow: 0.3)
    let rubble = ridge(s, base: floor + u * 0.05, amp: u * 0.04, seed: 550, bumps: 6, jag: 0.4, lift: 0.5)
    layer(c, rubble, k.near, k.deep, floor, H)
    motes(c, s, seed: 560, k.accent, count: 30, in: CGRect(x: 0, y: H * 0.15, width: W, height: floor - H * 0.15), size: u * 0.0015...u * 0.0035, glow: 0.4)
    calmCentre(c, s, k.deep, 0.2)
    vignette(c, s, 0.5)
}

// MARK: - Haunted: Night Manor (haunted houses and monster movies)

private func deadTree(_ c: CGContext, root: CGPoint, h: CGFloat, col: C, seed: UInt64) {
    var d = Dice(seed)
    func branch(_ from: CGPoint, _ ang: CGFloat, _ len: CGFloat, _ w: CGFloat, _ depth: Int) {
        let mid = P(from.x + cos(ang) * len * 0.5 + d.range(-len, len) * 0.12, from.y - sin(ang) * len * 0.5)
        let to = P(from.x + cos(ang) * len, from.y - sin(ang) * len)
        c.stroke(quad(from, mid, to), col, w)
        guard depth > 0 else { return }
        branch(to, ang + d.range(0.3, 0.7), len * d.range(0.55, 0.75), w * 0.62, depth - 1)
        branch(to, ang - d.range(0.3, 0.7), len * d.range(0.55, 0.75), w * 0.62, depth - 1)
    }
    branch(root, .pi / 2 + d.range(-0.1, 0.1), h * 0.42, h * 0.07, 4)
}

func drawHaunted(_ c: CGContext, _ s: CGSize, _ v: Int) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    let horizon = H - max(u * 0.3, H * 0.2)
    let looks: [Look] = [
        // Creaky night (green moon), Cobweb dusk, Organ-hall crimson, Graveyard fog.
        Look(top: C(0x080616), mid: C(0x1E1440), low: C(0x3A2A5A), haze: C(0x5A6A6A), far: C(0x221A3A), near: C(0x120C22), deep: C(0x06040E), light: C(0xD8FFC0), accent: C(0x8AFF7A), night: 1),
        Look(top: C(0x140A1E), mid: C(0x4A2440), low: C(0xA05A4A), haze: C(0x8A5A5A), far: C(0x3A2030), near: C(0x22101C), deep: C(0x0E060C), light: C(0xFFC080), accent: C(0xFFA040), night: 0.5),
        Look(top: C(0x0E0410), mid: C(0x3A0A20), low: C(0x6A1A2A), haze: C(0x6A2A3A), far: C(0x2E0C1C), near: C(0x180610), deep: C(0x080206), light: C(0xFF8A8A), accent: C(0xFF5A6A), night: 1),
        Look(top: C(0x04080E), mid: C(0x101E2E), low: C(0x2A3E50), haze: C(0x6A808E), far: C(0x182634), near: C(0x0C141E), deep: C(0x04080C), light: C(0xD0E4FF), accent: C(0x9AC8FF), night: 1),
    ]
    let k = looks[v]
    backdrop(c, s) { c in
        sky(c, s, k, horizon: horizon)
        c.fill(CGPath(rect: CGRect(x: 0, y: horizon, width: W, height: H - horizon), transform: nil), k.near)
    }
    if k.night > 0.6 { stars(c, CGSize(width: W, height: horizon * 0.6), seed: 601, density: 0.0007, tints: [C(0xFFFFFF), k.light], maxR: 1, keepOut: 0.2) }
    // The moon, big and low over the manor's shoulder, with cloud wisps across it.
    let mo = P(W * 0.62, H * 0.17 + u * 0.03), mr = u * (v == 2 ? 0.1 : 0.085)
    moon(c, mo, mr, v == 1 ? C(0xFFD8A0) : k.light, glow: 0.8)
    for (dy, w) in [(0.4, 1.0), (-0.1, 0.7), (1.3, 1.3)] as [(CGFloat, CGFloat)] {
        c.blob(softGrad(k.top, 0.3), P(mo.x - mr * 0.5, mo.y + mr * dy), mr * 3 * w, mr * 0.35)
    }
    // Bats crossing the moon.
    var bd = Dice(610)
    for _ in 0..<5 {
        let at = P(mo.x + bd.range(-mr * 3, mr * 2), mo.y + bd.range(-mr * 1.5, mr * 1.8)), w = u * bd.range(0.012, 0.022)
        let bat = CGMutablePath()
        bat.move(to: at)
        bat.addQuadCurve(to: P(at.x - w, at.y - w * 0.4), control: P(at.x - w * 0.5, at.y - w * 0.6))
        bat.addQuadCurve(to: P(at.x - w * 0.3, at.y + w * 0.05), control: P(at.x - w * 0.65, at.y + w * 0.05))
        bat.addQuadCurve(to: P(at.x + w * 0.3, at.y + w * 0.05), control: P(at.x, at.y - w * 0.15))
        bat.addQuadCurve(to: P(at.x + w, at.y - w * 0.4), control: P(at.x + w * 0.65, at.y + w * 0.05))
        bat.addQuadCurve(to: at, control: P(at.x + w * 0.5, at.y - w * 0.6))
        c.fill(bat, k.deep)
    }
    // Far hills, then the manor's hill on the right.
    layer(c, ridge(s, base: horizon - u * 0.02, amp: u * 0.08, seed: 620, bumps: 2, lift: 0.6), k.far.mix(k.haze, 0.3), k.far, horizon - u * 0.12, horizon)
    hazeBand(c, s, y: horizon, h: u * 0.06, k.haze, 0.3)
    let lm = landmarkSpot(.haunted, s)
    let mx = lm.x, floorY = lm.y + u * 0.13
    let hillP = CGMutablePath()
    hillP.move(to: P(mx - u * 0.6, horizon + u * 0.12))
    hillP.addCurve(to: P(mx + u * 0.6, horizon + u * 0.1), control1: P(mx - u * 0.25, floorY - u * 0.02), control2: P(mx + u * 0.25, floorY - u * 0.02))
    hillP.addLine(to: P(mx + u * 0.6, H + 10)); hillP.addLine(to: P(mx - u * 0.6, H + 10)); hillP.closeSubpath()
    // The manor: a main block, two towers with spires, gables, chimneys. Windows are dark but one.
    let m = CGMutablePath()
    let bw = u * 0.3, bh = u * 0.16
    m.addRect(CGRect(x: mx - bw / 2, y: floorY - bh, width: bw, height: bh + u * 0.02))
    m.addPath(polygon([P(mx - bw * 0.55, floorY - bh), P(mx, floorY - bh - u * 0.1), P(mx + bw * 0.55, floorY - bh)]))
    for (dx, tw, th) in [(-0.5, 0.075, 0.27), (0.42, 0.06, 0.22)] as [(CGFloat, CGFloat, CGFloat)] {
        let tx = mx + bw * dx
        m.addRect(CGRect(x: tx - u * tw / 2, y: floorY - u * th, width: u * tw, height: u * th))
        m.addPath(polygon([P(tx - u * tw * 0.7, floorY - u * th), P(tx, floorY - u * th - u * 0.1), P(tx + u * tw * 0.7, floorY - u * th)]))
    }
    m.addRect(CGRect(x: mx + bw * 0.15, y: floorY - bh - u * 0.1, width: u * 0.018, height: u * 0.06))
    m.addRect(CGRect(x: mx - bw * 0.2, y: floorY - bh - u * 0.085, width: u * 0.016, height: u * 0.05))
    c.fill(m, k.deep.lit(0.04))
    c.with { c.clip(m); c.linear(grad([(0, k.light.alpha(0.12)), (1, k.light.alpha(0))]), P(mo.x, mo.y), P(mx, floorY)) }
    // Dark windows.
    let wins = CGMutablePath()
    for row in 0..<2 {
        for col in 0..<5 where !(row == 0 && col == 3) {
            let wx = mx - bw / 2 + bw * (CGFloat(col) + 0.5) / 5, wy = floorY - bh + u * 0.03 + CGFloat(row) * u * 0.06
            wins.addPath(CGPath(roundedRect: CGRect(x: wx - u * 0.012, y: wy, width: u * 0.024, height: u * 0.034), cornerWidth: u * 0.012, cornerHeight: u * 0.01, transform: nil))
        }
    }
    c.fill(wins, k.far.mix(k.haze, 0.2).alpha(0.7))
    // The landmark: the one lit window.
    let lit = v == 2 ? C(0xFFB0A0) : C(0xFFD27A)
    c.glow(lit, P(lm.x, lm.y), u * 0.09, 0.6)
    let win = CGRect(x: lm.x - u * 0.016, y: lm.y - u * 0.022, width: u * 0.032, height: u * 0.044)
    c.fill(CGPath(roundedRect: win, cornerWidth: u * 0.016, cornerHeight: u * 0.012, transform: nil), lit)
    c.fill(CGPath(rect: CGRect(x: lm.x - u * 0.0015, y: win.minY, width: u * 0.003, height: win.height), transform: nil), k.deep)
    c.fill(CGPath(rect: CGRect(x: win.minX, y: lm.y - u * 0.0015, width: win.width, height: u * 0.003), transform: nil), k.deep)
    // A watching silhouette in the window: just a head and shoulders.
    c.fill(circle(P(lm.x + u * 0.004, lm.y + u * 0.004), u * 0.006), k.deep.alpha(0.6))
    layer(c, hillP, k.near.lit(0.05), k.deep, floorY, H)
    // Dead trees on the left, one big and one small.
    deadTree(c, root: P(W * 0.08, H - max(u * 0.15, H * 0.09)), h: u * 0.62, col: k.deep, seed: 630)
    deadTree(c, root: P(W * 0.3, horizon + u * 0.06), h: u * 0.22, col: k.near.mix(k.haze, 0.2), seed: 631)
    // Graveyard: tombstones and an iron fence at the front.
    var g = Dice(640)
    let front = H - max(u * 0.12, H * 0.075)
    let stones = CGMutablePath()
    for _ in 0..<(v == 3 ? 9 : 5) {
        let x = g.range(0, W), w = u * g.range(0.03, 0.05), h = u * g.range(0.04, 0.07)
        guard abs(x / W - 0.5) > 0.12 else { continue }
        stones.addPath(CGPath(roundedRect: CGRect(x: x - w / 2, y: front - h, width: w, height: h + u * 0.03), cornerWidth: w / 2, cornerHeight: w / 2.5, transform: nil))
    }
    c.fill(stones, k.near.mix(k.haze, 0.15))
    let ground = ridge(s, base: front + u * 0.02, amp: u * 0.025, seed: 650, bumps: 4, lift: 0.3)
    layer(c, ground, k.deep.lit(0.05), k.deep, front, H)
    let fence = CGMutablePath()
    var fx: CGFloat = 0
    while fx < W {
        fence.addRect(CGRect(x: fx, y: front + u * 0.005 - u * 0.07, width: max(1, u * 0.005), height: u * 0.08))
        fence.addPath(polygon([P(fx - u * 0.006, front - u * 0.065), P(fx + u * 0.0025, front - u * 0.08), P(fx + u * 0.011, front - u * 0.065)]))
        fx += u * 0.035
    }
    fence.addRect(CGRect(x: 0, y: front - u * 0.05, width: W, height: max(1, u * 0.004)))
    fence.addRect(CGRect(x: 0, y: front - u * 0.015, width: W, height: max(1, u * 0.004)))
    c.fill(fence, k.deep.alpha(0.9))
    // Fog rolling over the ground; thick in the graveyard variant.
    hazeBand(c, s, y: front - u * 0.02, h: u * (v == 3 ? 0.1 : 0.05), k.haze, v == 3 ? 0.5 : 0.3)
    if v == 1 {
        // Cobwebs in the top corners.
        for left in [true, false] {
            let o = P(left ? 0 : W, 0), r = u * 0.28
            let web = CGMutablePath()
            for i in 0...5 {
                let a = rad(CGFloat(i) * 18) * (left ? 1 : -1) + (left ? 0 : .pi)
                web.move(to: o); web.addLine(to: P(o.x + cos(a) * r, o.y + sin(abs(a - (left ? 0 : .pi))) * r))
            }
            for ring in 1...4 {
                let rr = r * CGFloat(ring) / 4.5
                var pts: [CGPoint] = []
                for i in 0...5 {
                    let a = rad(CGFloat(i) * 18)
                    pts.append(P(o.x + (left ? 1 : -1) * cos(a) * rr, o.y + sin(a) * rr))
                }
                for j in 0..<(pts.count - 1) {
                    let a = pts[j], b = pts[j + 1]
                    web.move(to: a); web.addQuadCurve(to: b, control: P((a.x + b.x) / 2 - (left ? 1 : -1) * rr * 0.04, (a.y + b.y) / 2 - rr * 0.04))
                }
            }
            c.stroke(web, C(0xE8E0F0, 0.28), max(0.6, u * 0.002))
        }
    }
    motes(c, s, seed: 660, k.accent, count: 14, in: CGRect(x: 0, y: horizon, width: W, height: H - horizon), size: u * 0.002...u * 0.0035, glow: 0.45)
    calmCentre(c, s, k.deep, 0.2)
    vignette(c, s, 0.5)
}

// MARK: - Circuit: Circuit City (neon noir, heists and arcades)

func drawCircuit(_ c: CGContext, _ s: CGSize, _ v: Int) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    let street = H - max(u * 0.2, H * 0.13)
    let looks: [Look] = [
        // Rainy neon, Pixel plaza, Data stream, Heist alarm.
        Look(top: C(0x05041A), mid: C(0x140A3A), low: C(0x3A1260), haze: C(0x4A2A8A), far: C(0x1A1446), near: C(0x0C0A26), deep: C(0x050412), light: C(0x5AF0FF), accent: C(0xFF3AC8), night: 1),
        Look(top: C(0x0E0524), mid: C(0x2A0E50), low: C(0x5A1A7A), haze: C(0x6A2A9A), far: C(0x2A1450), near: C(0x160A30), deep: C(0x080418), light: C(0xFFE04A), accent: C(0xB05AFF), night: 1),
        Look(top: C(0x020A08), mid: C(0x06201A), low: C(0x0A3A2A), haze: C(0x1A5A40), far: C(0x0A2A20), near: C(0x061A14), deep: C(0x020A08), light: C(0x5AFF9A), accent: C(0x3AE8C0), night: 1),
        Look(top: C(0x0A0410), mid: C(0x2A0818), low: C(0x4A0C20), haze: C(0x5A1A2A), far: C(0x240A18), near: C(0x14060E), deep: C(0x080206), light: C(0x5AA0FF), accent: C(0xFF3A3A), night: 1),
    ]
    let k = looks[v]
    backdrop(c, s) { c in
        sky(c, s, k, horizon: street)
        c.blob(softGrad(k.accent, 0.3), P(W * 0.5, street - u * 0.05), max(W, u) * 0.8, u * 0.3)
    }
    // Far skyline: hazed towers with tiny windows.
    func skyline(top: CGFloat, hRange: ClosedRange<CGFloat>, col: C, winCol: C, winA: CGFloat, seed: UInt64, sideBias: CGFloat) {
        var e = Dice(seed)
        var x: CGFloat = -u * 0.05
        let body = CGMutablePath(), wins = CGMutablePath()
        while x < W + u * 0.05 {
            let bw = u * e.range(0.07, 0.14)
            let edge = abs((x + bw / 2) / W - 0.5) * 2
            let bh = u * e.range(hRange.lowerBound, hRange.upperBound) * (1 - sideBias + sideBias * edge * 1.6)
            body.addRect(CGRect(x: x, y: top - bh, width: bw, height: H - top + bh))
            var wy = top - bh + u * 0.02
            while wy < top {
                var wx = x + u * 0.01
                while wx < x + bw - u * 0.01 { if e.unit() < 0.35 { wins.addRect(CGRect(x: wx, y: wy, width: u * 0.006, height: u * 0.006)) }; wx += u * 0.014 }
                wy += u * 0.016
            }
            x += bw + u * e.range(0.0, 0.01)
        }
        c.fill(body, col)
        c.fill(wins, winCol.alpha(winA))
    }
    skyline(top: street, hRange: 0.2...0.45, col: k.far.mix(k.haze, 0.4), winCol: k.light, winA: 0.3, seed: 720, sideBias: 0.3)
    hazeBand(c, s, y: street - u * 0.05, h: u * 0.12, k.haze, 0.35)
    skyline(top: street, hRange: 0.1...0.3, col: k.far, winCol: C(0xFFD8A0), winA: 0.4, seed: 721, sideBias: 0.7)
    // Near towers on both sides, edged in neon.
    for left in [true, false] {
        let w = u * 0.22, x = left ? -u * 0.02 : W - u * 0.2
        let top = street - max(u * 0.75, (street - H * 0.25))
        let p = CGPath(rect: CGRect(x: x, y: top, width: w, height: H - top), transform: nil)
        c.fill(p, k.near)
        let edgeX = left ? x + w : x
        c.stroke(polyline([P(edgeX, top), P(edgeX, street)]), k.accent.alpha(0.25), u * 0.012)
        c.stroke(polyline([P(edgeX, top), P(edgeX, street)]), k.accent.lit(0.4).alpha(0.8), max(0.8, u * 0.003))
        // Window bands and a vertical neon strip.
        var e = Dice(left ? 730 : 731)
        var y = top + u * 0.03
        let wins = CGMutablePath()
        while y < street - u * 0.02 {
            var wx = x + u * 0.02
            while wx < x + w - u * 0.02 { if e.unit() < 0.4 { wins.addRect(CGRect(x: wx, y: y, width: u * 0.018, height: u * 0.01)) }; wx += u * 0.03 }
            y += u * 0.03
        }
        c.fill(wins, k.light.alpha(0.18))
        if !left {
            let sx = x + u * 0.04, sy = top + u * 0.12
            let strip = CGPath(roundedRect: CGRect(x: sx, y: sy, width: u * 0.035, height: u * 0.28), cornerWidth: u * 0.008, cornerHeight: u * 0.008, transform: nil)
            c.glow(k.light, P(sx + u * 0.017, sy + u * 0.14), u * 0.16, 0.25)
            c.stroke(strip, k.light, max(1, u * 0.004))
            for i in 0..<5 { c.fill(CGPath(rect: CGRect(x: sx + u * 0.009, y: sy + u * 0.025 + CGFloat(i) * u * 0.05, width: u * 0.017, height: u * 0.025), transform: nil), k.light.alpha(0.7)) }
        }
    }
    // The landmark: the flickering arcade sign on the left tower, a pixel critter in a neon frame.
    let lm = landmarkSpot(.circuit, s)
    let sw = u * 0.16, sh = u * 0.11
    let frame = CGRect(x: lm.x - sw / 2, y: lm.y - sh / 2, width: sw, height: sh)
    c.glow(k.accent, P(lm.x, lm.y), u * 0.2, 0.45)
    c.fill(CGPath(roundedRect: frame, cornerWidth: u * 0.012, cornerHeight: u * 0.012, transform: nil), k.deep)
    c.stroke(CGPath(roundedRect: frame, cornerWidth: u * 0.012, cornerHeight: u * 0.012, transform: nil), k.accent.alpha(0.35), u * 0.012)
    c.stroke(CGPath(roundedRect: frame, cornerWidth: u * 0.012, cornerHeight: u * 0.012, transform: nil), k.accent.lit(0.5), max(1, u * 0.004))
    let critter = ["..X.X..", ".XXXXX.", "XX.X.XX", "XXXXXXX", ".X...X.", "X.....X"]
    let px = u * 0.011
    let gx = lm.x - px * 3.5, gy = lm.y - px * 3
    let pix = CGMutablePath()
    for (r, row) in critter.enumerated() { for (q, ch) in row.enumerated() where ch == "X" { pix.addRect(CGRect(x: gx + CGFloat(q) * px, y: gy + CGFloat(r) * px, width: px * 0.9, height: px * 0.9)) } }
    c.glow(k.light, P(lm.x, lm.y), u * 0.06, 0.5)
    c.fill(pix, k.light.lit(0.3))
    // A dead tube in the frame: the flicker.
    c.stroke(polyline([P(frame.maxX - u * 0.002, frame.minY + sh * 0.3), P(frame.maxX - u * 0.002, frame.maxY - sh * 0.2)]), k.deep, max(1.2, u * 0.006))
    // Wet street: reflections of the neon, then circuit traces in the paving.
    c.with {
        c.clip(to: CGRect(x: 0, y: street, width: W, height: H - street))
        c.linear(grad([(0, k.near.lit(0.05)), (1, k.deep)]), P(0, street), P(0, H))
        for (x, col) in [(lm.x, k.accent), (W - u * 0.12, k.light), (W * 0.5, k.accent.mix(k.light, 0.5))] as [(CGFloat, C)] {
            c.blob(softGrad(col, 0.35), P(x, street + u * 0.02), u * 0.06, (H - street) * 0.9)
        }
        var e = Dice(740)
        let traces = CGMutablePath(), pads = CGMutablePath()
        for _ in 0..<max(10, Int(W / 35)) {
            var p = P(e.range(0, W), e.range(street + u * 0.02, H))
            traces.move(to: p); pads.addPath(circle(p, u * 0.005))
            for _ in 0..<3 {
                let horiz = e.unit() < 0.6
                let l = u * e.range(0.04, 0.12)
                let q = horiz ? P(p.x + (e.unit() < 0.5 ? -l : l), p.y) : P(p.x + l * 0.5, p.y + l * 0.5)
                traces.addLine(to: q); p = q
            }
            pads.addPath(circle(p, u * 0.005))
        }
        c.stroke(traces, k.light.alpha(0.25), max(0.8, u * 0.003))
        c.fill(pads, k.light.alpha(0.5))
    }
    c.fill(CGPath(rect: CGRect(x: 0, y: street, width: W, height: max(1, u * 0.003)), transform: nil), k.accent.alpha(0.6))
    switch v {
    case 2:
        // Data stream: falling columns of light.
        var e = Dice(750)
        for _ in 0..<max(14, Int(W / 25)) {
            let x = e.range(0, W), y = e.range(0, street), l = u * e.range(0.08, 0.2)
            guard abs(x / W - 0.5) > 0.2 else { continue }
            c.fillLinear(CGPath(rect: CGRect(x: x, y: y, width: max(1, u * 0.004), height: l), transform: nil), grad([(0, k.light.alpha(0)), (1, k.light.alpha(0.5))]), P(0, y), P(0, y + l))
        }
    case 3:
        c.glow(k.accent, P(0, 0), u * 0.6, 0.25); c.glow(k.light, P(W, 0), u * 0.6, 0.2)
        streaks(c, s, seed: 751, C(0xC8D0FF, 0.16), count: max(100, Int(W * H / 3000)), len: u * 0.06, angle: 8, width: max(0.7, u * 0.002))
    case 1:
        motes(c, s, seed: 752, k.light, count: 20, in: CGRect(x: 0, y: 0, width: W, height: street), size: u * 0.002...u * 0.004, glow: 0.3)
    default:
        streaks(c, s, seed: 753, C(0xC8D8FF, 0.2), count: max(140, Int(W * H / 2200)), len: u * 0.07, angle: 6, width: max(0.7, u * 0.002))
    }
    calmCentre(c, s, k.deep, 0.24)
    vignette(c, s, 0.45)
}
