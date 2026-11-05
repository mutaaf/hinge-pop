import CoreGraphics

let confettiCount = 8

func drawFX(_ k: FXKind, _ c: CGContext) {
    switch k {
    case .popBurst: drawPopBurst(c)
    case .shockwave: drawShockwave(c)
    case .particleStar: drawParticle(c)
    case .confetti(let n): drawConfetti(n, c)
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
