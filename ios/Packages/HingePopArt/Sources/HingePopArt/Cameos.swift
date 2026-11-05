import CoreGraphics

/// Guest stars. Each is an original bubble dressed as a film or TV genre, not a likeness of any character.
public enum CameoKind: String, CaseIterable, Sendable {
    case captainFizz, docFlux, sirGlowstick, chosenFizz, merlinFizz, bigBurp, booBubble, discoDot
}

private extension Palette {
    static let hero = Palette(glow: C(0x2CF0C8), edge: C(0x075E58), light: C(0xB5FFE9), base: C(0x20D6B0), deep: C(0x0B8F86), bounce: C(0x8CFFE0))
    static let flux = Palette(glow: C(0xFF8A2C), edge: C(0x7A2C06), light: C(0xFFD9A0), base: C(0xFF9C3C), deep: C(0xD95C12), bounce: C(0xFFC680))
    static let knight = Palette(glow: C(0x7CE8FF), edge: C(0x3C2A18), light: C(0xF5DEB8), base: C(0xE0BC8A), deep: C(0xA67C4E), bounce: C(0xF7E2C0))
    static let shades = Palette(glow: C(0x3CFF8C), edge: C(0x04140C), light: C(0x4A6A5A), base: C(0x1E3028), deep: C(0x0A1812), bounce: C(0x2CFF8C))
    static let wizard = Palette(glow: C(0xB88CFF), edge: C(0x28106E), light: C(0xD8C2FF), base: C(0x8C5CF0), deep: C(0x4C24B0), bounce: C(0xC4A4FF))
    static let kaiju = Palette(glow: C(0x8CFF4C), edge: C(0x16500C), light: C(0xD2FF94), base: C(0x74DC3C), deep: C(0x2F9A20), bounce: C(0xB8FF7C))
    static let disco = Palette(glow: C(0xFF5CE0), edge: C(0x40407C), light: C(0xFFFFFF), base: C(0xC8D4F0), deep: C(0x7C88B8), bounce: C(0xFFC8F4))
}

private let friendlyEye = Eye(dx: 0.42, y: -0.1, rx: 0.26, ry: 0.33, pupilRx: 0.18, pupilRy: 0.24, pupilIn: 0.04, pupilDy: 0.02)

func drawCameo(_ kind: CameoKind, _ c: CGContext, small: Bool) {
    let r = bodyRadius
    switch kind {
    case .captainFizz:
        // A cape streaming behind, a mask across the eyes, a star on the chest.
        let cape = smooth([P(0.28, 0.34), P(0.05, 0.42), P(0.02, 0.68), P(0.17, 0.9), P(0.32, 0.8), P(0.5, 0.92), P(0.66, 0.78)], closed: true)
        c.fill(cape, C(0xFF4B3E))
        c.stroke(cape, C(0x8C160E), 0.016)
        gloss(c, mid, r, .hero, small: small)
        c.fill(polygon([P(0.2, 0.34), P(0.5, 0.39), P(0.8, 0.34), P(0.82, 0.52), P(0.58, 0.56), P(0.5, 0.5), P(0.42, 0.56), P(0.18, 0.52)], round: 0.02), C(0x123C5A))
        drawEyes(c, mid, r, Eye(dx: 0.42, y: -0.14, rx: 0.22, ry: 0.2, pupilRx: 0.12, pupilRy: 0.13, pupilIn: 0.03), small: small)
        mouthGrin(c, mid, r, y: 0.36, w: 0.34, h: 0.2, small: small)
        c.fill(polygon(starPoints(P(0.5, 0.79), 0.07, 0.03, 5, rot: -90)), C(0xFFD21E))

    case .docFlux:
        // Wild white hair and big brass goggles.
        gloss(c, mid, r, .flux, small: small)
        for a in stride(from: CGFloat(-165), through: -15, by: 25) {
            let at = P(0.5 + cos(rad(a)) * 0.3, 0.45 + sin(rad(a)) * 0.3)
            c.fill(circle(P(at.x + cos(rad(a)) * 0.07, at.y + sin(rad(a)) * 0.07), 0.085), C(0xFAFAFF))
        }
        for s in [CGFloat(-1), 1] {
            let o = P(0.5 + s * 0.15, 0.44)
            c.fill(circle(o, 0.125), C(0xC89030))
            c.fill(circle(o, 0.095), C(0xE8FBFF))
            c.fill(circle(P(o.x - s * 0.015, o.y + 0.012), 0.05), C(0x120826))
            c.fill(circle(P(o.x + 0.02, o.y - 0.03), 0.018), .white)
        }
        mouthOpenSmile(c, mid, r, y: 0.46, w: 0.32, h: 0.34, small: small)
        for (x, y) in [(0.14, 0.82), (0.86, 0.82)] as [(CGFloat, CGFloat)] { sparkle(c, P(x, y), 0.06, C(0xFFE28C)) }

    case .sirGlowstick:
        // A hooded traveller with a staff of light.
        c.glow(C(0x7CE8FF), P(0.86, 0.42), 0.2, 0.9)
        c.stroke(polyline([P(0.86, 0.1), P(0.86, 0.72)]), C(0x7CE8FF, 0.55), 0.06)
        c.stroke(polyline([P(0.86, 0.1), P(0.86, 0.72)]), .white, 0.024)
        c.stroke(polyline([P(0.86, 0.7), P(0.86, 0.85)]), C(0x5A4632), 0.034)
        gloss(c, mid, r, .knight, small: small, spec: 0.4)
        let hood = smooth([P(0.14, 0.62), P(0.14, 0.32), P(0.32, 0.13), P(0.5, 0.08), P(0.68, 0.13), P(0.86, 0.32), P(0.86, 0.62), P(0.72, 0.42), P(0.5, 0.34), P(0.28, 0.42)], closed: true)
        c.fill(hood, C(0x6A4C30))
        c.stroke(hood, C(0x34241A), 0.014)
        drawEyes(c, mid, r, Eye(dx: 0.38, y: 0.08, rx: 0.2, ry: 0.23, pupilRx: 0.13, pupilRy: 0.16, pupilIn: 0.02, lid: 0.22, lidColor: Palette.knight.deep), small: small)
        mouthSmirk(c, mid, r, y: 0.5, small: small)

    case .chosenFizz:
        // Dark glasses, dark coat, and streams of green glyphs falling past.
        for (x, top, n) in [(0.1, 0.1, 5), (0.22, 0.02, 3), (0.8, 0.04, 4), (0.92, 0.16, 5)] as [(CGFloat, CGFloat, Int)] {
            for i in 0..<n { c.fill(polygon([P(x - 0.012, top + CGFloat(i) * 0.075), P(x + 0.012, top + CGFloat(i) * 0.075), P(x + 0.012, top + CGFloat(i) * 0.075 + 0.045), P(x - 0.012, top + CGFloat(i) * 0.075 + 0.045)]), C(0x3CFF8C, 1 - CGFloat(i) * 0.16)) }
        }
        gloss(c, mid, r, .shades, small: small, spec: 0.7)
        for s in [CGFloat(-1), 1] {
            let lens = polygon([P(0.5 + s * 0.03, 0.39), P(0.5 + s * 0.3, 0.37), P(0.5 + s * 0.28, 0.5), P(0.5 + s * 0.06, 0.52)], round: 0.03)
            c.fill(lens, C(0x020805))
            c.stroke(polyline([P(0.5 + s * 0.09, 0.42), P(0.5 + s * 0.2, 0.41)]), C(0x3CFF8C, 0.8), 0.012)
        }
        c.stroke(polyline([P(0.47, 0.42), P(0.53, 0.42)]), C(0x020805), 0.018)
        mouthSmirk(c, mid, r, y: 0.42, small: small)

    case .merlinFizz:
        // A starry pointed hat, a long beard and a little wand.
        gloss(c, mid, r, .wizard, small: small)
        drawEyes(c, mid, r, friendlyEye, small: small)
        let beard = smooth([P(0.28, 0.6), P(0.36, 0.76), P(0.5, 0.95), P(0.64, 0.76), P(0.72, 0.6), P(0.5, 0.66)], closed: true)
        c.fill(beard, C(0xF7F7FF))
        c.stroke(beard, C(0xB8B8D8), 0.012)
        let hat = polygon([P(0.2, 0.36), P(0.56, 0.01), P(0.8, 0.36)], round: 0.02)
        c.fill(hat, C(0x3A1C9C))
        c.fill(polygon([P(0.14, 0.34), P(0.86, 0.34), P(0.84, 0.4), P(0.16, 0.4)], round: 0.015), C(0xFFD21E))
        sparkle(c, P(0.52, 0.22), 0.05, C(0xFFD21E))
        c.stroke(polyline([P(0.86, 0.74), P(0.94, 0.56)]), C(0x7A4A24), 0.024)
        sparkle(c, P(0.95, 0.53), 0.06, C(0xFFF5A0))

    case .bigBurp:
        // A small city-stomper: back plates, little arms, enormous roar.
        for (x, y, s) in [(0.2, 0.28, 0.09), (0.34, 0.15, 0.11), (0.52, 0.09, 0.12), (0.7, 0.15, 0.11), (0.84, 0.28, 0.09)] as [(CGFloat, CGFloat, CGFloat)] {
            c.fill(polygon([P(x - s, y + s * 0.9), P(x, y - s), P(x + s, y + s * 0.9)], round: 0.012), C(0x2F9A20))
        }
        c.fill(polygon([P(0.8, 0.72), P(0.99, 0.82), P(0.76, 0.86)], round: 0.02), C(0x2F9A20))
        gloss(c, mid, r, .kaiju, small: small)
        drawEyes(c, mid, r, Eye(dx: 0.42, y: -0.26, rx: 0.22, ry: 0.24, pupilRx: 0.14, pupilRy: 0.17, pupilIn: 0.03, lid: 0.2, slope: 14, lidColor: Palette.kaiju.deep), small: small)
        mouthRoar(c, mid, r, y: 0.28, w: 0.42, h: 0.42, small: small)

    case .booBubble:
        // A friendly sheet with nothing inside it.
        let sheet = smooth([P(0.5, 0.1), P(0.76, 0.2), P(0.84, 0.5), P(0.86, 0.84), P(0.74, 0.74), P(0.62, 0.88), P(0.5, 0.75), P(0.38, 0.88), P(0.26, 0.74), P(0.14, 0.84), P(0.16, 0.5), P(0.24, 0.2)], closed: true)
        c.glow(C(0xC8F4FF), mid, 0.5, 0.7)
        c.fill(sheet, C(0xF4FBFF))
        c.stroke(sheet, C(0x8CC4E0), 0.016)
        for s in [CGFloat(-1), 1] { c.fill(ellipse(P(0.5 + s * 0.13, 0.4), 0.065, 0.095), C(0x18203A)) }
        c.fill(ellipse(P(0.5, 0.58), 0.07, 0.085), C(0x18203A))
        for s in [CGFloat(-1), 1] { c.fill(circle(P(0.5 + s * 0.24, 0.5), 0.04), C(0xFFB0C8, 0.7)) }

    case .discoDot:
        // A mirror ball that has found its groove, with star shades.
        gloss(c, mid, r, .disco, small: small)
        c.with {
            c.clip(circle(mid, r * 0.96))
            let colours = [C(0xFF5CE0), C(0x5CE1FF), C(0xFFE14C), C(0x8CFF8C), C(0xFFFFFF), C(0xB88CFF)]
            var i = 0
            for y in stride(from: CGFloat(0.12), to: 0.9, by: 0.075) {
                for x in stride(from: CGFloat(0.12), to: 0.9, by: 0.075) {
                    c.fill(polygon([P(x, y), P(x + 0.066, y), P(x + 0.066, y + 0.066), P(x, y + 0.066)]), colours[(i * 7 + Int(y * 40)) % colours.count].alpha(0.62))
                    i += 1
                }
            }
        }
        for s in [CGFloat(-1), 1] {
            c.fill(polygon(starPoints(P(0.5 + s * 0.15, 0.44), 0.12, 0.06, 5, rot: -90), round: 0.008), C(0x1A1034))
            c.fill(circle(P(0.5 + s * 0.15, 0.44), 0.05), C(0xFFE14C))
        }
        mouthGrin(c, mid, r, y: 0.42, w: 0.3, h: 0.2, small: small)
        for (x, y) in [(0.08, 0.2), (0.92, 0.24), (0.12, 0.84), (0.9, 0.8)] as [(CGFloat, CGFloat)] { sparkle(c, P(x, y), 0.05, .white) }
    }
}
