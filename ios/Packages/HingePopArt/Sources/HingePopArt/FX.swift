import CoreGraphics

let confettiCount = 8

func drawFX(_ k: FXKind, _ c: CGContext) {
    switch k {
    case .popBurst: drawPopBurst(c)
    case .shockwave: drawShockwave(c)
    case .particleStar: drawParticle(c)
    case .confetti(let n): drawConfetti(n, c)
    case .shard: drawShard(c)
    case .crack: drawCrack(c)
    case .glint: drawGlint(c)
    }
}

private func drawPopBurst(_ c: CGContext) {
    c.glow(C(0xFFB000), mid, 0.47, 0.6)
    // Flung bits around the star.
    let bits: [(C, CGFloat)] = [(C(0xFFC21F), 0), (C(0xFF7A1F), 45), (C(0xFF4FA8), 90), (C(0xFFE34D), 135), (C(0xFF7A1F), 180), (C(0x3FD8FF), 225), (C(0xFFC21F), 270), (C(0xFF4FA8), 315)]
    for (col, deg) in bits {
        let a = rad(deg + 22.5)
        let d = P(cos(a), sin(a))
        c.stroke(polyline([P(0.5 + d.x * 0.385, 0.5 + d.y * 0.385), P(0.5 + d.x * 0.44, 0.5 + d.y * 0.44)]), col, 0.052)
    }
    let star = polygon(starPoints(mid, 0.355, 0.165, 8), round: 0.012)
    c.stroke(star, C(0xE85A00), 0.022)
    c.fillRadial(star, grad([(0, C(0xFFFFE0)), (0.3, C(0xFFF04A)), (0.75, C(0xFFC400)), (1, C(0xFF9400))]), mid, 0.355)
    c.glow(.white, mid, 0.11, 0.7)
}

private func drawShockwave(_ c: CGContext) {
    let R: CGFloat = 0.475
    c.radial(grad([(0, C(0x5A4CFF, 0)), (0.58, C(0x5A4CFF, 0)), (0.74, C(0x6A58FF, 0.42)), (0.82, C(0x7CC8FF, 0.95)), (0.86, C.white), (0.90, C(0xA67CFF, 0.9)), (1, C(0x7A40FF, 0))]), mid, R)
    c.stroke(circle(mid, 0.325), C(0xB4C8FF, 0.75), 0.012)
    // Two swept arcs give the ring some speed.
    let a = CGMutablePath(); a.addArc(center: mid, radius: 0.30, startAngle: rad(200), endAngle: rad(300), clockwise: false)
    let b = CGMutablePath(); b.addArc(center: mid, radius: 0.30, startAngle: rad(20), endAngle: rad(120), clockwise: false)
    c.stroke(a, C(0xC8D8FF, 0.75), 0.008)
    c.stroke(b, C(0xC8D8FF, 0.75), 0.008)
}

private func drawParticle(_ c: CGContext) {
    c.glow(C(0xB070FF), mid, 0.47, 0.75)
    let star = polygon(starPoints(mid, 0.44, 0.075, 4))
    c.fillRadial(star, grad([(0, .white), (0.4, C(0xF0DCFF)), (1, C(0xC890FF))]), mid, 0.44)
    let cross = polygon(starPoints(mid, 0.2, 0.05, 4, rot: 45))
    c.fill(cross, C.white.alpha(0.75))
    c.glow(.white, mid, 0.16, 1)
}

private func drawConfetti(_ n: Int, _ c: CGContext) {
    let palette: [(C, C)] = [
        (C(0xFF4FA8), C(0xB8127A)), (C(0xFFD52E), C(0xD07E00)), (C(0x3FD8FF), C(0x0E78D0)), (C(0x4CE680), C(0x0E9050)),
        (C(0xFF8A2E), C(0xC8400A)), (C(0xB070FF), C(0x6A22D8)), (C(0x2EE8D0), C(0x0A8A98)), (C(0xFF5C5C), C(0xB81A3A)),
    ]
    let (hi, lo) = palette[n]
    let g = grad([(0, hi.mix(.white, 0.28)), (0.5, hi), (1, lo)])
    let shape: CGPath
    switch n {
    case 0: // tilted slip
        shape = CGPath(roundedRect: CGRect(x: -0.40, y: -0.20, width: 0.80, height: 0.40), cornerWidth: 0.05, cornerHeight: 0.05, transform: nil)
    case 1: // diamond
        shape = polygon([P(0, -0.44), P(0.30, 0), P(0, 0.44), P(-0.30, 0)], round: 0.03)
    case 2: // dot
        shape = circle(.zero, 0.27)
    case 3: // triangle
        shape = polygon([P(0, -0.40), P(0.40, 0.32), P(-0.40, 0.32)], round: 0.045)
    case 4: // curl ribbon
        shape = smooth([P(-0.42, -0.10), P(-0.14, 0.18), P(0.14, -0.14), P(0.42, 0.12)])
            .copy(strokingWithWidth: 0.19, lineCap: .round, lineJoin: .round, miterLimit: 4)
    case 5: // star
        shape = polygon(starPoints(.zero, 0.44, 0.20, 5), round: 0.03)
    case 6: // square
        shape = CGPath(roundedRect: CGRect(x: -0.28, y: -0.28, width: 0.56, height: 0.56), cornerWidth: 0.05, cornerHeight: 0.05, transform: nil)
    default: // crescent slip
        let p = CGMutablePath()
        p.move(to: P(-0.40, 0.18))
        p.addQuadCurve(to: P(0.40, 0.18), control: P(0, -0.62))
        p.addQuadCurve(to: P(-0.40, 0.18), control: P(0, -0.12))
        p.closeSubpath()
        shape = p
    }
    c.with {
        c.translateBy(x: 0.5, y: 0.5)
        c.rotate(by: rad([18, 0, 0, -14, 0, 12, 24, -10][n]))
        c.fillLinear(shape, g, P(-0.3, -0.4), P(0.3, 0.4))
        if n != 4 {
            c.stroke(shape, lo.alpha(0.7), 0.028)
        }
    }
}

/// A curl of bubble film: a thin crescent, bright along its outer edge like the rim of the bubble it came from.
private func drawShard(_ c: CGContext) {
    let p = CGMutablePath()
    p.move(to: P(0.1, 0.62))
    p.addQuadCurve(to: P(0.9, 0.62), control: P(0.5, 0.06))
    p.addQuadCurve(to: P(0.1, 0.62), control: P(0.5, 0.34))
    p.closeSubpath()
    c.glow(.white, P(0.5, 0.42), 0.46, 0.22)
    c.fillLinear(p, grad([(0, C.white), (0.45, C.white.alpha(0.86)), (1, C.white.alpha(0.5))]), P(0.5, 0.2), P(0.5, 0.62))
    let rim = CGMutablePath()
    rim.move(to: P(0.16, 0.58))
    rim.addQuadCurve(to: P(0.84, 0.58), control: P(0.5, 0.1))
    c.stroke(rim, C.white, 0.035)
    c.glow(.white, P(0.42, 0.33), 0.09, 1)
}

/// Glass struck from the centre: straight rays that kink and fork as they run out, rings of chords between
/// them like a web, and a crushed ring at the point of impact.
private func drawCrack(_ c: CGContext) {
    var d = Dice(77)
    let centre = mid
    c.glow(.white, centre, 0.14, 0.5)
    let rays = 9
    var paths: [[CGPoint]] = []
    for i in 0..<rays {
        var a = CGFloat(i) / CGFloat(rays) * 2 * .pi + d.range(-0.2, 0.2)
        var at = P(centre.x + cos(a) * 0.06, centre.y + sin(a) * 0.06)
        var pts = [at]
        let reach = d.range(0.36, 0.47)
        var r: CGFloat = 0.06
        while r < reach {
            let step = d.range(0.06, 0.11)
            a += d.range(-0.14, 0.14)
            at = P(at.x + cos(a) * step, at.y + sin(a) * step)
            pts.append(at)
            r += step
            if r > 0.16, d.unit() < 0.35 {
                let b = a + (d.unit() < 0.5 ? 1 : -1) * d.range(0.35, 0.7)
                let s = d.range(0.06, 0.12)
                c.stroke(polyline([at, P(at.x + cos(b) * s, at.y + sin(b) * s)]), C.white.alpha(0.7), 0.004, join: .miter)
            }
        }
        paths.append(pts)
    }
    for pts in paths {
        c.stroke(polyline(pts), C.white.alpha(0.28), 0.016, join: .miter)
        c.stroke(polyline(pts), C.white, 0.0065, join: .miter)
    }
    // Chords between neighbouring rays: the web.
    for ringAt in [2, 3] {
        for i in 0..<rays {
            let a = paths[i], b = paths[(i + 1) % rays]
            guard a.count > ringAt, b.count > ringAt, d.unit() < 0.8 else { continue }
            c.stroke(polyline([a[ringAt], b[ringAt]]), C.white.alpha(0.6), 0.004, join: .miter)
        }
    }
    var ring: [CGPoint] = []
    for k in 0...12 {
        let a = CGFloat(k) / 12 * 2 * .pi
        let r = 0.06 + d.range(-0.012, 0.012)
        ring.append(P(centre.x + cos(a) * r, centre.y + sin(a) * r))
    }
    c.stroke(polyline(ring), C.white, 0.007, join: .miter)
    c.glow(.white, centre, 0.045, 1)
}

/// A four-point flare with a soft halo: stars landing, sparkles, the ready flash on the line.
private func drawGlint(_ c: CGContext) {
    c.glow(.white, mid, 0.42, 0.45)
    c.fill(polygon(starPoints(mid, 0.48, 0.05, 4)), C.white)
    c.fill(polygon(starPoints(mid, 0.24, 0.04, 4, rot: 45)), C.white.alpha(0.8))
    c.glow(.white, mid, 0.12, 1)
}
