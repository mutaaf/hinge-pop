import CoreGraphics

/// Every normal bubble's body is a circle of this radius at the image centre.
let bodyRadius: CGFloat = 0.36
let bossBodyRadius: CGFloat = 0.35
/// Under this point size faces get bigger features and fussy details drop out.
let smallBelow: CGFloat = 56
let mid = P(0.5, 0.5)

struct Palette {
    var glow: C, edge: C, light: C, base: C, deep: C, bounce: C
    var rim: C = .white
}

extension Palette {
    static let basic = Palette(glow: C(0x37C8FF), edge: C(0x0C4CC4), light: C(0xA8F6FF), base: C(0x2CC4FF), deep: C(0x1C7CF2), bounce: C(0xC860FF))
    static let fast = Palette(glow: C(0xFF3FD2), edge: C(0x6A0B7E), light: C(0xFFB1EC), base: C(0xF43FCF), deep: C(0xA10FA8), bounce: C(0xFF8BE0))
    static let armored = Palette(glow: C(0x7E9DE0), edge: C(0x20283E), light: C(0xC2CCDA), base: C(0x8290A6), deep: C(0x48546C), bounce: C(0xA7B8E8))
    static let magnetic = Palette(glow: C(0xA65CFF), edge: C(0x260A6E), light: C(0xC79BFF), base: C(0x7C33E6), deep: C(0x3E12A0), bounce: C(0xE07CFF))
    static let repel = Palette(glow: C(0xFF5A1F), edge: C(0x760E08), light: C(0xFFC04D), base: C(0xFF5C1E), deep: C(0xC11610), bounce: C(0xFFD24A))
    static let golden = Palette(glow: C(0xFFB300), edge: C(0xB25A00), light: C(0xFFFAB0), base: C(0xFFD21E), deep: C(0xF79A00), bounce: C(0xFFF2A0))
    static let boss = Palette(glow: C(0xA53DFF), edge: C(0x24054E), light: C(0xDC9CFF), base: C(0xA03AE8), deep: C(0x5C14A8), bounce: C(0xFF5FCB))
    static let bossHurt = Palette(glow: C(0xE0409C), edge: C(0x2E0640), light: C(0xD98CD8), base: C(0x8D2F9E), deep: C(0x420B60), bounce: C(0xFF5F90))
}

/// The glossy ball all bubbles are made of. Layers run from the outside in:
/// halo, dark edge, body shade, bounced light, edge darkening, sheen, speculars, rim.
func gloss(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, _ p: Palette, small: Bool, halo: CGFloat = 0.7, spec: CGFloat = 1) {
    if halo > 0 {
        let hr = min(r * 1.27, 0.46)
        c.radial(grad([(0, p.glow.alpha(halo)), (r * 0.9 / hr, p.glow.alpha(halo)), (1, p.glow.alpha(0))]), o, hr)
    }
    c.fill(circle(o, r), p.edge)
    let inner = r * 0.965
    c.with {
        c.clip(circle(o, inner))
        // Body: light falls from the upper left.
        let focal = P(o.x - r * 0.28, o.y - r * 0.42)
        c.radial(grad([(0, p.light), (0.40, p.base), (0.92, p.deep), (1, p.deep.mix(p.edge, 0.25))]),
                 P(o.x + r * 0.02, o.y + r * 0.03), r * 1.03, from: focal, extend: true)
        // Bounced colour along the bottom, the iridescent lift the concept bubbles have.
        c.blob(softGrad(p.bounce, 0.95), P(o.x + r * 0.06, o.y + r * 0.92), r * 1.05, r * 0.66)
        // Top dome sheen.
        c.blob(grad([(0, C.white.alpha(0.34)), (0.6, C.white.alpha(0.2)), (1, C.white.alpha(0))]),
               P(o.x - r * 0.04, o.y - r * 0.62), r * 0.72, r * 0.36)
        // Specular window and its small companion.
        if spec > 0 {
            c.blob(grad([(0, C.white.alpha(0.98 * spec)), (0.55, C.white.alpha(0.9 * spec)), (0.82, C.white.alpha(0.4 * spec)), (1, C.white.alpha(0))]),
                   P(o.x - r * 0.34, o.y - r * 0.72), r * 0.27, r * 0.125, rot: -22)
            c.fill(circle(P(o.x + r * 0.30, o.y - r * 0.76), r * 0.05), C.white.alpha(0.8 * spec))
        }
        if !small {
            // Lower glints, soft as on the sheet's hero bubble.
            let glint = grad([(0, C.white.alpha(0.62)), (0.5, C.white.alpha(0.42)), (1, C.white.alpha(0))])
            c.blob(glint, P(o.x - r * 0.60, o.y + r * 0.52), r * 0.25, r * 0.075, rot: 48)
            c.blob(glint, P(o.x + r * 0.42, o.y + r * 0.72), r * 0.20, r * 0.05, rot: -30)
        }
    }
    // Rim light hugging the edge: bright upper left, gone at the sides, back softly at lower right.
    c.strokeLinear(circle(o, r * 0.945), r * (small ? 0.06 : 0.042),
                   grad([(0, p.rim.alpha(0.9)), (0.40, p.rim.alpha(0.1)), (0.62, p.rim.alpha(0.0)), (1, p.rim.alpha(0.55))]),
                   P(o.x - r * 0.7, o.y - r * 0.7), P(o.x + r * 0.7, o.y + r * 0.7))
}

func drawBubble(_ kind: BubbleKind, _ c: CGContext, small: Bool) {
    let r = bodyRadius
    switch kind {
    case .basic:
        gloss(c, mid, r, .basic, small: small)
        let eye = Eye(dx: 0.43, y: -0.15, rx: 0.285, ry: 0.395, tilt: 8, pupilRx: 0.205, pupilRy: 0.30, pupilIn: 0.055, pupilDy: 0.03)
        drawEyes(c, mid, r, eye, small: small)
        mouthOpenSmile(c, mid, r, y: 0.42, w: 0.30, h: 0.42, small: small)

    case .fast:
        drawFastStreaks(c, r)
        gloss(c, mid, r, .fast, small: small, halo: 0.55)
        let eye = Eye(dx: 0.42, y: -0.08, rx: 0.27, ry: 0.30, tilt: 4, pupilRx: 0.165, pupilRy: 0.20, pupilIn: 0.0, pupilDy: 0.02, pupilGlobalDx: -0.07,
                      lid: 0.30, slope: 24, lidColor: Palette.fast.deep, browT: 0.13)
        drawEyes(c, mid, r, eye, small: small)
        mouthGrit(c, mid, r, y: 0.42, w: 0.33, h: 0.20, small: small)

    case .armored:
        gloss(c, mid, r, .armored, small: small, halo: 0.5, spec: 0)
        drawArmorFace(c, r, small: small, cracked: false)
        drawHelmet(c, r, small: small, cracked: false)

    case .armoredCracked:
        gloss(c, mid, r, .armored, small: small, halo: 0.5, spec: 0.6)
        drawArmorFace(c, r, small: small, cracked: true)
        drawHelmet(c, r, small: small, cracked: true)

    case .magnetic:
        drawMagneticRing(c, front: false, small: small)
        gloss(c, mid, r, .magnetic, small: small)
        let base = Eye(dx: 0.41, y: -0.26, rx: 0.26, ry: 0.27, pupilRx: 0.16, pupilRy: 0.19, pupilIn: 0, pupilDy: 0.035, pupilGlobalDx: 0.09,
                       lid: 0.40, slope: 10, lidColor: Palette.magnetic.deep, browT: 0.085)
        var raised = base; raised.lid = 0; raised.slope = -10; raised.browGap = -0.02; raised.browT = 0.085; raised.y = -0.24
        drawEye(c, mid, r, base, side: -1, small: small)
        drawEye(c, mid, r, raised, side: 1, small: small)
        mouthSmirk(c, mid, r, y: 0.14, small: small)
        drawMagneticRing(c, front: true, small: small)

    case .repel:
        drawPushMarks(c, r, small: small)
        gloss(c, mid, r, .repel, small: small, halo: 0.6)
        let eye = Eye(dx: 0.42, y: -0.10, rx: 0.27, ry: 0.28, pupilRx: 0.16, pupilRy: 0.17, pupilIn: 0.06, pupilDy: 0.05,
                      lid: 0.40, slope: 32, lidColor: Palette.repel.deep, browT: 0.17)
        drawEyes(c, mid, r, eye, small: small)
        mouthRoar(c, mid, r, y: 0.40, w: 0.34, h: 0.28, small: small)

    case .golden:
        drawGoldenRays(c, r, small: small)
        gloss(c, mid, r, .golden, small: small, halo: 0.8)
        cheeks(c, mid, r, dx: 0.64, y: 0.24, C(0xFF6A3C, 0.55))
        var eye = Eye(dx: 0.42, y: -0.12, rx: 0.27, ry: 0.335, tilt: 6, pupilRx: 0.20, pupilRy: 0.27, pupilIn: 0.04, pupilDy: 0.02,
                      browT: small ? 0 : 0.07, browGap: 0.13)
        eye.slope = -12
        eye.starGleam = !small
        eye.outlineColor = C(0x4A2200)
        eye.browColor = C(0x8A4200)
        eye.pupil = C(0x2A1000)
        drawEyes(c, mid, r, eye, small: small)
        mouthGrin(c, mid, r, y: 0.34, w: 0.46, h: 0.44, small: small)
        drawCrown(c, cx: 0.5, baseY: 0.215, w: 0.27, h: 0.135, small: small)
        if !small {
            sparkle(c, P(0.74, 0.26), 0.045, C.white)
            sparkle(c, P(0.27, 0.73), 0.03, C.white)
        }

    case .frozen:
        drawFrozen(c, r, small: small)

    case .boss:
        drawBoss(c, hurt: false, small: small)

    case .bossHurt:
        drawBoss(c, hurt: true, small: small)
    }
}

// MARK: - Fast

private func drawFastStreaks(_ c: CGContext, _ r: CGFloat) {
    c.blob(softGrad(C(0xFF3FD2), 0.6), P(0.74, 0.47), 0.23, 0.34)
    let streaks: [(y: CGFloat, x: CGFloat, w: CGFloat)] = [
        (0.20, 0.90, 0.075), (0.335, 0.955, 0.095), (0.475, 0.955, 0.095), (0.615, 0.945, 0.09), (0.745, 0.865, 0.07),
    ]
    let g = grad([(0, C(0xFFD8F6)), (0.45, C(0xFF4FD8)), (1, C(0xD22FE0, 0.25))])
    for s in streaks {
        let start = P(0.56, s.y + 0.045)
        let end = P(s.x, s.y - 0.03)
        c.fillLinear(taper(start, end, width: s.w, at: 0.55), g, P(0.72, 0.5), P(s.x, 0.5))
    }
}

// MARK: - Armored

private func drawArmorFace(_ c: CGContext, _ r: CGFloat, small: Bool, cracked: Bool) {
    var eye = Eye(dx: 0.42, y: 0.03, rx: 0.255, ry: 0.28, pupilRx: 0.16, pupilRy: 0.185, pupilIn: 0.05, pupilDy: 0.05,
                  lid: 0.2, slope: 20, lidColor: Palette.armored.deep, browT: 0)
    eye.outline = 0.06
    if cracked {
        var wide = eye; wide.ry = 0.32; wide.rx = 0.28; wide.lid = 0; wide.pupilRx = 0.13; wide.pupilRy = 0.15; wide.y = -0.04
        wide.pupilIn = 0.03; wide.pupilDy = 0.02
        wide.browT = 0
        drawEye(c, mid, r, eye, side: -1, small: small)
        drawEye(c, mid, r, wide, side: 1, small: small)
        mouthFrown(c, mid, r, y: 0.62, w: 0.18, depth: 0.09, small: small)
        if !small { sweat(c, P(mid.x + r * 0.42, mid.y - r * 0.70), r * 0.13) }
    } else {
        drawEyes(c, mid, r, eye, small: small)
        mouthFrown(c, mid, r, y: 0.62, w: 0.26, depth: 0.13, small: small)
    }
}

/// Helmet outline: dome over the top of the bubble, rim dipping into a nose guard.
private func helmetDome(_ r: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let R = r * 1.06, y0 = mid.y - r * 0.02
    p.move(to: P(mid.x - R, y0))
    p.addCurve(to: P(mid.x, mid.y - r * 1.13), control1: P(mid.x - R, mid.y - r * 0.68), control2: P(mid.x - r * 0.62, mid.y - r * 1.13))
    p.addCurve(to: P(mid.x + R, y0), control1: P(mid.x + r * 0.62, mid.y - r * 1.13), control2: P(mid.x + R, mid.y - r * 0.68))
    // Rim, with the sides lifted and sloping down to the centre like a scowl.
    p.addLine(to: P(mid.x + r * 0.90, mid.y + r * 0.04))
    p.addQuadCurve(to: P(mid.x + r * 0.15, mid.y - r * 0.10), control: P(mid.x + r * 0.55, mid.y - r * 0.28))
    p.addLine(to: P(mid.x + r * 0.09, mid.y + r * 0.30))
    p.addLine(to: P(mid.x, mid.y + r * 0.38))
    p.addLine(to: P(mid.x - r * 0.09, mid.y + r * 0.30))
    p.addLine(to: P(mid.x - r * 0.15, mid.y - r * 0.10))
    p.addQuadCurve(to: P(mid.x - r * 0.90, mid.y + r * 0.04), control: P(mid.x - r * 0.55, mid.y - r * 0.28))
    p.closeSubpath()
    return p
}

private func drawHelmet(_ c: CGContext, _ r: CGFloat, small: Bool, cracked: Bool) {
    let dome = helmetDome(r)
    let bite = polygon([
        P(mid.x + r * 1.5, mid.y - r * 1.4), P(mid.x + r * 0.02, mid.y - r * 1.4), P(mid.x + r * 0.10, mid.y - r * 0.92),
        P(mid.x - r * 0.08, mid.y - r * 0.74), P(mid.x + r * 0.13, mid.y - r * 0.56), P(mid.x + r * 0.04, mid.y - r * 0.38),
        P(mid.x + r * 0.30, mid.y - r * 0.34), P(mid.x + r * 0.22, mid.y - r * 0.10), P(mid.x + r * 0.34, mid.y + r * 0.30), P(mid.x + r * 1.5, mid.y + r * 0.30),
    ])
    c.with {
        if cracked {
            let keep = CGMutablePath()
            keep.addRect(CGRect(x: 0, y: 0, width: 1, height: 1))
            keep.addPath(bite)
            c.addPath(keep); c.clip(using: .evenOdd)
        }
        c.stroke(dome, C.ink, r * (small ? 0.13 : 0.10))
        // Steel, with the concept's blue-painted crown.
        c.fillLinear(dome, grad([(0, C(0xDDE6F2)), (0.3, C(0x9AA9C0)), (0.62, C(0x66748E)), (1, C(0x3C465E))]),
                     P(0.40, mid.y - r * 1.13), P(0.56, mid.y + r * 0.5))
        c.with {
            c.clip(dome)
            // Painted cap above the band.
            let cap = CGMutablePath()
            cap.addEllipse(in: CGRect(x: mid.x - r * 1.0, y: mid.y - r * 1.34, width: r * 2, height: r * 1.02))
            c.fillLinear(cap, grad([(0, C(0x8FC4FF)), (0.45, C(0x3F7FE6)), (1, C(0x1F4AAE))]), P(0.42, mid.y - r * 1.2), P(0.52, mid.y - r * 0.35))
            c.stroke(cap, C(0x1B2340, 0.85), r * 0.05)
            // Sheen along the dome.
            c.blob(grad([(0, C.white.alpha(0.9)), (0.5, C.white.alpha(0.55)), (1, C.white.alpha(0))]),
                   P(mid.x - r * 0.40, mid.y - r * 0.86), r * 0.36, r * 0.14, rot: -24)
            // Lower edge highlight on the band.
            c.stroke(polyline([P(mid.x - r * 0.9, mid.y - r * 0.20), P(mid.x + r * 0.9, mid.y - r * 0.20)]), C.white.alpha(0), 0)
        }
        // Nose guard centre line.
        c.stroke(polyline([P(mid.x, mid.y - r * 0.28), P(mid.x, mid.y + r * 0.28)]), C.white.alpha(0.5), r * 0.04)
        // Rivets.
        let rivets: [CGPoint] = small
            ? [P(-0.62, -0.16), P(0.62, -0.16)]
            : [P(-0.82, -0.10), P(-0.50, -0.27), P(0.50, -0.27), P(0.82, -0.10), P(0, -0.20), P(-0.32, -0.40), P(0.32, -0.40)]
        for v in rivets {
            let at = P(mid.x + v.x * r, mid.y + v.y * r)
            let rr = r * (small ? 0.105 : 0.066)
            c.fill(circle(at, rr * 1.25), C(0x1B2340))
            c.fillRadial(circle(at, rr), grad([(0, .white), (0.5, C(0xB9C6D8)), (1, C(0x56637C))]),
                         at, rr * 1.2, from: P(at.x - rr * 0.35, at.y - rr * 0.4))
        }
    }
    if cracked {
        // Broken edge, thick dark with a bright inner lip, only where the helmet was.
        c.with {
            c.clip(dome)
            c.stroke(bite, C.ink, r * 0.11)
        }
        // Cracks running out across the steel.
        let cracks: [[CGPoint]] = small
            ? [[P(-0.08, -0.74), P(-0.36, -0.58), P(-0.34, -0.40)]]
            : [[P(-0.08, -0.74), P(-0.30, -0.68), P(-0.32, -0.52), P(-0.56, -0.44)],
               [P(0.04, -0.38), P(-0.22, -0.34), P(-0.28, -0.20)]]
        for line in cracks {
            c.stroke(polyline(line.map { P(mid.x + $0.x * r, mid.y + $0.y * r) }), C.ink, r * (small ? 0.075 : 0.045), join: .miter)
        }
        if !small {
            // A flying shard.
            let shard = polygon([P(0.75, 0.085), P(0.83, 0.11), P(0.80, 0.19), P(0.72, 0.15)], round: 0.006)
            c.stroke(shard, C.ink, r * 0.05)
            c.fillLinear(shard, grad([(0, C(0x8FC4FF)), (1, C(0x2F5FC4))]), P(0.74, 0.085), P(0.80, 0.19))
        }
    }
}

// MARK: - Magnetic

/// A thick Saturn band, split so the back half passes behind the body and the front across it.
private func drawMagneticRing(_ c: CGContext, front: Bool, small: Bool) {
    let o = P(0.5, 0.545), tilt: CGFloat = -16
    let outerRX: CGFloat = 0.445, outerRY: CGFloat = 0.185
    let innerRX: CGFloat = 0.365, innerRY: CGFloat = 0.115
    let band = CGMutablePath()
    var t = CGAffineTransform(translationX: o.x, y: o.y).rotated(by: rad(tilt))
    band.addEllipse(in: CGRect(x: -outerRX, y: -outerRY, width: outerRX * 2, height: outerRY * 2), transform: t)
    band.addEllipse(in: CGRect(x: -innerRX, y: -innerRY, width: innerRX * 2, height: innerRY * 2), transform: t)
    t = .identity
    c.with {
        // Half plane on the near or far side of the ring's major axis.
        c.translateBy(x: o.x, y: o.y); c.rotate(by: rad(tilt))
        c.clip(to: CGRect(x: -1, y: front ? 0 : -1, width: 2, height: 1))
        c.rotate(by: rad(-tilt)); c.translateBy(x: -o.x, y: -o.y)

        let solid = CGMutablePath(); solid.addPath(band)
        c.with {
            c.addPath(solid); c.clip(using: .evenOdd)
            c.linear(front
                     ? grad([(0, C(0xF2B8FF)), (0.3, C(0xD36BFF)), (0.7, C(0xA046FF)), (1, C(0xE8A6FF))])
                     : grad([(0, C(0x8B3DE0)), (0.5, C(0x5A1FB0)), (1, C(0x8B3DE0))]),
                     P(0.06, 0.6), P(0.94, 0.4))
        }
        // Crisp edges so the band holds up at small sizes.
        let edges = CGMutablePath()
        edges.addEllipse(in: CGRect(x: -outerRX, y: -outerRY, width: outerRX * 2, height: outerRY * 2),
                         transform: CGAffineTransform(translationX: o.x, y: o.y).rotated(by: rad(tilt)))
        edges.addEllipse(in: CGRect(x: -innerRX, y: -innerRY, width: innerRX * 2, height: innerRY * 2),
                         transform: CGAffineTransform(translationX: o.x, y: o.y).rotated(by: rad(tilt)))
        c.stroke(edges, front ? C(0x2A0A70) : C(0x1E0858), small ? 0.016 : 0.009)
        if front && !small {
            let mids = CGMutablePath()
            mids.addEllipse(in: CGRect(x: -0.41, y: -0.155, width: 0.82, height: 0.31),
                            transform: CGAffineTransform(translationX: o.x, y: o.y).rotated(by: rad(tilt)))
            c.stroke(mids, C.white.alpha(0.55), 0.005)
        }
    }
    if front {
        // Charged sparks riding the ring.
        let a = P(0.885, 0.435), b = P(0.13, 0.65)
        c.glow(C(0xE9B8FF), a, 0.06, 0.8)
        c.fill(circle(a, small ? 0.026 : 0.02), .white)
        if !small {
            c.glow(C(0xE9B8FF), b, 0.045, 0.7)
            c.fill(circle(b, 0.014), .white)
        }
    }
}

// MARK: - Repel

private func drawPushMarks(_ c: CGContext, _ r: CGFloat, small: Bool) {
    let n = 10
    for i in 0..<n {
        let a = rad(CGFloat(i) * 360 / CGFloat(n) - 90 + 18)
        let d = P(cos(a), sin(a))
        let inner = P(0.5 + d.x * (r + 0.022), 0.5 + d.y * (r + 0.022))
        let outer = P(0.5 + d.x * 0.462, 0.5 + d.y * 0.462)
        let n2 = P(-d.y, d.x)
        let w0: CGFloat = small ? 0.016 : 0.01, w1: CGFloat = small ? 0.042 : 0.036
        // Wedge that widens as it goes out, reading as force leaving the body.
        let path = polygon([P(inner.x + n2.x * w0, inner.y + n2.y * w0), P(outer.x + n2.x * w1, outer.y + n2.y * w1),
                            P(outer.x - n2.x * w1, outer.y - n2.y * w1), P(inner.x - n2.x * w0, inner.y - n2.y * w0)], round: 0.006)
        c.fillLinear(path, grad([(0, C(0xFF7A1F)), (1, C(0xFFE34D))]), inner, outer)
    }
}

// MARK: - Golden

private func drawGoldenRays(_ c: CGContext, _ r: CGFloat, small: Bool) {
    let n = 12
    let pts = starPoints(mid, 0.462, r * 1.02, n, rot: 15)
    let spikes = polygon(pts, round: 0.008)
    c.stroke(spikes, C(0x8F4300), 0.012)
    c.fillRadial(spikes, grad([(0.7, C(0xFF9A00)), (0.85, C(0xFFC21F)), (1, C(0xFFF08A))]), mid, 0.462)
}

/// Shared gold crown, used by golden, boss and the logo.
func drawCrown(_ c: CGContext, cx: CGFloat, baseY: CGFloat, w: CGFloat, h: CGFloat, tilt: CGFloat = 0, small: Bool, jewel: C = C(0xFF2E63)) {
    c.with {
        c.translateBy(x: cx, y: baseY); c.rotate(by: rad(tilt))
        let u = w
        let pts = [P(-0.46 * u, 0), P(-0.56 * u, -0.74 * h), P(-0.23 * u, -0.40 * h), P(0, -1.0 * h),
                   P(0.23 * u, -0.40 * h), P(0.56 * u, -0.74 * h), P(0.46 * u, 0)]
        let body = polygon(pts, round: u * 0.035)
        let line = u * (small ? 0.13 : 0.09)
        c.stroke(body, C(0x4A1E00), line)
        c.fillLinear(body, grad([(0, C(0xFFF6A8)), (0.45, C(0xFFCE2E)), (1, C(0xF08A00))]), P(0, -h), P(0, 0))
        // Tips.
        let rb = u * (small ? 0.085 : 0.07)
        for tip in [pts[1], pts[3], pts[5]] {
            c.fill(circle(tip, rb + line * 0.45), C(0x4A1E00))
            c.fillRadial(circle(tip, rb), grad([(0, .white), (0.5, C(0xFFE76A)), (1, C(0xF59A00))]), tip, rb, from: P(tip.x - rb * 0.3, tip.y - rb * 0.3))
        }
        // Band and jewel.
        let bandH = h * 0.24
        let band = polygon([P(-0.47 * u, -bandH), P(0.47 * u, -bandH), P(0.46 * u, 0), P(-0.46 * u, 0)], round: u * 0.02)
        c.fillLinear(band, grad([(0, C(0xFFB01F)), (1, C(0xD9650A))]), P(0, -bandH), P(0, 0))
        let jr = bandH * (small ? 0.5 : 0.42)
        c.fill(circle(P(0, -bandH * 0.5), jr), jewel)
        c.fill(circle(P(-jr * 0.25, -bandH * 0.5 - jr * 0.25), jr * 0.35), C.white.alpha(0.9))
    }
}

/// Four-point twinkle.
func sparkle(_ c: CGContext, _ at: CGPoint, _ r: CGFloat, _ col: C) {
    c.glow(col, at, r * 1.15, 0.5)
    c.fill(polygon(starPoints(at, r, r * 0.17, 4)), col)
}

// MARK: - Frozen

private func drawFrozen(_ c: CGContext, _ r: CGFloat, small: Bool) {
    let R = r * 1.11
    func hex(_ radius: CGFloat, squash: CGFloat = 1) -> [CGPoint] {
        (0..<6).map { i in
            let a = rad(CGFloat(i) * 60 - 90)
            return P(0.5 + cos(a) * radius * squash, 0.5 + sin(a) * radius)
        }
    }
    let outer = hex(R)
    let inner = hex(R * 0.66, squash: 1.05)
    c.radial(grad([(0, C(0x6FD8FF, 0.6)), (0.78, C(0x6FD8FF, 0.6)), (1, C(0x6FD8FF, 0))]), mid, 0.462)
    let body = polygon(outer, round: 0.012)
    c.stroke(body, C(0x123E9E), small ? 0.03 : 0.022)
    c.fillLinear(body, grad([(0, C(0xC8F6FF)), (0.5, C(0x5CC6FF)), (1, C(0x2B86F0))]), P(0.3, 0.1), P(0.7, 0.9))
    c.with {
        c.clip(body)
        // Facets: each side of the bevel is lit by where it faces.
        let tones: [(C, C)] = [
            (C(0xE8FCFF, 0.85), C(0x9CE6FF, 0.55)), // upper right
            (C(0x7FD4FF, 0.55), C(0x3C9CF2, 0.5)),  // right
            (C(0x2F7FE6, 0.55), C(0x1E62D0, 0.65)), // lower right
            (C(0x3E8FEE, 0.45), C(0x2670DC, 0.6)),  // lower left
            (C(0xA8EBFF, 0.5), C(0x62BEFA, 0.45)),  // left
            (C(0xFFFFFF, 0.9), C(0xB8F0FF, 0.6)),   // upper left
        ]
        for i in 0..<6 {
            let j = (i + 1) % 6
            let q = polygon([outer[i], outer[j], inner[j], inner[i]])
            c.fillLinear(q, grad([(0, tones[i].0), (1, tones[i].1)]), outer[i], inner[j])
        }
        // Table of the crystal: a clear pale centre the face sits on.
        c.fillLinear(polygon(inner), grad([(0, C(0x9AE8FF, 0.9)), (0.55, C(0x58BEFF, 0.9)), (1, C(0x3C9AF4, 0.9))]), P(0.38, 0.24), P(0.62, 0.76))
        if !small {
            for i in 0..<6 { c.stroke(polyline([outer[i], inner[i]]), C.white.alpha(0.65), 0.0055) }
            c.stroke(polygon(inner), C.white.alpha(0.6), 0.0055)
            // Inner fractures.
            c.stroke(polyline([P(0.34, 0.33), P(0.41, 0.28)]), C.white.alpha(0.75), 0.008)
            c.stroke(polyline([P(0.68, 0.72), P(0.60, 0.77)]), C.white.alpha(0.5), 0.006)
        }
    }
    c.strokeLinear(polygon(hex(R * 0.965), round: 0.01), small ? 0.016 : 0.01,
                   grad([(0, C.white.alpha(0.95)), (0.5, C.white.alpha(0.3)), (1, C.white.alpha(0.7))]), P(0.2, 0.1), P(0.8, 0.9))
    // Glints on the upper left facet.
    c.fill(polygon([P(0.255, 0.30), P(0.40, 0.205), P(0.42, 0.235), P(0.285, 0.33)], round: 0.006), C.white.alpha(0.9))

    let col = C(0x0E2F7A)
    cheeks(c, mid, r, dx: 0.60, y: 0.30, C(0x8FA8FF, 0.6))
    var eye = Eye(dx: 0.40, y: -0.08, rx: 0.27, ry: 0.32, pupilRx: 0.18, pupilRy: 0.23, pupilIn: 0.03, pupilDy: -0.05,
                  lid: 0.20, slope: -20, lidColor: C(0x47A8F4), browT: 0.075)
    eye.browGap = 0.05
    eye.outlineColor = col
    eye.browColor = col
    eye.pupil = C(0x0B1B4C)
    drawEyes(c, mid, r, eye, small: small)
    mouthWobble(c, mid, r, y: 0.46, w: 0.24, small: small, amp: 0.028, color: col)
    if !small {
        // A cold tear, and frost flecks.
        sweat(c, P(mid.x - r * 0.52, mid.y + r * 0.40), r * 0.10, color: C(0xE8FAFF))
        sparkle(c, P(0.76, 0.22), 0.035, .white)
    }
}

// MARK: - Boss

private func drawBoss(_ c: CGContext, hurt: Bool, small: Bool) {
    let r = bossBodyRadius
    let pal: Palette = hurt ? .bossHurt : .boss

    // Flame-like spikes behind the body.
    let n = 14
    var pts = [CGPoint]()
    for i in 0..<(n * 2) {
        let a = rad(CGFloat(i) * 180 / CGFloat(n) - 90 + 12.8)
        let long = i % 2 == 0
        let rr: CGFloat = long ? (i % 4 == 0 ? 0.452 : 0.43) : r * 1.04
        pts.append(P(0.5 + cos(a) * rr, 0.5 + sin(a) * rr))
    }
    let spikes = polygon(pts, round: 0.006)
    c.radial(grad([(0, pal.glow.alpha(0.6)), (0.8, pal.glow.alpha(0.6)), (1, pal.glow.alpha(0))]), mid, 0.46)
    c.stroke(spikes, C(0x3A0A30), small ? 0.016 : 0.012)
    c.fillRadial(spikes, hurt
                 ? grad([(0.72, C(0x9A2A6A)), (0.88, C(0xC8508A)), (1, C(0xE8A0A8))])
                 : grad([(0.7, C(0xE85A00)), (0.86, C(0xFF9A0A)), (1, C(0xFFE050))]), mid, 0.452)

    gloss(c, mid, r, pal, small: small, halo: 0)

    if !small {
        // Lumps give the big ball some mass.
        for (v, s) in [(P(0.70, 0.38), 0.05), (P(0.78, 0.04), 0.04), (P(-0.72, 0.34), 0.045), (P(0.48, 0.70), 0.035)] as [(CGPoint, CGFloat)] {
            let at = P(mid.x + v.x * r, mid.y + v.y * r)
            c.fill(circle(at, r * CGFloat(s) * 1.5), pal.deep.alpha(0.55))
        }
    }

    // Scowl shadow, so the eyes sit in a dark mask.
    c.blob(softGrad(C(0x1E0444), 0.6), P(0.5, 0.47), r * 0.98, r * 0.5)

    let eyeY: CGFloat = -0.07
    let hot = Eye(dx: 0.40, y: eyeY, rx: 0.33, ry: 0.32, pupilRx: 0.075, pupilRy: 0.15, pupilIn: 0.05, pupilDy: 0.05,
                  lid: 0.36, slope: 28, lidColor: C(0x2C0660), browT: 0.21,
                  sclera: C(0xFFF04A), pupil: C(0x3A0A00), outline: 0.065, outlineColor: C(0x12022A), browColor: C(0x12022A))
    func ember(_ s: CGFloat, _ peak: CGFloat = 0.95) {
        let at = P(0.5 + s * 0.40 * r, 0.5 + eyeY * r)
        c.glow(C(0xFFC400), at, r * 0.62, peak)
    }

    if hurt {
        ember(-1, 0.7)
        var left = hot
        left.ry = 0.34; left.lid = 0.22; left.slope = -12; left.browT = 0.14; left.browGap = 0.09
        left.pupilRx = 0.06; left.pupilRy = 0.09; left.sclera = C(0xFFE27A); left.scleraLow = C(0xFF8A2A)
        drawEye(c, mid, r, left, side: -1, small: small)
        // Right eye squeezed shut: an X-like crease.
        let e = P(0.5 + 0.40 * r, 0.5 + eyeY * r)
        let w = r * 0.29
        let lw = r * (small ? 0.16 : 0.12)
        c.stroke(polyline([P(e.x - w, e.y - w * 0.65), P(e.x + w * 0.7, e.y), P(e.x - w, e.y + w * 0.65)]), C(0x12022A), lw * 1.5, join: .round)
        c.stroke(polyline([P(e.x - w, e.y - w * 0.65), P(e.x + w * 0.7, e.y), P(e.x - w, e.y + w * 0.65)]), C(0xFFD24A), lw * 0.55, join: .round)
        mouthHurt(c, mid, r, y: 0.46, small: small)
        drawBossCracks(c, r, small: small)
        if !small { sweat(c, P(0.5 + r * 0.82, 0.5 - r * 0.42), r * 0.14) }
    } else {
        ember(-1); ember(1)
        var eye = hot
        eye.scleraLow = C(0xFF8A00)
        drawEyes(c, mid, r, eye, small: small)
        mouthFangs(c, mid, r, y: 0.47, w: 0.48, h: 0.24, small: small)
    }
    let crownBase: CGFloat = 0.5 - r * 0.84
    drawCrown(c, cx: hurt ? 0.565 : 0.5, baseY: hurt ? crownBase + 0.008 : crownBase, w: 0.30, h: 0.122, tilt: hurt ? 14 : 0, small: small)
}

private func drawBossCracks(_ c: CGContext, _ r: CGFloat, small: Bool) {
    let lines: [[CGPoint]] = small
        ? [[P(0.94, 0.26), P(0.68, 0.36), P(0.66, 0.60)]]
        : [[P(0.94, 0.26), P(0.72, 0.36), P(0.70, 0.56), P(0.50, 0.64)],
           [P(-0.94, 0.28), P(-0.72, 0.38), P(-0.68, 0.60)],
           [P(0.72, 0.36), P(0.88, 0.52)]]
    for l in lines {
        c.stroke(polyline(l.map { P(0.5 + $0.x * r, 0.5 + $0.y * r) }), C(0x12022A), r * (small ? 0.075 : 0.045), join: .miter)
    }
}
