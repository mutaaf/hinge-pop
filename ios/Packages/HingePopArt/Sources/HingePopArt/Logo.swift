import CoreGraphics
import CoreText

/// height / width of `Art.logo`.
let logoAspect: CGFloat = 0.86

/// SF Rounded Black through the UI font descriptor, with a named rounded face as the fallback.
private func roundedBlack(_ size: CGFloat) -> CTFont {
    if let base = CTFontCreateUIFontForLanguage(.system, size, nil) {
        let traits: [String: Any] = [
            kCTFontWeightTrait as String: 0.62,
            "NSCTFontUIFontDesignTrait": "NSCTFontUIFontDesignRounded",
        ]
        let d = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(base), [kCTFontTraitsAttribute as String: traits] as CFDictionary)
        let f = CTFontCreateWithFontDescriptor(d, size, nil)
        if (CTFontCopyFamilyName(f) as String).contains("Rounded") { return f }
    }
    return CTFontCreateWithName("ArialRoundedMTBold" as CFString, size, nil)
}

private struct Letter { var ch: Character; var scale: CGFloat = 1; var rot: CGFloat = 0; var dy: CGFloat = 0 }

/// Lays letters out one by one, so each gets a small bounce, then returns a y-down path.
private func word(_ letters: [Letter], size: CGFloat, shear: CGFloat, rot: CGFloat, tracking: CGFloat, center: CGPoint) -> CGMutablePath {
    let font = roundedBlack(size)
    let out = CGMutablePath()
    var x: CGFloat = 0
    for l in letters {
        var uni = Array(String(l.ch).utf16)
        var glyph = CGGlyph()
        guard CTFontGetGlyphsForCharacters(font, &uni, &glyph, 1), let g = CTFontCreatePathForGlyph(font, glyph, nil) else { continue }
        var adv = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &adv, 1)
        // Glyph outlines are y-up, so flip first. Shear makes the italic lean.
        var t = CGAffineTransform(a: l.scale, b: 0, c: shear * l.scale, d: -l.scale, tx: 0, ty: 0)
        t = t.concatenating(CGAffineTransform(rotationAngle: rad(l.rot)))
        t = t.concatenating(CGAffineTransform(translationX: x, y: l.dy))
        out.addPath(g, transform: t)
        x += adv.width * l.scale + tracking
    }
    let b = out.boundingBoxOfPath
    var place = CGAffineTransform(translationX: -b.midX, y: -b.midY)
    place = place.concatenating(CGAffineTransform(rotationAngle: rad(rot)))
    place = place.concatenating(CGAffineTransform(translationX: center.x, y: center.y))
    return out.copy(using: &place)!.mutableCopy()!
}

/// Fattens the letters a touch past the Black weight so counters stay chunky.
private func fattened(_ p: CGPath, _ w: CGFloat) -> CGPath {
    // A real union: glyph and stroke wind opposite ways, so simply adding them leaves a seam.
    p.union(p.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 4))
}

/// Splits a path back into one path per closed contour.
private func solidList(_ p: CGPath) -> [CGPath] {
    var out = [CGPath]()
    var cur = CGMutablePath()
    p.applyWithBlock { el in
        let e = el.pointee
        switch e.type {
        case .moveToPoint: cur = CGMutablePath(); cur.move(to: e.points[0])
        case .addLineToPoint: cur.addLine(to: e.points[0])
        case .addQuadCurveToPoint: cur.addQuadCurve(to: e.points[1], control: e.points[0])
        case .addCurveToPoint: cur.addCurve(to: e.points[2], control1: e.points[0], control2: e.points[1])
        case .closeSubpath: cur.closeSubpath(); out.append(cur)
        @unknown default: break
        }
    }
    return out
}

func drawLogo(_ c: CGContext) {
    // Design space is 1000 wide, y down.
    c.scaleBy(x: 0.001, y: 0.001)
    // Everything but the halo sits slightly in, so strokes and sparkles clear the bounds.
    c.translateBy(x: 500 - 500 * 0.93, y: 0.43 * 1000 - 0.43 * 1000 * 0.93)
    c.scaleBy(x: 0.93, y: 0.93)
    let H: CGFloat = logoAspect * 1000

    let hinge = word([Letter(ch: "H", scale: 1.04), Letter(ch: "I"), Letter(ch: "N"), Letter(ch: "G"), Letter(ch: "E", scale: 1.04)],
                     size: 262, shear: 0.20, rot: -7.5, tracking: 3, center: P(500, H * 0.335))
    let pop = word([Letter(ch: "P", scale: 1.02, rot: -2), Letter(ch: "O", dy: 6), Letter(ch: "P", scale: 1.02, rot: 2)],
                   size: 368, shear: 0.05, rot: -4, tracking: 6, center: P(490, H * 0.685))

    let both = CGMutablePath(); both.addPath(hinge); both.addPath(pop)

    // Halo and lilac sticker edge.
    c.blob(softGrad(C(0x9A4CFF), 0.45), P(500, H * 0.5), 530, H * 0.53)
    // Each outline is normalized and every contour filled solid, so counters and the small
    // gaps between the two words go dark instead of showing lilac through.
    for (width, col) in [(92, C(0xB98CFF)), (76, C(0x150A3A))] as [(CGFloat, C)] {
        let outline = both.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 4).normalized()
        c.setFillColor(col.cg)
        for contour in solidList(outline) { c.addPath(contour); c.fillPath() }
    }

    // Extruded side walls.
    func walls(_ p: CGPath, _ top: C, _ bottom: C, _ depth: CGFloat) {
        let stroked = fattened(p, 7)
        let b = p.boundingBoxOfPath
        let n = 8
        for i in stride(from: n, through: 1, by: -1) {
            let d = depth * CGFloat(i) / CGFloat(n)
            c.with {
                c.translateBy(x: 0, y: d)
                c.clip(stroked)
                c.linear(grad([(0, top), (1, bottom)]), P(0, b.minY), P(0, b.maxY))
            }
        }
    }

    func face(_ p: CGPath, stops: [(CGFloat, C)], lip: C, shine: CGFloat) {
        let fat = fattened(p, 7)
        let b = p.boundingBoxOfPath
        c.with {
            c.clip(fat)
            c.fill(CGPath(rect: b.insetBy(dx: -30, dy: -30), transform: nil), lip)
            c.with {
                c.translateBy(x: 0, y: 5)
                c.clip(fat)
                c.translateBy(x: 0, y: -5)
                c.linear(grad(stops), P(0, b.minY), P(0, b.maxY))
            }
            // Wet gloss band across the upper letters.
            c.blob(grad([(0, C.white.alpha(shine)), (0.7, C.white.alpha(shine * 0.8)), (1, C.white.alpha(0))]),
                   P(b.midX, b.minY + b.height * 0.2), b.width * 0.62, b.height * 0.25, rot: -6)
        }
    }

    walls(pop, C(0xD8460A), C(0x9E2204), 20)
    face(pop, stops: [(0, C(0xFFF08A)), (0.42, C(0xFFCC1F)), (1, C(0xFF8214))], lip: C(0xFFF6B0), shine: 0.34)
    walls(hinge, C(0x0C48C8), C(0x082C94), 17)
    face(hinge, stops: [(0, C(0x8BF0FF)), (0.46, C(0x2BBEFF)), (1, C(0x1176EE))], lip: C(0xC4F6FF), shine: 0.32)

    // Crown on the H and sparkle off the E.
    let hb = hinge.boundingBoxOfPath
    drawCrown(c, cx: hb.minX + 118, baseY: hb.minY + 52, w: 138, h: 100, tilt: -18, small: false)
    let s = P(hb.maxX - 6, hb.minY + 10)
    sparkle(c, s, 60, .white)
    sparkle(c, P(hb.maxX + 22, hb.minY + 96), 22, C(0xFFE98A))
}

func drawAppIcon(_ c: CGContext) {
    // Full-bleed violet, brighter behind the bubble.
    c.fill(CGPath(rect: CGRect(x: 0, y: 0, width: 1, height: 1), transform: nil), C(0x1A0650))
    c.radial(grad([(0, C(0x8E3CF0)), (0.45, C(0x5A1CC0)), (0.85, C(0x2A0A78)), (1, C(0x1A0650))]), P(0.5, 0.46), 0.82, extend: true)

    // Glowing hinge behind and in front of the bubble.
    let hingeY: CGFloat = 0.835
    /// Irregular strides and swings, so it reads as a live arc and not a sine wave.
    func bolt(_ seed: UInt64, _ amp: CGFloat) -> CGPath {
        var d = Dice(seed)
        var pts = [P(-0.02, hingeY)]
        var x: CGFloat = -0.02
        var up = true
        while x < 1.02 {
            x += d.range(0.02, 0.075)
            pts.append(P(x, hingeY + (up ? -1 : 1) * pow(d.unit(), 1.4) * amp))
            up.toggle()
        }
        return polyline(pts)
    }
    func hinge() {
        c.blob(softGrad(C(0x38B8FF), 0.95), P(0.5, hingeY), 0.9, 0.12)
        c.blob(softGrad(C(0xB070FF), 0.55), P(0.5, hingeY), 0.5, 0.06)
        let a = bolt(7, 0.038), b = bolt(19, 0.03)
        c.stroke(b, C(0xB070FF, 0.8), 0.016, join: .round)
        c.stroke(a, C(0x45C0FF, 0.55), 0.03, join: .round)
        c.stroke(a, C(0xD8F8FF), 0.0115, join: .round)
        c.fill(CGPath(ellipseIn: CGRect(x: -0.1, y: hingeY - 0.0055, width: 1.2, height: 0.011), transform: nil), .white)
    }

    // Bubble: 0.36 body radius in unit space scales up to fill the icon.
    let k: CGFloat = 1.22
    c.with {
        c.translateBy(x: 0.5, y: 0.46)
        c.scaleBy(x: k, y: k)
        c.translateBy(x: -0.5, y: -0.5)
        drawBubble(.basic, c, small: false)
    }
    hinge()
}
