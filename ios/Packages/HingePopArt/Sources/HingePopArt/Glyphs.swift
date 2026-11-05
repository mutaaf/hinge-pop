import CoreGraphics

func drawGlyph(_ g: UIGlyph, _ c: CGContext) {
    switch g {
    case .shieldOn: drawBlueShield(c, P(0.5, 0.49), 0.385, mark: false)
    case .shieldOff: drawShieldOff(c)
    case .starOn: drawStar(c, on: true)
    case .starOff: drawStar(c, on: false)
    case .play:
        drawButton(c, rim: C(0xFF8FC8), rimDark: C(0x5A0630), light: C(0xF0405F), base: C(0xC81440), deep: C(0x7E0630))
        let tri = polygon([P(0.405, 0.30), P(0.71, 0.5), P(0.405, 0.70)], round: 0.028)
        icon(c, tri)
    case .pause:
        drawButton(c, rim: C(0xC8A8FF), rimDark: C(0x1E0A58), light: C(0x7C4AD8), base: C(0x4A22A0), deep: C(0x2A0F6A))
        let bars = CGMutablePath()
        bars.addRoundedRect(in: CGRect(x: 0.335, y: 0.30, width: 0.115, height: 0.40), cornerWidth: 0.03, cornerHeight: 0.03)
        bars.addRoundedRect(in: CGRect(x: 0.55, y: 0.30, width: 0.115, height: 0.40), cornerWidth: 0.03, cornerHeight: 0.03)
        icon(c, bars)
    case .settings:
        drawButton(c, rim: C(0xC8A8FF), rimDark: C(0x1E0A58), light: C(0x7C4AD8), base: C(0x4A22A0), deep: C(0x2A0F6A))
        icon(c, gearPath(mid, 0.225, teeth: 8), eoHole: circle(mid, 0.088))
    case .lock: drawLock(c)
    }
}

private func icon(_ c: CGContext, _ p: CGPath, eoHole: CGPath? = nil) {
    let full = CGMutablePath(); full.addPath(p)
    if let h = eoHole { full.addPath(h) }
    c.with {
        c.translateBy(x: 0, y: 0.014)
        c.addPath(full); c.setFillColor(C(0x12022A, 0.55).cg); c.fillPath(using: .evenOdd)
    }
    c.with {
        c.addPath(full); c.clip(using: .evenOdd)
        c.linear(grad([(0, .white), (0.6, .white), (1, C(0xD8D8F0))]), P(0.5, 0.26), P(0.5, 0.74))
    }
}

private func drawButton(_ c: CGContext, rim: C, rimDark: C, light: C, base: C, deep: C) {
    let r: CGFloat = 0.455
    c.fill(circle(mid, r), rimDark)
    c.fillLinear(circle(mid, r * 0.965), grad([(0, .white), (0.3, rim), (1, rim.mix(rimDark, 0.45))]), P(0.25, 0.08), P(0.75, 0.92))
    c.fill(circle(mid, r * 0.84), rimDark)
    c.fillRadial(circle(mid, r * 0.80), grad([(0, light), (0.55, base), (1, deep)]), P(0.5, 0.56), r * 0.9, from: P(0.42, 0.3))
    // Top gloss cap.
    c.with {
        c.clip(circle(mid, r * 0.80))
        c.fill(ellipse(P(0.5, 0.31), r * 0.72, r * 0.42), C.white.alpha(0.17))
    }
}

func gearPath(_ o: CGPoint, _ R: CGFloat, teeth n: Int) -> CGPath {
    let inner = R * 0.74
    let halfTop = 0.42 / CGFloat(n) * .pi * 1.05
    let halfRoot = 0.66 / CGFloat(n) * .pi
    var pts = [CGPoint]()
    for i in 0..<n {
        let a = CGFloat(i) * 2 * .pi / CGFloat(n) - .pi / 2
        pts.append(P(o.x + cos(a - halfRoot) * inner, o.y + sin(a - halfRoot) * inner))
        pts.append(P(o.x + cos(a - halfTop) * R, o.y + sin(a - halfTop) * R))
        pts.append(P(o.x + cos(a + halfTop) * R, o.y + sin(a + halfTop) * R))
        pts.append(P(o.x + cos(a + halfRoot) * inner, o.y + sin(a + halfRoot) * inner))
    }
    return polygon(pts, round: R * 0.05)
}

private func drawShieldOff(_ c: CGContext) {
    let o = P(0.5, 0.49), s: CGFloat = 0.385
    let outer = shieldPath(o, s)
    c.stroke(outer, C(0x120A30), s * 0.13)
    c.fillLinear(outer, grad([(0, C(0x8C90B8)), (1, C(0x4E507A))]), P(o.x - s, o.y - s), P(o.x + s, o.y + s))
    let inner = shieldPath(P(o.x, o.y + s * 0.03), s * 0.8)
    c.fillLinear(inner, grad([(0, C(0x3A3A62)), (1, C(0x24244A))]), P(o.x, o.y - s), P(o.x, o.y + s))
    c.with {
        c.clip(inner)
        c.fill(polygon([P(o.x, o.y - s * 1.2), P(o.x + s * 1.1, o.y - s * 1.2), P(o.x + s * 1.1, o.y + s * 1.2), P(o.x, o.y + s * 1.2)]), C.white.alpha(0.05))
    }
}

private func drawStar(_ c: CGContext, on: Bool) {
    let o = P(0.5, 0.525)
    let outer = polygon(starPoints(o, 0.45, 0.225, 5), round: 0.05)
    let face = polygon(starPoints(P(o.x, o.y - 0.012), 0.385, 0.20, 5), round: 0.045)
    if on {
        c.glow(C(0xFF9A00), mid, 0.49, 0.55)
        c.stroke(outer, C(0x8F3A00), 0.018)
        c.fillLinear(outer, grad([(0, C(0xFFD23A)), (1, C(0xE86A00))]), P(0.5, 0.05), P(0.5, 0.95))
        c.fillLinear(face, grad([(0, C(0xFFF7A0)), (0.5, C(0xFFD42E)), (1, C(0xFFA400))]), P(0.4, 0.15), P(0.6, 0.88))
        // Left half highlight, a cheap bevel that reads as faceted.
        c.with {
            c.clip(face)
            c.blob(grad([(0, C.white.alpha(0.85)), (1, C.white.alpha(0))]), P(0.42, 0.33), 0.15, 0.08, rot: -40)
        }
    } else {
        c.stroke(outer, C(0x120A30), 0.018)
        c.fillLinear(outer, grad([(0, C(0x8C8EAE)), (1, C(0x4A4A6E))]), P(0.5, 0.05), P(0.5, 0.95))
        c.fillLinear(face, grad([(0, C(0x7C7E9E)), (1, C(0x50507A))]), P(0.4, 0.15), P(0.6, 0.88))
    }
}

private func drawLock(_ c: CGContext) {
    // Shackle.
    let shackle = CGMutablePath()
    shackle.move(to: P(0.315, 0.50))
    shackle.addLine(to: P(0.315, 0.31))
    shackle.addCurve(to: P(0.685, 0.31), control1: P(0.315, 0.07), control2: P(0.685, 0.07))
    shackle.addLine(to: P(0.685, 0.50))
    c.stroke(shackle, C(0x12062E), 0.135, cap: .butt)
    c.strokeLinear(shackle, 0.09, grad([(0, C(0xF2F6FF)), (0.5, C(0xAAB6D0)), (1, C(0x6A7694))]), P(0.28, 0.1), P(0.72, 0.5), cap: .butt)
    // Body.
    let body = CGPath(roundedRect: CGRect(x: 0.15, y: 0.42, width: 0.70, height: 0.51), cornerWidth: 0.11, cornerHeight: 0.11, transform: nil)
    c.stroke(body, C(0x4A1E00), 0.042)
    c.fillLinear(body, grad([(0, C(0xFFEE80)), (0.42, C(0xFFC21F)), (1, C(0xE87A00))]), P(0.5, 0.42), P(0.5, 0.93))
    c.fill(CGPath(roundedRect: CGRect(x: 0.19, y: 0.455, width: 0.62, height: 0.085), cornerWidth: 0.04, cornerHeight: 0.04, transform: nil), C.white.alpha(0.6))
    // Keyhole.
    let hole = CGMutablePath()
    hole.addEllipse(in: CGRect(x: 0.44, y: 0.585, width: 0.12, height: 0.12))
    hole.addLines(between: [P(0.47, 0.67), P(0.53, 0.67), P(0.555, 0.83), P(0.445, 0.83)])
    c.fill(hole, C(0x4A1E00))
}
