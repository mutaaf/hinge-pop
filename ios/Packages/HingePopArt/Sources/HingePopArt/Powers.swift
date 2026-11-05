import CoreGraphics

func drawPower(_ kind: PowerKind, _ c: CGContext) {
    switch kind {
    case .overcharge: drawOvercharge(c)
    case .freeze: drawFreeze(c)
    case .focus: drawFocus(c)
    case .shield: drawShieldPower(c)
    case .chainBurst: drawChainBurst(c)
    }
}

/// A round glassy orb without a face.
private func orb(_ c: CGContext, r: CGFloat, glow: C, ring: C, ringDark: C, light: C, base: C, deep: C) {
    c.radial(grad([(0, glow.alpha(0.7)), (r / 0.47, glow.alpha(0.7)), (1, glow.alpha(0))]), mid, 0.47)
    c.fill(circle(mid, r), ringDark)
    c.fill(circle(mid, r * 0.965), ring)
    c.fillRadial(circle(mid, r * 0.87), grad([(0, light), (0.55, base), (1, deep)]),
                 P(0.5, 0.52), r * 0.9, from: P(0.5 - r * 0.25, 0.5 - r * 0.35))
}

private func orbGlass(_ c: CGContext, r: CGFloat) {
    c.with {
        c.clip(circle(mid, r * 0.87))
        c.blob(grad([(0, C.white.alpha(0.55)), (0.65, C.white.alpha(0.3)), (1, C.white.alpha(0))]),
               P(0.5 - r * 0.05, 0.5 - r * 0.60), r * 0.72, r * 0.34)
    }
    c.blob(grad([(0, C.white.alpha(0.95)), (0.6, C.white.alpha(0.8)), (1, C.white.alpha(0))]),
           P(0.5 - r * 0.42, 0.5 - r * 0.56), r * 0.2, r * 0.09, rot: -34)
}

private func drawOvercharge(_ c: CGContext) {
    let r: CGFloat = 0.40
    orb(c, r: r, glow: C(0xFF9A00), ring: C(0xFFC233), ringDark: C(0x7A2E00), light: C(0xFFC233), base: C(0xF58A00), deep: C(0xB84C00))
    // Coin edge: notched ring.
    c.stroke(circle(mid, r * 0.90), C(0x8A3A00, 0.75), r * 0.035)
    // Bolt.
    let b = [P(0.58, 0.17), P(0.30, 0.56), P(0.46, 0.56), P(0.39, 0.83), P(0.70, 0.42), P(0.53, 0.42), P(0.645, 0.17)]
    let bolt = polygon(b, round: 0.012)
    c.with {
        c.translateBy(x: 0.012, y: 0.02)
        c.fill(bolt, C(0x7A2E00, 0.85))
    }
    c.stroke(bolt, C(0x7A2E00), 0.022)
    c.fillLinear(bolt, grad([(0, C(0xFFFBC8)), (0.45, C(0xFFE84A)), (1, C(0xFFB300))]), P(0.5, 0.2), P(0.5, 0.8))
    orbGlass(c, r: r)
}

private func drawFreeze(_ c: CGContext) {
    let r: CGFloat = 0.40
    orb(c, r: r, glow: C(0x38BFFF), ring: C(0x9FEFFF), ringDark: C(0x0B3C9E), light: C(0x6AD8FF), base: C(0x1E9CF8), deep: C(0x0B5CD6))
    // Snowflake.
    let arm = CGMutablePath()
    let o = mid
    for i in 0..<6 {
        let a = rad(CGFloat(i) * 60 - 90)
        func at(_ d: CGFloat, _ side: CGFloat = 0) -> CGPoint {
            P(o.x + cos(a) * d - sin(a) * side, o.y + sin(a) * d + cos(a) * side)
        }
        arm.move(to: o); arm.addLine(to: at(0.265))
        let s: CGFloat = 0.056
        arm.move(to: at(0.205 - s, -s)); arm.addLine(to: at(0.205)); arm.addLine(to: at(0.205 - s, s))
    }
    c.stroke(arm, C(0x0B3C9E, 0.8), 0.058)
    c.stroke(arm, .white, 0.034)
    c.fill(circle(o, 0.03), .white)
    orbGlass(c, r: r)
}

private func drawFocus(_ c: CGContext) {
    let r: CGFloat = 0.34
    orb(c, r: r, glow: C(0xFF2E5B), ring: C(0xFF8FA3), ringDark: C(0x7A0620), light: C(0xFF5C7A), base: C(0xE01640), deep: C(0x8E0426))
    c.stroke(circle(mid, r * 0.56), .white, 0.022)
    // Crosshair ticks crossing the orb's edge.
    for i in 0..<4 {
        let a = rad(CGFloat(i) * 90)
        let d = P(cos(a), sin(a))
        let inner = P(0.5 + d.x * 0.235, 0.5 + d.y * 0.235), outer = P(0.5 + d.x * 0.45, 0.5 + d.y * 0.45)
        c.stroke(polyline([inner, outer]), C(0x7A0620), 0.058)
        c.stroke(polyline([inner, outer]), .white, 0.034)
    }
    // Centre plus.
    let plus = CGMutablePath()
    plus.addLines(between: [P(0.5, 0.445), P(0.5, 0.555)])
    plus.addLines(between: [P(0.445, 0.5), P(0.555, 0.5)])
    c.stroke(plus, .white, 0.03)
    orbGlass(c, r: r)
}

/// Heater shield, unit width about 0.74 at full size.
func shieldPath(_ o: CGPoint, _ s: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let top = o.y - s * 1.0, bot = o.y + s * 1.08
    p.move(to: P(o.x, top))
    p.addCurve(to: P(o.x + s * 0.86, top + s * 0.30), control1: P(o.x + s * 0.22, top + s * 0.20), control2: P(o.x + s * 0.54, top + s * 0.30))
    p.addCurve(to: P(o.x, bot), control1: P(o.x + s * 0.92, top + s * 1.14), control2: P(o.x + s * 0.55, top + s * 1.74))
    p.addCurve(to: P(o.x - s * 0.86, top + s * 0.30), control1: P(o.x - s * 0.55, top + s * 1.74), control2: P(o.x - s * 0.92, top + s * 1.14))
    p.addCurve(to: P(o.x, top), control1: P(o.x - s * 0.54, top + s * 0.30), control2: P(o.x - s * 0.22, top + s * 0.20))
    p.closeSubpath()
    return p
}

func drawBlueShield(_ c: CGContext, _ o: CGPoint, _ s: CGFloat, mark: Bool) {
    c.radial(grad([(0, C(0x38C8FF, 0.65)), (0.74, C(0x38C8FF, 0.65)), (1, C(0x38C8FF, 0))]), o, min(s * 1.35, 0.47))
    let outer = shieldPath(o, s)
    c.stroke(outer, C(0x0A2C8A), s * 0.13)
    c.fillLinear(outer, grad([(0, C(0xE6FBFF)), (0.45, C(0x7FE4FF)), (1, C(0x28A4F4))]), P(o.x - s, o.y - s), P(o.x + s, o.y + s))
    let inner = shieldPath(P(o.x, o.y + s * 0.03), s * 0.8)
    c.fillLinear(inner, grad([(0, C(0x57CFFF)), (0.55, C(0x1E9AF8)), (1, C(0x0F5FD8))]), P(o.x, o.y - s * 0.8), P(o.x, o.y + s))
    // Right half in a lighter facet, as the sheet has it.
    c.with {
        c.clip(inner)
        c.fill(polygon([P(o.x, o.y - s * 1.2), P(o.x + s * 1.1, o.y - s * 1.2), P(o.x + s * 1.1, o.y + s * 1.2), P(o.x, o.y + s * 1.2)]), C.white.alpha(0.14))
        c.blob(grad([(0, C.white.alpha(0.75)), (1, C.white.alpha(0))]), P(o.x - s * 0.34, o.y - s * 0.52), s * 0.42, s * 0.22, rot: -22)
    }
    if mark {
        let check = polyline([P(o.x - s * 0.38, o.y + s * 0.04), P(o.x - s * 0.08, o.y + s * 0.36), P(o.x + s * 0.42, o.y - s * 0.28)])
        c.stroke(check, C(0x0A2C8A), s * 0.30, join: .round)
        c.stroke(check, .white, s * 0.17, join: .round)
    }
}

private func drawShieldPower(_ c: CGContext) { drawBlueShield(c, P(0.5, 0.49), 0.385, mark: true) }

private func drawChainBurst(_ c: CGContext) {
    let r: CGFloat = 0.40
    c.radial(grad([(0, C(0xA050FF, 0.75)), (r / 0.47, C(0xA050FF, 0.75)), (1, C(0xA050FF, 0))]), mid, 0.47)
    c.fill(circle(mid, r), C(0x1E0660))
    c.fillRadial(circle(mid, r * 0.96), grad([(0, C(0x0E0230)), (0.35, C(0x3A10A0)), (1, C(0x6A22DA))]), mid, r)
    // Tapered spiral arms, built outside in.
    let arms = 3
    for k in 0..<arms {
        let start = CGFloat(k) * 2 * .pi / CGFloat(arms)
        let steps = 28
        var outerEdge = [CGPoint](), innerEdge = [CGPoint]()
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let a = start + t * 2.9 * .pi * 0.72
            let rr = r * 0.93 * (1 - t) + r * 0.05
            let w = r * 0.30 * (1 - t) * sin(min(t * 6, 1) * .pi / 2) + r * 0.012
            outerEdge.append(P(0.5 + cos(a) * rr, 0.5 + sin(a) * rr))
            innerEdge.append(P(0.5 + cos(a - 0.10) * (rr - w), 0.5 + sin(a - 0.10) * (rr - w)))
        }
        let path = CGMutablePath()
        path.addLines(between: outerEdge + innerEdge.reversed())
        path.closeSubpath()
        c.with {
            c.clip(circle(mid, r * 0.96))
            c.fillRadial(path, grad([(0, C(0xFFFFFF)), (0.35, C(0xE8B4FF)), (0.7, C(0xB05CFF)), (1, C(0x8A3CF0))]), mid, r)
        }
    }
    c.glow(C(0xF0D0FF), mid, r * 0.42, 0.9)
    c.strokeLinear(circle(mid, r * 0.97), 0.022, grad([(0, C(0xE8C8FF)), (0.5, C(0x9A58FF)), (1, C(0xD8A8FF))]), P(0.2, 0.2), P(0.8, 0.8))
    c.blob(grad([(0, C.white.alpha(0.7)), (1, C.white.alpha(0))]), P(0.5 - r * 0.40, 0.5 - r * 0.58), r * 0.26, r * 0.1, rot: -32)
}
