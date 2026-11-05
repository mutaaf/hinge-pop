import CoreGraphics

// Eye and mouth kit. Measurements are multiples of the body radius, from the body centre.

struct Eye {
    var dx: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat
    var tilt: CGFloat = 0
    var pupilRx: CGFloat, pupilRy: CGFloat
    var pupilIn: CGFloat = 0
    var pupilDy: CGFloat = 0
    var pupilGlobalDx: CGFloat = 0
    /// Fraction of the eye covered from the top. Zero means no eyelid.
    var lid: CGFloat = 0
    /// Eyelid and brow slope, degrees. Positive is angry (inner end down), negative is sad.
    var slope: CGFloat = 0
    var lidColor: C = .ink
    var browT: CGFloat = 0
    var browGap: CGFloat = 0
    var sclera: C = .white
    var scleraLow: C? = nil
    var pupil: C = C(0x120826)
    var outline: CGFloat = 0.055
    var outlineColor: C = .ink
    var browColor: C = .ink
    var starGleam = false
}

func drawEyes(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, _ e: Eye, small: Bool) {
    drawEye(c, o, r, e, side: -1, small: small)
    drawEye(c, o, r, e, side: 1, small: small)
}

/// side -1 is the left of the picture, +1 the right. Highlights do not mirror: light has one source.
func drawEye(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, _ spec: Eye, side s: CGFloat, small: Bool) {
    var e = spec
    if small {
        e.rx *= 1.08; e.ry *= 1.08
        e.pupilRx *= 1.08; e.pupilRy *= 1.08
        e.outline *= 1.35
        e.browT *= 1.25
    }
    let at = P(o.x + s * e.dx * r, o.y + e.y * r)
    let rx = e.rx * r, ry = e.ry * r
    let rot = s * e.tilt
    let shape = ellipse(at, rx, ry, rot: rot)
    let lineW = e.outline * r

    c.fill(ellipse(at, rx + lineW, ry + lineW, rot: rot), e.outlineColor)
    let k = tan(rad(e.slope))
    let lidY = at.y - ry + e.lid * 2 * ry
    func yLid(_ x: CGFloat) -> CGFloat { lidY - s * (x - at.x) * k }

    c.with {
        c.clip(shape)
        let low = e.scleraLow ?? e.sclera.mix(C(0xC6D2F2), 0.75)
        c.linear(grad([(0, e.sclera), (0.58, e.sclera), (1, low)]), P(at.x, at.y - ry), P(at.x, at.y + ry))
        let pc = P(at.x - s * e.pupilIn * r + e.pupilGlobalDx * r, at.y + e.pupilDy * r)
        c.fill(ellipse(pc, e.pupilRx * r, e.pupilRy * r, rot: rot), e.pupil)
        let hr = min(e.pupilRx, e.pupilRy) * r
        let hi = P(pc.x - hr * 0.30, pc.y - e.pupilRy * r * 0.42)
        if e.starGleam {
            c.fill(polygon(starPoints(hi, hr * 0.62, hr * 0.2, 4)), .white)
            if !small { c.fill(circle(P(pc.x + hr * 0.42, pc.y + e.pupilRy * r * 0.42), hr * 0.17), C.white.alpha(0.95)) }
        } else {
            c.fill(circle(hi, hr * (small ? 0.50 : 0.42)), .white)
            if !small { c.fill(circle(P(pc.x + hr * 0.42, pc.y + e.pupilRy * r * 0.46), hr * 0.17), C.white.alpha(0.9)) }
        }
        if e.lid > 0 {
            let x0 = at.x - rx * 1.4, x1 = at.x + rx * 1.4
            c.fill(polygon([P(x0, at.y - ry * 2), P(x1, at.y - ry * 2), P(x1, yLid(x1)), P(x0, yLid(x0))]), e.lidColor)
            c.stroke(polyline([P(x0, yLid(x0)), P(x1, yLid(x1))]), e.outlineColor, lineW * 1.1)
        }
    }

    if e.browT > 0 {
        // Brow rides the lid line, thick at the inner end, thin at the outer.
        let inner = at.x - s * rx * 1.14, outer = at.x + s * rx * 1.12
        let gap = e.browGap * r
        let t = e.browT * r
        let yi = yLid(inner) - gap, yo = yLid(outer) - gap
        let brow = polygon([P(inner, yi - t * 0.62), P(outer, yo - t * 0.42), P(outer, yo + t * 0.02), P(inner, yi + t * 0.38)], round: t * 0.28)
        c.fill(brow, e.browColor)
    }
}

func cheeks(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, dx: CGFloat, y: CGFloat, _ col: C) {
    let g = softGrad(col, col.a)
    c.blob(g, P(o.x - dx * r, o.y + y * r), r * 0.22, r * 0.15)
    c.blob(g, P(o.x + dx * r, o.y + y * r), r * 0.22, r * 0.15)
}

private func lineScale(_ small: Bool) -> CGFloat { small ? 1.35 : 1 }
private let mouthDark = C(0x2A0A2E)
private let tongue = C(0xFF4F7E)

/// The sheet's big open happy mouth: nearly flat on top, deep round bottom.
func mouthOpenSmile(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, small: Bool) {
    let W = w * r * (small ? 1.12 : 1), H = h * r * (small ? 1.1 : 1), cy = o.y + y * r
    let p = CGMutablePath()
    p.move(to: P(o.x - W, cy - H * 0.18))
    p.addQuadCurve(to: P(o.x + W, cy - H * 0.18), control: P(o.x, cy - H * 0.02))
    p.addCurve(to: P(o.x - W, cy - H * 0.18), control1: P(o.x + W * 1.04, cy + H * 1.02), control2: P(o.x - W * 1.04, cy + H * 1.02))
    p.closeSubpath()
    c.stroke(p, C.ink, r * 0.075 * lineScale(small))
    c.fill(p, mouthDark)
    c.with {
        c.clip(p)
        c.fillRadial(ellipse(P(o.x + W * 0.04, cy + H * 0.86), W * 0.74, H * 0.56), grad([(0, C(0xFF7FA0)), (1, tongue)]),
                     P(o.x, cy + H * 0.5), W * 0.8)
    }
}

/// Delighted grin with a band of teeth.
func mouthGrin(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, small: Bool) {
    let W = w * r, H = h * r, cy = o.y + y * r
    let p = CGMutablePath()
    p.move(to: P(o.x - W, cy - H * 0.12))
    p.addQuadCurve(to: P(o.x + W, cy - H * 0.12), control: P(o.x, cy + H * 0.14))
    p.addCurve(to: P(o.x - W, cy - H * 0.12), control1: P(o.x + W * 0.92, cy + H * 1.02), control2: P(o.x - W * 0.92, cy + H * 1.02))
    p.closeSubpath()
    c.stroke(p, C(0x3A1800), r * 0.07 * lineScale(small))
    c.fill(p, C(0x5A1408))
    c.with {
        c.clip(p)
        c.fill(ellipse(P(o.x, cy + H * 0.92), W * 0.62, H * 0.42), tongue)
        let teeth = CGMutablePath()
        teeth.move(to: P(o.x - W * 1.1, cy - H * 0.3))
        teeth.addLine(to: P(o.x + W * 1.1, cy - H * 0.3))
        teeth.addLine(to: P(o.x + W * 1.1, cy + H * 0.1))
        teeth.addQuadCurve(to: P(o.x - W * 1.1, cy + H * 0.1), control: P(o.x, cy + H * 0.5))
        teeth.closeSubpath()
        c.fill(teeth, .white)
    }
}

/// Fast's gritted grimace: a rounded slot of teeth.
func mouthGrit(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, small: Bool) {
    let W = w * r * (small ? 1.12 : 1), H = h * r * (small ? 1.2 : 1), cy = o.y + y * r
    let p = CGMutablePath()
    p.move(to: P(o.x - W, cy + H * 0.42))
    p.addQuadCurve(to: P(o.x + W, cy - H * 0.10), control: P(o.x + W * 0.05, cy - H * 0.92))
    p.addQuadCurve(to: P(o.x - W, cy + H * 0.42), control: P(o.x + W * 0.05, cy + H * 1.02))
    p.closeSubpath()
    c.stroke(p, C.ink, r * 0.075 * lineScale(small))
    c.fill(p, .white)
    c.with {
        c.clip(p)
        let col = C(0x3A1040)
        let lw = r * (small ? 0.06 : 0.035)
        c.stroke(polyline([P(o.x - W, cy + H * 0.2), P(o.x + W, cy - H * 0.05)]), col, lw)
        let n = small ? 2 : 3
        for i in 1...n {
            let x = o.x - W + 2 * W * CGFloat(i) / CGFloat(n + 1)
            c.stroke(polyline([P(x, cy - H), P(x, cy + H)]), col, lw)
        }
    }
}

/// Plain stern frown line.
func mouthFrown(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, y: CGFloat, w: CGFloat, depth: CGFloat, small: Bool) {
    let W = w * r, cy = o.y + y * r
    c.stroke(quad(P(o.x - W, cy + depth * r * 0.7), P(o.x, cy - depth * r * 1.1), P(o.x + W, cy + depth * r * 0.7)),
             C.ink, r * 0.105 * lineScale(small))
}

/// Shivering or worried line.
func mouthWobble(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, y: CGFloat, w: CGFloat, small: Bool, amp: CGFloat, color: C = .ink) {
    let W = w * r, cy = o.y + y * r, A = amp * r
    let n = small ? 3 : 4
    var pts = [CGPoint]()
    for i in 0...n {
        let t = CGFloat(i) / CGFloat(n)
        let arch = (2 * t - 1) * (2 * t - 1) * r * 0.13
        pts.append(P(o.x - W + 2 * W * t, cy + arch + (i % 2 == 0 ? A : -A)))
    }
    c.stroke(smooth(pts), color, r * 0.095 * lineScale(small))
}

/// Sly lopsided smirk with a cheek tick.
func mouthSmirk(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, y: CGFloat, small: Bool) {
    let cy = o.y + y * r
    let a = P(o.x - r * 0.26, cy + r * 0.08), b = P(o.x + r * 0.32, cy - r * 0.04)
    let line = quad(a, P(o.x + r * 0.12, cy + r * 0.26), b)
    c.stroke(line, C.ink, r * 0.11 * lineScale(small))
}

/// Repel's bellow: a wide trapezoid with an upper row of teeth.
func mouthRoar(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, small: Bool) {
    let W = w * r * (small ? 1.1 : 1), H = h * r * (small ? 1.12 : 1), cy = o.y + y * r
    let p = CGMutablePath()
    p.move(to: P(o.x - W * 0.58, cy - H * 0.52))
    p.addQuadCurve(to: P(o.x + W * 0.58, cy - H * 0.52), control: P(o.x, cy - H * 0.82))
    p.addQuadCurve(to: P(o.x + W, cy + H * 0.46), control: P(o.x + W * 1.0, cy - H * 0.2))
    p.addQuadCurve(to: P(o.x - W, cy + H * 0.46), control: P(o.x, cy + H * 0.12))
    p.addQuadCurve(to: P(o.x - W * 0.58, cy - H * 0.52), control: P(o.x - W * 1.0, cy - H * 0.2))
    p.closeSubpath()
    c.stroke(p, C.ink, r * 0.075 * lineScale(small))
    c.fill(p, C(0x3A0A10))
    c.with {
        c.clip(p)
        c.fill(ellipse(P(o.x, cy + H * 0.62), W * 0.62, H * 0.42), tongue)
        c.fill(polygon([P(o.x - W, cy - H), P(o.x + W, cy - H), P(o.x + W, cy - H * 0.32), P(o.x - W, cy - H * 0.32)]), .white)
    }
}

/// Boss snarl: arching mouth, two big fangs and a jagged lower row.
func mouthFangs(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, small: Bool) {
    let W = w * r, H = h * r, cy = o.y + y * r
    let p = CGMutablePath()
    p.move(to: P(o.x - W, cy + H * 0.62))
    p.addQuadCurve(to: P(o.x + W, cy + H * 0.62), control: P(o.x, cy - H * 1.5))
    p.addQuadCurve(to: P(o.x - W, cy + H * 0.62), control: P(o.x, cy + H * 0.72))
    p.closeSubpath()
    c.stroke(p, C(0x12022A), r * 0.08 * lineScale(small))
    c.fill(p, C(0x2A0420))
    c.with {
        c.clip(p)
        c.fill(ellipse(P(o.x, cy + H * 0.62), W * 0.42, H * 0.34), C(0xE0355E))
        let n = small ? 2 : 3
        for i in 0..<n {
            let t = (CGFloat(i) + 0.5) / CGFloat(n)
            for s: CGFloat in [-1, 1] {
                let x = o.x + s * W * (0.13 + t * 0.72)
                let top = cy - H * 0.65
                let len = H * (i == n - 1 ? 0.95 : 0.8) + (i == 0 ? H * 0.1 : 0)
                let wid = W * (small ? 0.2 : 0.14)
                c.fill(polygon([P(x - wid, top), P(x + wid, top), P(x, top + len + H * 0.32)]), C(0xFFF8E8))
            }
        }
    }
}

/// Boss in pain: a crooked open wail.
func mouthHurt(_ c: CGContext, _ o: CGPoint, _ r: CGFloat, y: CGFloat, small: Bool) {
    let cy = o.y + y * r, W = r * 0.40, H = r * 0.26
    let p = smooth([P(o.x - W, cy + H * 0.2), P(o.x - W * 0.45, cy - H * 0.45), P(o.x + W * 0.1, cy - H * 0.3),
                    P(o.x + W * 0.62, cy - H * 0.62), P(o.x + W, cy + H * 0.1), P(o.x + W * 0.35, cy + H * 0.66), P(o.x - W * 0.4, cy + H * 0.72)], closed: true)
    c.stroke(p, C(0x12022A), r * 0.08 * lineScale(small))
    c.fill(p, C(0x2A0420))
    c.with {
        c.clip(p)
        c.fill(ellipse(P(o.x - W * 0.05, cy + H * 0.72), W * 0.5, H * 0.45), C(0xE0355E))
        if !small {
            c.fill(polygon([P(o.x - W * 0.5, cy - H * 0.7), P(o.x - W * 0.2, cy - H * 0.7), P(o.x - W * 0.34, cy - H * 0.05)]), C(0xFFF8E8))
            c.fill(polygon([P(o.x + W * 0.28, cy - H * 0.8), P(o.x + W * 0.58, cy - H * 0.8), P(o.x + W * 0.42, cy - H * 0.1)]), C(0xFFF8E8))
        }
    }
}

func sweat(_ c: CGContext, _ at: CGPoint, _ s: CGFloat, color: C = C(0xBDEFFF)) {
    let p = CGMutablePath()
    p.move(to: P(at.x, at.y - s))
    p.addCurve(to: P(at.x, at.y + s * 0.7), control1: P(at.x + s * 1.0, at.y + s * 0.0), control2: P(at.x + s * 0.8, at.y + s * 0.7))
    p.addCurve(to: P(at.x, at.y - s), control1: P(at.x - s * 0.8, at.y + s * 0.7), control2: P(at.x - s * 1.0, at.y + s * 0.0))
    p.closeSubpath()
    c.stroke(p, C(0x123E9E), s * 0.28)
    c.fill(p, color)
    c.fill(circle(P(at.x - s * 0.18, at.y + s * 0.15), s * 0.2), C.white)
}
