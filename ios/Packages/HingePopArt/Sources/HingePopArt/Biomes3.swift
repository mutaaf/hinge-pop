import CoreGraphics
import Foundation

// Jungle, clouds and clockwork. See Biomes.swift for the rules every painter follows.

// MARK: - Jungle: Wild Temple (treasure-hunting serials)

/// A broad leaf on a curved stem, with a midrib. Hangs from the screen edges.
private func leaf(_ c: CGContext, _ a: CGPoint, _ b: CGPoint, width w: CGFloat, col: C, rib: C) {
    c.fill(taper(a, b, width: w, at: 0.45), col)
    c.stroke(quad(a, P((a.x + b.x) / 2 + w * 0.08, (a.y + b.y) / 2 - w * 0.08), b), rib, max(0.6, w * 0.05))
}

func drawJungle(_ c: CGContext, _ s: CGSize, _ v: Int) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    let floor = H - max(u * 0.1, H * 0.06)
    let looks: [Look] = [
        // Green noon, Golden idol afternoon, Misty dusk, Firefly night.
        Look(top: C(0x0E3A3A), mid: C(0x1E6A58), low: C(0x8ACB8A), haze: C(0x6AB89A), far: C(0x2A6A58), near: C(0x123A2E), deep: C(0x061A14), light: C(0xF0FFC0), accent: C(0xC8FF7A)),
        Look(top: C(0x2A2A1A), mid: C(0x7A6A2A), low: C(0xE8B860), haze: C(0xC8A060), far: C(0x5A5A2A), near: C(0x2A3018), deep: C(0x10140A), light: C(0xFFE0A0), accent: C(0xFFC040)),
        Look(top: C(0x0E1A2A), mid: C(0x2A4A5A), low: C(0x7A9A9A), haze: C(0x7A9A9A), far: C(0x2A4A4A), near: C(0x142826), deep: C(0x08120E), light: C(0xD8F0E8), accent: C(0x8AE8D0), night: 0.3),
        Look(top: C(0x020812), mid: C(0x082030), low: C(0x14384A), haze: C(0x24485A), far: C(0x0E2A30), near: C(0x081A1C), deep: C(0x020A0A), light: C(0xC8E8FF), accent: C(0xE0FF6A), night: 1),
    ]
    let k = looks[v]
    backdrop(c, s) { c in
        sky(c, s, k, horizon: floor)
        c.blob(softGrad(k.light, k.night > 0.5 ? 0.12 : 0.4), P(W * 0.5, H * 0.08), max(W, u) * 0.6, H * 0.35)
    }
    if k.night > 0.5 {
        stars(c, CGSize(width: W, height: H * 0.3), seed: 801, density: 0.0006, tints: [C(0xFFFFFF)], maxR: 1, keepOut: 0.2)
        moon(c, P(W * 0.3, H * 0.1), u * 0.04, k.light, glow: 0.5)
    } else {
        // Light shafts through the canopy.
        for (x, a) in [(0.36, 0.1), (0.52, 0.07), (0.66, 0.08)] as [(CGFloat, CGFloat)] {
            beam(c, from: P(W * x, -u * 0.05), angle: .pi / 2 + 0.12, length: H * 0.9, spread: 0.07, k.light, a)
        }
    }
    // Far jungle: rounded tree crowns in layers, each hazier than the last.
    for (i, (base, amp, haze)) in ([(0.42, 0.14, 0.6), (0.55, 0.16, 0.4), (0.68, 0.18, 0.2)] as [(CGFloat, CGFloat, CGFloat)]).enumerated() {
        let y = floor - u * (0.42 - base * 0.4) - (H - u) * 0.12 * (1 - base)
        let crowns = CGMutablePath()
        var e = Dice(UInt64(810 + i))
        var x: CGFloat = -u * 0.05
        while x < W + u * 0.05 {
            let edge = abs(x / W - 0.5) * 2
            let r = u * e.range(0.05, 0.09) * (1 + edge * 0.6)
            crowns.addPath(circle(P(x, y - edge * u * amp * 1.4 + e.range(-1, 1) * u * 0.02), r))
            x += r * 1.2
        }
        crowns.addRect(CGRect(x: 0, y: y - u * 0.01, width: W, height: H))
        let col = k.far.mix(k.haze, haze * 0.7).lit(-0.05)
        layer(c, crowns, col.lit(0.05), col, y - u * 0.2, y + u * 0.2)
        hazeBand(c, s, y: y + u * 0.04, h: u * 0.05, k.haze, 0.25)
    }
    // The temple: a stepped pyramid at the bottom centre, its door the landmark.
    let lm = landmarkSpot(.jungle, s)
    let tw = u * 0.62, steps = 5, stepH = u * 0.05
    let tBase = floor + u * 0.02
    let stone = k.near.mix(C(0x8A8A6A), 0.25).mix(k.haze, 0.15)
    for i in 0..<steps {
        let w = tw * (1 - CGFloat(i) * 0.15), y = tBase - CGFloat(i + 1) * stepH
        let r = CGRect(x: W / 2 - w / 2, y: y, width: w, height: stepH + 1)
        c.fill(CGPath(rect: r, transform: nil), stone.lit(CGFloat(i) * 0.02))
        c.fill(CGPath(rect: CGRect(x: r.minX, y: r.minY, width: r.width, height: max(1, stepH * 0.12)), transform: nil), k.light.alpha(0.15))
        c.fill(CGPath(rect: CGRect(x: r.maxX - w * 0.18, y: r.minY, width: w * 0.18, height: r.height), transform: nil), k.deep.alpha(0.25))
    }
    // Shrine on top.
    let topY = tBase - CGFloat(steps) * stepH
    let shrine = CGRect(x: W / 2 - u * 0.08, y: topY - u * 0.07, width: u * 0.16, height: u * 0.07)
    c.fill(CGPath(rect: shrine, transform: nil), stone.lit(0.08))
    c.fill(polygon([P(shrine.minX - u * 0.015, shrine.minY), P(W / 2, shrine.minY - u * 0.035), P(shrine.maxX + u * 0.015, shrine.minY)]), stone.lit(0.04))
    // Stairs up the middle.
    c.fill(polygon([P(W / 2 - u * 0.05, tBase), P(W / 2 - u * 0.03, topY), P(W / 2 + u * 0.03, topY), P(W / 2 + u * 0.05, tBase)]), stone.lit(-0.12))
    // The door, at the foot, with gold light leaking out.
    let dw = u * 0.08, dh = u * 0.1
    c.glow(k.accent, P(lm.x, lm.y), u * 0.12, 0.45)
    let door = CGMutablePath()
    door.move(to: P(lm.x - dw / 2, lm.y + dh / 2)); door.addLine(to: P(lm.x - dw / 2, lm.y - dh * 0.15))
    door.addArc(center: P(lm.x, lm.y - dh * 0.15), radius: dw / 2, startAngle: .pi, endAngle: 0, clockwise: false)
    door.addLine(to: P(lm.x + dw / 2, lm.y + dh / 2)); door.closeSubpath()
    c.fill(door, k.deep)
    c.with { c.clip(door); c.linear(grad([(0, C(0xFFD060, 0)), (1, C(0xFFD060, 0.7))]), P(0, lm.y - dh / 2), P(0, lm.y + dh / 2)) }
    c.stroke(door, C(0xC89A3A, 0.8), max(1, u * 0.005))
    // Vines over the temple face.
    var vd = Dice(820)
    for _ in 0..<6 {
        let x = W / 2 + vd.range(-tw * 0.4, tw * 0.4), y = topY + vd.range(0, stepH * 2), l = u * vd.range(0.05, 0.12)
        c.stroke(quad(P(x, y), P(x + u * 0.02, y + l / 2), P(x, y + l)), k.near.mix(C(0x3A8A3A), 0.4), max(1, u * 0.004))
    }
    // Ground and big foreground leaves from both edges; vines hanging from the top.
    layer(c, ridge(s, base: floor + u * 0.04, amp: u * 0.03, seed: 830, bumps: 4, lift: 0.5), k.deep.lit(0.05), k.deep, floor, H)
    let leafCol = k.near.mix(C(0x1E5A32), 0.3), rib = k.light.alpha(0.18)
    var ld = Dice(840)
    for left in [true, false] {
        let x0: CGFloat = left ? -u * 0.02 : W + u * 0.02
        for i in 0..<5 {
            let y = H * (0.28 + CGFloat(i) * 0.15) + ld.range(-u * 0.04, u * 0.04)
            let l = u * ld.range(0.18, 0.3), a = rad(ld.range(10, 45))
            let tip = P(x0 + (left ? 1 : -1) * cos(a) * l, y + sin(a) * l * 0.6)
            leaf(c, P(x0, y), tip, width: l * 0.32, col: leafCol.lit(CGFloat(i % 2) * 0.05), rib: rib)
        }
    }
    let vines = CGMutablePath()
    for x in [0.06, 0.14, 0.86, 0.95, 0.3, 0.72] as [CGFloat] {
        let len = H * ld.range(0.12, 0.35) * (abs(x - 0.5) > 0.3 ? 1.3 : 0.5)
        vines.move(to: P(W * x, -2))
        vines.addQuadCurve(to: P(W * x + u * ld.range(-0.03, 0.03), len), control: P(W * x + u * 0.04, len * 0.5))
        for j in 1...4 {
            let p = P(W * x + u * 0.015, len * CGFloat(j) / 5)
            leaf(c, p, P(p.x + u * 0.04 * (j % 2 == 0 ? 1 : -1), p.y + u * 0.02), width: u * 0.018, col: leafCol, rib: rib)
        }
    }
    c.stroke(vines, leafCol.lit(-0.1), max(1, u * 0.005))
    // The canopy edge across the top.
    let canopy = CGMutablePath()
    var cx: CGFloat = -u * 0.05
    while cx < W + u * 0.05 {
        let e = abs(cx / W - 0.5) * 2, r = u * ld.range(0.05, 0.08) * (0.6 + e)
        canopy.addPath(circle(P(cx, -u * 0.01 + e * u * 0.04), r)); cx += r * 1.1
    }
    c.fill(canopy, k.deep.lit(0.08))
    switch v {
    case 3: motes(c, s, seed: 850, k.accent, count: 40, in: CGRect(x: 0, y: H * 0.2, width: W, height: H * 0.75), size: u * 0.002...u * 0.004, glow: 0.5)
    case 2: hazeBand(c, s, y: floor - u * 0.05, h: u * 0.14, k.haze, 0.45)
    default: motes(c, s, seed: 851, k.light, count: 20, in: CGRect(x: 0, y: 0, width: W, height: floor), size: u * 0.0012...u * 0.0025, glow: 0.2)
    }
    calmCentre(c, s, k.deep, 0.22)
    vignette(c, s, 0.45)
}

// MARK: - Clouds: Cloud Kingdom (fairy tales and sky castles)

func drawClouds(_ c: CGContext, _ s: CGSize, _ v: Int) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    let sea = H - max(u * 0.22, H * 0.14)
    let looks: [Look] = [
        // Morning, Sunset gold, Starry night, Storm lavender.
        Look(top: C(0x1A3A8A), mid: C(0x4A7AC0), low: C(0xF0B8B0), haze: C(0xB8C8E8), far: C(0x8AA0D8), near: C(0x6A80C0), deep: C(0x3A4A8A), light: C(0xFFF0D0), accent: C(0xFFD27A)),
        Look(top: C(0x2A1A5A), mid: C(0xB04A7A), low: C(0xFFB060), haze: C(0xF0A090), far: C(0xD07A8A), near: C(0xA0507A), deep: C(0x5A2A5A), light: C(0xFFD090), accent: C(0xFFC050)),
        Look(top: C(0x050A28), mid: C(0x14205A), low: C(0x2A3A7A), haze: C(0x4A5A9A), far: C(0x3A4A8A), near: C(0x2A3470), deep: C(0x141A44), light: C(0xE0E8FF), accent: C(0xFFE08A), night: 1),
        Look(top: C(0x22203A), mid: C(0x504A70), low: C(0x8A84A8), haze: C(0x8A88B0), far: C(0x6A6890), near: C(0x4A4870), deep: C(0x2A2848), light: C(0xF0F0FF), accent: C(0xC0B0FF), night: 0.3),
    ]
    let k = looks[v]
    backdrop(c, s) { c in
        sky(c, s, k, horizon: sea)
        c.blob(softGrad(k.light, k.night > 0.5 ? 0.15 : 0.45), P(W * 0.3, sea - u * 0.1), max(W, u) * 0.7, u * 0.4)
        c.fill(CGPath(rect: CGRect(x: 0, y: sea, width: W, height: H - sea), transform: nil), k.near)
    }
    if k.night > 0.5 {
        stars(c, CGSize(width: W, height: sea), seed: 901, density: 0.0016, tints: [C(0xFFFFFF), C(0xFFF0C0)], maxR: 1.3, keepOut: 0.2)
        moon(c, P(W * 0.2, H * 0.1), u * 0.05, k.light, glow: 0.6)
    } else if v == 1 {
        disc(c, P(W * 0.3, sea - u * 0.08), u * 0.1, C(0xFFC070), glow: 0.8)
    } else if v == 0 {
        disc(c, P(W * 0.24, H * 0.14), u * 0.06, C(0xFFF4D0), glow: 0.6)
    }
    let cb = k.haze.mix(.white, k.night > 0.5 ? 0.0 : 0.25), cs = k.far, cl = k.light.mix(cb, 0.3)
    // Far cloud banks, faint.
    for (i, (x, y, w)) in ([(0.15, 0.32, 0.5), (0.85, 0.42, 0.45), (0.5, 0.56, 0.6)] as [(CGFloat, CGFloat, CGFloat)]).enumerated() {
        puff(c, P(W * x, H * y), w: u * w, h: u * 0.08, body: cb.alpha(0.35), shade: cs.alpha(0.25), lit: cl.alpha(0.35), seed: UInt64(910 + i))
    }
    // The prism bridge in the night variant: a soft rainbow arc.
    if v == 2 || v == 0 {
        let o = P(W * 0.5, sea + u * 0.2), R = max(W * 0.5, u * 0.5)
        for (i, col) in [C(0xFF6A8A), C(0xFFB05A), C(0xFFF07A), C(0x7AF0A0), C(0x6AC8FF), C(0xA07AFF)].enumerated() {
            c.stroke(circle(o, R - CGFloat(i) * u * 0.014), col.alpha(v == 2 ? 0.1 : 0.06), u * 0.014, cap: .butt)
        }
    }
    // The castle on its cloud, left of centre, behind the sea of clouds.
    let cx = W * 0.2, cyb = sea + u * 0.02
    let stoneCol = k.far.mix(C(0xE8E0F0), k.night > 0.5 ? 0.1 : 0.3)
    let roof = v == 3 ? C(0x5A4A8A) : C(0x4A6AD8).mix(k.far, 0.3)
    let castle = CGMutablePath()
    castle.addRect(CGRect(x: cx - u * 0.1, y: cyb - u * 0.12, width: u * 0.2, height: u * 0.13))
    let towers: [(CGFloat, CGFloat, CGFloat)] = [(-0.11, 0.05, 0.22), (0.11, 0.05, 0.2), (0, 0.06, 0.3), (-0.05, 0.035, 0.17), (0.055, 0.035, 0.16)]
    for (dx, tw, th) in towers { castle.addRect(CGRect(x: cx + u * dx - u * tw / 2, y: cyb - u * th, width: u * tw, height: u * th)) }
    c.fill(castle, stoneCol)
    c.with { c.clip(castle); c.fill(CGPath(rect: CGRect(x: cx, y: cyb - u * 0.4, width: u * 0.2, height: u * 0.4), transform: nil), k.deep.alpha(0.18)) }
    for (dx, tw, th) in towers {
        let tx = cx + u * dx
        c.fill(polygon([P(tx - u * tw * 0.65, cyb - u * th), P(tx, cyb - u * th - u * tw * 1.6), P(tx + u * tw * 0.65, cyb - u * th)]), roof)
        c.fill(polygon([P(tx, cyb - u * th - u * tw * 1.6), P(tx + u * tw * 0.65, cyb - u * th), P(tx, cyb - u * th)]), roof.lit(-0.25))
        // Pennant.
        let top = P(tx, cyb - u * th - u * tw * 1.6)
        c.stroke(polyline([top, P(top.x, top.y - u * 0.03)]), k.deep, max(0.6, u * 0.002))
        c.fill(polygon([P(top.x, top.y - u * 0.03), P(top.x + u * 0.025, top.y - u * 0.024), P(top.x, top.y - u * 0.018)]), C(0xFF5A7A))
        let win = CGRect(x: tx - u * 0.006, y: cyb - u * th + u * 0.03, width: u * 0.012, height: u * 0.02)
        c.fill(CGPath(roundedRect: win, cornerWidth: u * 0.006, cornerHeight: u * 0.006, transform: nil), k.night > 0.5 ? C(0xFFD27A) : k.deep.alpha(0.6))
        if k.night > 0.5 { c.glow(C(0xFFD27A), P(win.midX, win.midY), u * 0.03, 0.4) }
    }
    // The beanstalk, curling up the right side to the highest cloud.
    let lm = landmarkSpot(.clouds, s)
    let stalk = CGMutablePath()
    let bx = W * 0.9
    stalk.move(to: P(bx, H + 10))
    var pts: [CGPoint] = []
    for i in 0...8 {
        let t = CGFloat(i) / 8
        pts.append(P(bx + sin(t * .pi * 3) * u * 0.05 - t * (bx - lm.x) * 0.6, H + 10 - (H + 10 - lm.y - u * 0.05) * t))
    }
    let stalkPath = smooth(pts)
    let green = k.near.mix(C(0x3AA05A), k.night > 0.5 ? 0.35 : 0.6)
    c.stroke(stalkPath, green.lit(-0.2), u * 0.03)
    c.stroke(stalkPath, green, u * 0.018)
    for (i, p) in pts.enumerated() where i > 0 && i < 8 {
        leaf(c, p, P(p.x + (i % 2 == 0 ? 1 : -1) * u * 0.07, p.y - u * 0.03), width: u * 0.035, col: green.lit(0.05), rib: green.lit(0.3).alpha(0.5))
    }
    // The highest cloud, with the golden goose's nest on top: the landmark.
    puff(c, P(lm.x, lm.y + u * 0.05), w: u * 0.3, h: u * 0.1, body: cb, shade: cs.alpha(0.9), lit: cl, seed: 920)
    let nest = P(lm.x, lm.y)
    c.fill(ellipse(P(nest.x, nest.y + u * 0.012), u * 0.05, u * 0.022), C(0x7A5A2A))
    var nd = Dice(921)
    let twigs = CGMutablePath()
    for _ in 0..<10 { let y = nest.y + u * nd.range(0, 0.025); twigs.move(to: P(nest.x - u * 0.05, y)); twigs.addQuadCurve(to: P(nest.x + u * 0.05, y + u * nd.range(-0.01, 0.01)), control: P(nest.x, y + u * 0.02)) }
    c.stroke(twigs, C(0xB08A4A), max(0.6, u * 0.003))
    c.glow(k.accent, P(nest.x, nest.y - u * 0.005), u * 0.06, 0.6)
    c.fill(ellipse(P(nest.x, nest.y - u * 0.004), u * 0.016, u * 0.021), C(0xFFD040))
    c.fill(ellipse(P(nest.x - u * 0.005, nest.y - u * 0.012), u * 0.005, u * 0.007), C(0xFFFFE0, 0.8))
    // The sea of clouds along the bottom, three rows deep.
    for (row, (y, h, a)) in ([(sea - u * 0.02, 0.1, 0.8), (sea + u * 0.06, 0.12, 0.95), (H - u * 0.02, 0.14, 1.0)] as [(CGFloat, CGFloat, CGFloat)]).enumerated() {
        let n = max(3, Int(W / (u * 0.32)))
        for i in 0...n {
            let t = (CGFloat(i) + (row % 2 == 0 ? 0 : 0.5)) / CGFloat(n)
            puff(c, P(W * t, y), w: u * 0.42, h: u * h, body: cb.lit(CGFloat(row) * 0.04 - 0.04).alpha(a), shade: cs.alpha(a), lit: cl.alpha(a), seed: UInt64(930 + row * 10 + i))
        }
        c.fill(CGPath(rect: CGRect(x: 0, y: y + u * h * 0.3, width: W, height: H), transform: nil), cs.alpha(a))
    }
    if v == 3 {
        streaks(c, s, seed: 940, k.light.alpha(0.2), count: max(60, Int(W * H / 4000)), len: u * 0.15, angle: 75, width: max(0.8, u * 0.0025))
        bolt(c, P(W * 0.78, H * 0.3), P(W * 0.72, H * 0.3 + u * 0.18), seed: 941, width: u * 0.005, k.accent, glow: 0.4)
    } else {
        motes(c, s, seed: 942, k.accent, count: 18, in: CGRect(x: 0, y: H * 0.1, width: W, height: H * 0.7), size: u * 0.0015...u * 0.003, glow: 0.35)
    }
    calmCentre(c, s, k.deep, 0.18)
    vignette(c, s, 0.38)
}

// MARK: - Clockwork: Clockwork Sky (steampunk and time travel)

private func gearPath(_ o: CGPoint, r: CGFloat, teeth: Int, hole: CGFloat) -> CGMutablePath {
    let p = CGMutablePath()
    let n = teeth * 4
    for i in 0..<n {
        let a = CGFloat(i) / CGFloat(n) * .pi * 2
        let rr = (i % 4 == 0 || i % 4 == 1) ? r : r * 0.86
        let pt = P(o.x + cos(a) * rr, o.y + sin(a) * rr)
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    p.addPath(circle(o, r * hole))
    // Spokes cut-outs.
    for i in 0..<5 {
        let a = CGFloat(i) / 5 * .pi * 2
        p.addPath(ellipse(P(o.x + cos(a) * r * 0.5, o.y + sin(a) * r * 0.5), r * 0.16, r * 0.11, rot: a * 180 / .pi))
    }
    return p
}

private func gear(_ c: CGContext, _ o: CGPoint, r: CGFloat, teeth: Int, col: C, edge: C) {
    let p = gearPath(o, r: r, teeth: teeth, hole: 0.18)
    c.with {
        c.addPath(p); c.clip(using: .evenOdd)
        c.radial(grad([(0, col.lit(0.15)), (1, col.lit(-0.2))]), o, r, from: P(o.x - r * 0.3, o.y - r * 0.3), extend: true)
    }
    c.addPath(p); c.setStrokeColor(edge.cg); c.setLineWidth(max(0.6, r * 0.02)); c.strokePath()
}

func drawClockwork(_ c: CGContext, _ s: CGSize, _ v: Int) {
    let u = min(s.width, s.height), W = s.width, H = s.height
    let floor = H - max(u * 0.16, H * 0.1)
    let looks: [Look] = [
        // Brass dusk, Steam docks, Time loop, Pendulum night.
        Look(top: C(0x1A0E14), mid: C(0x5A2A1E), low: C(0xC87A3A), haze: C(0xA8683A), far: C(0x6A3A22), near: C(0x3A2014), deep: C(0x140A06), light: C(0xFFD890), accent: C(0xFFB04A)),
        Look(top: C(0x0A1A1E), mid: C(0x1E4A4A), low: C(0x6A9A8A), haze: C(0x6A8A80), far: C(0x2A4A44), near: C(0x18302C), deep: C(0x081412), light: C(0xE8FFF0), accent: C(0xE0A060)),
        Look(top: C(0x0C0620), mid: C(0x2E1450), low: C(0x7A3A8A), haze: C(0x6A4A9A), far: C(0x3A2260), near: C(0x221440), deep: C(0x0C0620), light: C(0xD8C0FF), accent: C(0x7AE0FF), night: 0.6),
        Look(top: C(0x040814), mid: C(0x0E1A34), low: C(0x22305A), haze: C(0x2A3A68), far: C(0x1A2440), near: C(0x101628), deep: C(0x060810), light: C(0xD0E0FF), accent: C(0xFFC060), night: 1),
    ]
    let k = looks[v]
    let brass = [C(0xC8903A), C(0xB87A4A), C(0xA88AC0), C(0x8A7A5A)][v]
    backdrop(c, s) { c in
        sky(c, s, k, horizon: floor)
        c.blob(softGrad(k.light, k.night > 0.5 ? 0.15 : 0.35), P(W * 0.5, H * 0.18), max(W, u) * 0.6, u * 0.4)
        c.fill(CGPath(rect: CGRect(x: 0, y: floor, width: W, height: H - floor), transform: nil), k.deep)
    }
    if k.night > 0.5 { stars(c, CGSize(width: W, height: H * 0.6), seed: 1001, density: 0.0008, tints: [C(0xFFFFFF), C(0xFFE8C0)], maxR: 1.1, keepOut: 0.2) }
    // Far gears turning in the haze behind everything.
    var d = Dice(1010)
    for (x, y, r) in [(0.1, 0.42, 0.26), (0.92, 0.5, 0.3), (0.75, 0.75, 0.18), (0.22, 0.72, 0.16)] as [(CGFloat, CGFloat, CGFloat)] {
        gear(c, P(W * x, H * y), r: u * r, teeth: Int(r * 60), col: k.far.mix(k.haze, 0.35), edge: k.haze.alpha(0.3))
    }
    hazeBand(c, s, y: H * 0.6, h: H * 0.3, k.haze, 0.25)
    // An airship crossing high on the left.
    let ap = P(W * 0.18, H * 0.25), aw = u * 0.18
    c.fill(ellipse(ap, aw / 2, aw * 0.18), k.near.mix(k.haze, 0.25))
    c.fill(ellipse(P(ap.x - aw * 0.05, ap.y - aw * 0.05), aw * 0.4, aw * 0.07), k.light.alpha(0.12))
    c.fill(CGPath(roundedRect: CGRect(x: ap.x - aw * 0.15, y: ap.y + aw * 0.2, width: aw * 0.3, height: aw * 0.07), cornerWidth: aw * 0.03, cornerHeight: aw * 0.03, transform: nil), k.near.mix(k.haze, 0.15))
    c.stroke(polyline([P(ap.x - aw * 0.12, ap.y + aw * 0.15), P(ap.x - aw * 0.1, ap.y + aw * 0.2)]), k.near, 1)
    c.stroke(polyline([P(ap.x + aw * 0.12, ap.y + aw * 0.15), P(ap.x + aw * 0.1, ap.y + aw * 0.2)]), k.near, 1)
    c.fill(polygon([P(ap.x + aw * 0.45, ap.y), P(ap.x + aw * 0.6, ap.y - aw * 0.12), P(ap.x + aw * 0.6, ap.y + aw * 0.12)]), k.near.mix(k.haze, 0.2))
    // The landmark: the great clock face, high in the middle, in a brass ring.
    let lm = landmarkSpot(.clockwork, s)
    let o = P(lm.x, lm.y), R = u * 0.15
    // Clock tower behind the face, hazed into the sky so the play column stays quiet.
    let tower = polygon([P(o.x - R * 0.75, floor), P(o.x - R * 0.65, o.y + R * 1.05), P(o.x - R * 1.2, o.y + R * 1.05), P(o.x - R * 1.2, o.y - R * 0.6), P(o.x, o.y - R * 1.6), P(o.x + R * 1.2, o.y - R * 0.6), P(o.x + R * 1.2, o.y + R * 1.05), P(o.x + R * 0.65, o.y + R * 1.05), P(o.x + R * 0.75, floor)])
    c.fill(tower, k.far.mix(k.haze, 0.5))
    c.with {
        c.clip(tower)
        c.fill(CGPath(rect: CGRect(x: o.x, y: o.y - R * 2, width: R * 1.5, height: floor), transform: nil), k.deep.alpha(0.2))
        let bricks = CGMutablePath()
        var by = o.y + R * 1.2
        while by < floor { bricks.move(to: P(o.x - R, by)); bricks.addLine(to: P(o.x + R, by)); by += R * 0.14 }
        c.stroke(bricks, k.deep.alpha(0.15), max(0.6, R * 0.01))
        for i in 0..<3 {
            let wy = o.y + R * (1.5 + CGFloat(i) * 0.9)
            c.fill(CGPath(roundedRect: CGRect(x: o.x - R * 0.12, y: wy, width: R * 0.24, height: R * 0.4), cornerWidth: R * 0.12, cornerHeight: R * 0.12, transform: nil), k.accent.alpha(k.night > 0.5 ? 0.35 : 0.15))
        }
    }
    c.glow(k.accent, o, R * 1.8, 0.3)
    c.fillRadial(circle(o, R * 1.12), grad([(0, brass.lit(0.2)), (1, brass.lit(-0.35))]), o, R * 1.12, from: P(o.x - R * 0.3, o.y - R * 0.4))
    c.fillRadial(circle(o, R), grad([(0, C(0xFFF4DC).mix(k.light, 0.3)), (1, C(0xC8B490).mix(k.haze, 0.3))]), o, R, from: P(o.x - R * 0.2, o.y - R * 0.3))
    let ticks = CGMutablePath()
    for i in 0..<60 {
        let a = CGFloat(i) / 60 * .pi * 2
        let r0 = i % 5 == 0 ? R * 0.78 : R * 0.88
        ticks.move(to: P(o.x + cos(a) * r0, o.y + sin(a) * r0)); ticks.addLine(to: P(o.x + cos(a) * R * 0.94, o.y + sin(a) * R * 0.94))
    }
    c.stroke(ticks, C(0x3A2414, 0.8), max(0.6, R * 0.02))
    // Hands at nearly midnight.
    c.stroke(polyline([o, P(o.x + R * 0.08, o.y - R * 0.5)]), C(0x2A1A10), R * 0.06)
    c.stroke(polyline([o, P(o.x - R * 0.06, o.y - R * 0.78)]), C(0x2A1A10), R * 0.035)
    c.fill(circle(o, R * 0.06), brass)
    c.blob(grad([(0, C.white.alpha(0.4)), (1, C.white.alpha(0))]), P(o.x - R * 0.4, o.y - R * 0.5), R * 0.35, R * 0.12, rot: -35)
    hazeBand(c, s, y: (o.y + floor) / 2, h: H * 0.25, k.haze, 0.3)
    // A pendulum hanging under the face in the night variant.
    if v == 3 {
        let pb = P(o.x + R * 0.2, o.y + R * 2.4)
        c.stroke(polyline([P(o.x, o.y + R * 1.1), pb]), brass.alpha(0.6), max(1, R * 0.03))
        c.fill(circle(pb, R * 0.18), brass.alpha(0.7))
    }
    // Near gears at the sides, big and partly off-screen, in brass.
    gear(c, P(-u * 0.04, floor - u * 0.12), r: u * 0.24, teeth: 14, col: brass.mix(k.near, 0.45), edge: k.deep.alpha(0.6))
    gear(c, P(u * 0.2, floor - u * 0.02), r: u * 0.11, teeth: 9, col: brass.mix(k.near, 0.35), edge: k.deep.alpha(0.6))
    gear(c, P(W + u * 0.05, floor - u * 0.24), r: u * 0.2, teeth: 12, col: brass.mix(k.near, 0.45), edge: k.deep.alpha(0.6))
    // Pipes along the floor with steam.
    let pipes = CGMutablePath()
    pipes.move(to: P(-10, floor + u * 0.03)); pipes.addLine(to: P(W * 0.35, floor + u * 0.03)); pipes.addQuadCurve(to: P(W * 0.4, floor - u * 0.04), control: P(W * 0.4, floor + u * 0.03))
    pipes.addLine(to: P(W * 0.4, floor - u * 0.06))
    pipes.move(to: P(W + 10, floor + u * 0.06)); pipes.addLine(to: P(W * 0.7, floor + u * 0.06)); pipes.addLine(to: P(W * 0.7, floor - u * 0.08))
    c.stroke(pipes, brass.mix(k.deep, 0.5), u * 0.03, cap: .butt)
    c.stroke(pipes, brass.lit(0.2).alpha(0.35), u * 0.008, cap: .butt)
    layer(c, ridge(s, base: floor + u * 0.07, amp: u * 0.02, seed: 1020, bumps: 3, lift: 0.3), k.deep.lit(0.04), k.deep, floor, H)
    for x in [W * 0.4, W * 0.7] {
        for j in 0..<4 {
            let p = P(x + d.range(-u * 0.02, u * 0.02), floor - u * 0.08 - CGFloat(j) * u * 0.05)
            c.glow(k.light.mix(k.haze, 0.4), p, u * (0.04 + CGFloat(j) * 0.015), 0.3 - CGFloat(j) * 0.05)
        }
    }
    motes(c, s, seed: 1030, k.accent, count: 20, in: CGRect(x: 0, y: H * 0.3, width: W, height: H * 0.65), size: u * 0.0015...u * 0.003, glow: 0.35)
    calmCentre(c, s, k.deep, 0.2)
    vignette(c, s, 0.45)
}
