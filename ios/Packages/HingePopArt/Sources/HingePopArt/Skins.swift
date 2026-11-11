import CoreGraphics
import Foundation

// Per-biome bubble skins, drawn over the finished bubble. Each skin is two things: the biome's light
// bounced into the lower body and around the rim, and one small accessory that sits on the body's
// edge, away from the face. Nothing covers the eyes or mouth, and nothing reaches the image edge, so
// every kind still reads as itself at a glance.

private func skinLight(_ k: ArenaKind) -> C {
    switch k {
    case .classic: return C(0x70B0FF)
    case .neon: return C(0xFF4FE0)
    case .forest: return C(0x8AF07A)
    case .space: return C(0xC090FF)
    case .frost: return C(0xD8F4FF)
    case .reef: return C(0x5AF0D8)
    case .magma: return C(0xFF8A30)
    case .candy: return C(0xFF8AC8)
    case .dunes: return C(0xFFC070)
    case .storm: return C(0xA8E0FF)
    case .crystal: return C(0x7AF0F0)
    case .haunted: return C(0xA0FF8A)
    case .circuit: return C(0x3AF0E0)
    case .jungle: return C(0xC8F060)
    case .clouds: return C(0xFFF0D0)
    case .clockwork: return C(0xFFC060)
    }
}

func drawSkin(_ biome: ArenaKind, _ kind: BubbleKind, _ c: CGContext, small: Bool) {
    let boss = kind == .boss || kind == .bossHurt
    let r = boss ? bossBodyRadius : bodyRadius
    let o = mid
    let light = skinLight(biome)
    // Bounce light in the lower body and a coloured rim. Bosses keep their own menace: rim only.
    if !boss {
        c.with {
            c.clip(circle(o, r * 0.96))
            c.blob(softGrad(light, 0.28), P(o.x, o.y + r * 0.95), r * 1.0, r * 0.45)
        }
    }
    c.strokeLinear(circle(o, r * 0.985), r * (small ? 0.07 : 0.05),
                   grad([(0, light.alpha(0)), (0.55, light.alpha(0.15)), (1, light.alpha(0.8))]), P(o.x - r * 0.5, o.y - r * 0.6), P(o.x + r * 0.4, o.y + r * 0.9))
    // The accessory sits on the upper right shoulder (bosses: on the left, clear of the crown).
    let side: CGFloat = boss ? -1 : 1
    let a = rad(boss ? -150 : -38)
    let at = P(o.x + cos(a) * r, o.y + sin(a) * r)
    let s = r * (small ? 0.34 : 0.28)
    switch biome {
    case .classic:
        break
    case .neon:
        sparkle(c, P(at.x + s * 0.2 * side, at.y - s * 0.1), s * 0.7, C(0xFF8AF0))
    case .forest, .jungle:
        let base = P(o.x + r * 0.15 * side, o.y - r * 0.9)
        let tip = P(base.x + s * 2.0 * side, base.y - s * 0.75)
        let leafCol = biome == .forest ? C(0x3ACB5A) : C(0x7AC832)
        c.fill(taper(base, tip, width: s * 1.1, at: 0.45), leafCol.lit(-0.3))
        c.fill(taper(base, P(tip.x - s * 0.08 * side, tip.y + s * 0.05), width: s * 0.85, at: 0.45), leafCol)
        if !small { c.stroke(quad(base, P((base.x + tip.x) / 2, (base.y + tip.y) / 2 + s * 0.1), tip), leafCol.lit(0.4), s * 0.08) }
        if biome == .jungle && !small {
            c.stroke(quad(P(o.x - r * 0.75, o.y - r * 0.68), P(o.x - r * 1.0, o.y), P(o.x - r * 0.8, o.y + r * 0.62)), C(0x4A8A2A, 0.85), r * 0.06)
        }
    case .space:
        c.with {
            c.translateBy(x: at.x, y: at.y); c.rotate(by: rad(-20))
            c.stroke(ellipse(.zero, s * 1.3, s * 0.4), C(0xE0C8FF, 0.85), s * 0.16)
            c.fill(circle(.zero, s * 0.55), C(0xB07AFF))
            c.fill(circle(P(-s * 0.18, -s * 0.18), s * 0.2), C(0xE8D8FF))
        }
    case .frost:
        // Rime along the top of the body: a jagged white cap.
        var pts: [CGPoint] = []
        let n = small ? 7 : 11
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let ang = rad(-150 + 120 * t)
            let rr = i % 2 == 0 ? r * 1.02 : r * (small ? 0.86 : 0.9)
            pts.append(P(o.x + cos(ang) * rr, o.y + sin(ang) * rr))
        }
        let cap = CGMutablePath()
        cap.addArc(center: o, radius: r * 1.02, startAngle: rad(-150), endAngle: rad(-30), clockwise: false)
        for p in pts.reversed() { cap.addLine(to: p) }
        cap.closeSubpath()
        c.fill(cap, C(0xF4FCFF, 0.9))
        c.stroke(cap, C(0xA8D8FF, 0.7), r * 0.015)
    case .reef:
        for (dx, dy, k) in [(0.0, 0.0, 1.0), (0.9, 0.7, 0.6), (0.2, 1.3, 0.45)] as [(CGFloat, CGFloat, CGFloat)] {
            let p = P(at.x + s * dx * side, at.y - s * dy + s * 0.5)
            c.fill(circle(p, s * 0.42 * k), C(0xC8FAFF, 0.25))
            c.stroke(circle(p, s * 0.42 * k), C(0xE8FFFF, 0.85), s * 0.09)
            c.fill(circle(P(p.x - s * 0.12 * k, p.y - s * 0.12 * k), s * 0.1 * k), .white)
        }
    case .magma:
        c.with { c.clip(circle(o, r * 0.97)); c.blob(softGrad(C(0xFF5A1E), 0.4), P(o.x, o.y + r * 1.05), r * 0.9, r * 0.3) }
        for (dx, dy) in [(0.0, 0.0), (0.8, 0.9), (-0.5, 1.2)] as [(CGFloat, CGFloat)] {
            let p = P(at.x + s * dx * side, at.y - s * dy)
            c.glow(C(0xFF8A30), p, s * 0.6, 0.6)
            c.fill(circle(p, s * 0.16), C(0xFFE0A0))
        }
    case .candy:
        // Sprinkles across the crown.
        let cols = [C(0xFF4A8A), C(0x5AD0FF), C(0xFFE05A), C(0x7AE87A), C(0xB07AFF)]
        var d = Dice(7)
        for i in 0..<(small ? 6 : 10) {
            let ang = rad(-150 + 120 * (CGFloat(i) + 0.5) / CGFloat(small ? 6 : 10))
            let rr = r * d.range(0.82, 0.93)
            let p = P(o.x + cos(ang) * rr, o.y + sin(ang) * rr)
            let t = d.range(0, .pi), l = r * (small ? 0.13 : 0.1)
            c.stroke(polyline([P(p.x - cos(t) * l / 2, p.y - sin(t) * l / 2), P(p.x + cos(t) * l / 2, p.y + sin(t) * l / 2)]), cols[i % 5], r * (small ? 0.05 : 0.04))
        }
    case .dunes:
        // A little cloth wrap tied on the crown.
        let band = CGMutablePath()
        band.addArc(center: o, radius: r * 0.96, startAngle: rad(-155), endAngle: rad(-25), clockwise: false)
        c.stroke(band, C(0xE8A050, 0.9), r * 0.11, cap: .butt)
        c.stroke(band, C(0xFFD890, 0.6), r * 0.03, cap: .butt)
        c.fill(taper(at, P(at.x + s * 1.5, at.y + s * 0.8), width: s * 0.6), C(0xD08A3A))
    case .storm:
        let b = [P(0.15, -1), P(-0.35, 0.05), P(0.05, 0.05), P(-0.2, 1), P(0.45, -0.2), P(0.05, -0.2), P(0.3, -1)].map { P(at.x + $0.x * s * 0.9, at.y - s * 0.3 + $0.y * s * 0.9) }
        c.glow(C(0xA8E0FF), P(at.x, at.y - s * 0.3), s * 1.3, 0.6)
        c.fill(polygon(b), C(0xFFF4A0))
        c.stroke(polygon(b), C(0x3A2A6A, 0.7), s * 0.08)
    case .crystal:
        let base = P(at.x, at.y + s * 0.25)
        let shard = [P(base.x - s * 0.35, base.y), P(base.x - s * 0.3, base.y - s * 0.9), P(base.x + s * 0.05, base.y - s * 1.5), P(base.x + s * 0.35, base.y - s * 0.85), P(base.x + s * 0.3, base.y)]
        c.glow(C(0x7AF0F0), P(base.x, base.y - s * 0.7), s * 1.2, 0.4)
        c.fill(polygon(shard), C(0x8AF8FF))
        c.fill(polygon([shard[2], shard[3], shard[4], P(base.x, base.y)]), C(0x3AB0D0))
        c.stroke(polyline([shard[1], shard[2]]), .white, s * 0.07)
    case .haunted:
        if small {
            c.fill(circle(P(at.x, at.y - s * 0.2), s * 0.3), C(0x1A1028))
        } else {
            // A cobweb on the upper left shoulder, clear of the eyes.
            let wo = P(o.x - r * 0.95, o.y - r * 0.95)
            let web = CGMutablePath()
            for i in 0...3 {
                let ang = rad(10 + CGFloat(i) * 23)
                web.move(to: wo); web.addLine(to: P(wo.x + cos(ang) * r * 0.75, wo.y + sin(ang) * r * 0.75))
            }
            for ring in 1...3 {
                let rr = r * 0.22 * CGFloat(ring)
                var prev: CGPoint?
                for i in 0...3 {
                    let ang = rad(10 + CGFloat(i) * 23)
                    let p = P(wo.x + cos(ang) * rr, wo.y + sin(ang) * rr)
                    if let q = prev { web.move(to: q); web.addQuadCurve(to: p, control: P((p.x + q.x) / 2 - rr * 0.05, (p.y + q.y) / 2 - rr * 0.05)) }
                    prev = p
                }
            }
            c.with { c.clip(circle(o, r * 1.02)); c.stroke(web, C(0xF0F0FF, 0.75), r * 0.018) }
        }
    case .circuit:
        // Traces across the lower body, under the mouth line.
        if !small {
            c.with {
                c.clip(circle(o, r * 0.96))
                let t = CGMutablePath()
                t.move(to: P(o.x - r, o.y + r * 0.72)); t.addLine(to: P(o.x - r * 0.45, o.y + r * 0.72)); t.addLine(to: P(o.x - r * 0.3, o.y + r * 0.86))
                t.move(to: P(o.x + r, o.y + r * 0.62)); t.addLine(to: P(o.x + r * 0.5, o.y + r * 0.62)); t.addLine(to: P(o.x + r * 0.35, o.y + r * 0.8))
                c.stroke(t, C(0x3AF0E0, 0.85), r * 0.035)
                c.fill(circle(P(o.x - r * 0.3, o.y + r * 0.86), r * 0.05), C(0xC8FFF8))
                c.fill(circle(P(o.x + r * 0.35, o.y + r * 0.8), r * 0.05), C(0xC8FFF8))
            }
        }
        c.fill(CGPath(roundedRect: CGRect(x: at.x - s * 0.5, y: at.y - s * 0.5, width: s, height: s), cornerWidth: s * 0.15, cornerHeight: s * 0.15, transform: nil), C(0x1A2A3A))
        c.stroke(CGPath(roundedRect: CGRect(x: at.x - s * 0.5, y: at.y - s * 0.5, width: s, height: s), cornerWidth: s * 0.15, cornerHeight: s * 0.15, transform: nil), C(0x3AF0E0), s * 0.12)
    case .clouds:
        let b = P(o.x + r * 0.35 * side, o.y + r * 0.92)
        let puffP = CGMutablePath()
        for (dx, dy, k) in [(-0.9, 0.1, 0.5), (0.0, -0.15, 0.7), (0.9, 0.1, 0.5)] as [(CGFloat, CGFloat, CGFloat)] { puffP.addPath(circle(P(b.x + dx * s, b.y + dy * s), s * k)) }
        c.fill(puffP, C(0xFFFFFF, 0.92))
    case .clockwork:
        let g = CGMutablePath()
        let n = 8
        for i in 0..<(n * 2) {
            let ang = CGFloat(i) / CGFloat(n * 2) * .pi * 2
            let rr = i % 2 == 0 ? s * 0.85 : s * 0.62
            let p = P(at.x + cos(ang) * rr, at.y + sin(ang) * rr)
            if i == 0 { g.move(to: p) } else { g.addLine(to: p) }
        }
        g.closeSubpath()
        g.addPath(circle(at, s * 0.25))
        c.with {
            c.addPath(g); c.clip(using: .evenOdd)
            c.radial(grad([(0, C(0xFFE0A0)), (1, C(0xB07A2A))]), at, s, from: P(at.x - s * 0.3, at.y - s * 0.3), extend: true)
        }
        c.addPath(g); c.setStrokeColor(C(0x4A2A0A, 0.8).cg); c.setLineWidth(s * 0.06); c.strokePath()
    }
}
