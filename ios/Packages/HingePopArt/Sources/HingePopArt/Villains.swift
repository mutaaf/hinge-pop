import CoreGraphics

/// Villain bubbles: bad bubbles you must leave alone. Each is an original genre nod (a fairy-tale witch, a
/// haunted-house ghost, a monster-movie giant, a treasure-chest mimic, a machine tyrant, a cosmic maw), never a
/// likeness of any character. Every one wears a spiked warning rim whose colour and spike count say how bad a
/// touch is: amber with 8 short spikes (Menace), orange with 10 (Brute), crimson with 12 long ones (Doom). The rim
/// is part of the sprite, so the tell survives Reduce Motion. Raw values match the core's `VillainKind`.
public enum VillainSprite: String, CaseIterable, Sendable {
    case hex, phantom, kaiju, mimic, overlord, void

    /// 1 Menace, 2 Brute, 3 Doom.
    public var tier: Int {
        switch self {
        case .hex, .phantom: 1
        case .kaiju, .mimic: 2
        case .overlord, .void: 3
        }
    }
    /// The tier's warning colour, for rings, flashes and labels drawn outside the sprite (sRGB 0...1).
    public var warning: (r: CGFloat, g: CGFloat, b: CGFloat) {
        let c = warningColor(tier)
        return (c.r, c.g, c.b)
    }
}

func warningColor(_ tier: Int) -> C {
    switch tier {
    case 1: C(0xFFC21F)
    case 2: C(0xFF6A1F)
    default: C(0xFF1F45)
    }
}

private extension Palette {
    static let hex = Palette(glow: C(0x6CFF3C), edge: C(0x1A0A2E), light: C(0xC8FF7C), base: C(0x5CD630), deep: C(0x1F7A26), bounce: C(0xB04CFF), rim: C(0xD8FF9C))
    static let kaiju = Palette(glow: C(0xFF6A1F), edge: C(0x0E1410), light: C(0x6A8A64), base: C(0x3C5A3A), deep: C(0x1A2C1C), bounce: C(0xFF8A3C), rim: C(0xFFB07C))
    static let mimic = Palette(glow: C(0xFFB300), edge: C(0xA0480A), light: C(0xFFF2A0), base: C(0xFFCC1E), deep: C(0xE88A00), bounce: C(0xFFE08A))
    static let overlord = Palette(glow: C(0xFF1F45), edge: C(0x06080E), light: C(0x9AA6B8), base: C(0x4A5468), deep: C(0x1A2030), bounce: C(0xFF3C5A), rim: C(0xC8D4E8))
    static let void = Palette(glow: C(0x8C3CFF), edge: C(0x05010C), light: C(0x4A2C7C), base: C(0x1C0C36), deep: C(0x08031A), bounce: C(0xFF2E9A), rim: C(0xB88CFF))
}

/// The warning crown: spikes around the body, in the tier's colour, with a dark keyline so it reads on any world.
func drawWarningRim(_ c: CGContext, tier: Int, small: Bool, reach: CGFloat = 0.475) {
    let n = tier == 1 ? 8 : tier == 2 ? 10 : 12
    let inner = bodyRadius * 0.96
    let outer = tier == 3 ? reach : tier == 2 ? reach - 0.02 : reach - 0.04
    let col = warningColor(tier)
    c.glow(col, mid, 0.5, tier == 3 ? 0.75 : 0.55)
    let pts = starPoints(mid, outer, inner, n, rot: -90)
    let spikes = polygon(pts, round: 0.006)
    c.stroke(spikes, C(0x12020A), small ? 0.03 : 0.022)
    c.fillRadial(spikes, grad([(0.7, col.mix(C(0x12020A), 0.35)), (0.9, col), (1, col.mix(.white, 0.35))]), mid, outer)
}

func drawVillain(_ kind: VillainSprite, _ c: CGContext, small: Bool) {
    let r = bodyRadius
    switch kind {
    case .hex:
        drawWarningRim(c, tier: 1, small: small)
        gloss(c, mid, r, .hex, small: small, halo: 0, spec: 0.7)
        // Bubbling brew dripping off the bottom.
        for (x, len) in [(0.36, 0.08), (0.5, 0.12), (0.62, 0.07)] as [(CGFloat, CGFloat)] {
            let drip = smooth([P(x - 0.025, 0.8), P(x - 0.02, 0.8 + len), P(x, 0.83 + len), P(x + 0.02, 0.8 + len), P(x + 0.025, 0.8)], closed: true)
            c.fill(drip, C(0x8CFF3C))
            c.stroke(drip, C(0x1A0A2E), 0.01)
        }
        // Angry glowing eyes.
        var eye = Eye(dx: 0.4, y: -0.02, rx: 0.24, ry: 0.2, pupilRx: 0.08, pupilRy: 0.16, pupilIn: 0.04, lid: 0.32, slope: 26, lidColor: C(0x1F7A26))
        eye.sclera = C(0xFFF04C); eye.scleraLow = C(0xFFB31F); eye.pupil = C(0x1A0A2E)
        drawEyes(c, mid, r, eye, small: small)
        // A crooked grin with one tooth.
        let grin = CGMutablePath()
        grin.move(to: P(0.33, 0.6)); grin.addQuadCurve(to: P(0.68, 0.58), control: P(0.5, 0.74)); grin.addQuadCurve(to: P(0.33, 0.6), control: P(0.5, 0.67))
        c.fill(grin, C(0x1A0A2E))
        c.fill(polygon([P(0.53, 0.62), P(0.58, 0.62), P(0.555, 0.67)]), .white)
        // The crooked hat, its tip bent over.
        let hat = smooth([P(0.16, 0.3), P(0.4, 0.22), P(0.47, 0.02), P(0.6, -0.0), P(0.72, 0.06), P(0.6, 0.08), P(0.58, 0.22), P(0.84, 0.3)], closed: true)
        c.fill(hat, C(0x1A0A2E))
        c.fill(polygon([P(0.34, 0.24), P(0.62, 0.21), P(0.63, 0.26), P(0.35, 0.29)], round: 0.01), C(0xB04CFF))
        c.fill(polygon([P(0.06, 0.31), P(0.94, 0.31), P(0.88, 0.36), P(0.12, 0.36)], round: 0.02), C(0x1A0A2E))

    case .phantom:
        drawWarningRim(c, tier: 1, small: small)
        // A ragged sheet with hollow, angry eyes and a cold aura.
        c.glow(C(0x7CE8FF), mid, 0.46, 0.8)
        let sheet = smooth([P(0.5, 0.12), P(0.78, 0.22), P(0.84, 0.5), P(0.88, 0.86), P(0.74, 0.72), P(0.66, 0.9), P(0.56, 0.74), P(0.46, 0.92), P(0.36, 0.74), P(0.24, 0.88), P(0.14, 0.86), P(0.16, 0.5), P(0.22, 0.22)], closed: true)
        c.fillLinear(sheet, grad([(0, C(0xEAF8FF)), (1, C(0x9CC8E8))]), P(0.5, 0.12), P(0.5, 0.9))
        c.stroke(sheet, C(0x1C2C5A), 0.02)
        for s in [CGFloat(-1), 1] {
            let eye = polygon([P(0.5 + s * 0.05, 0.38), P(0.5 + s * 0.22, 0.31), P(0.5 + s * 0.2, 0.47), P(0.5 + s * 0.06, 0.46)], round: 0.02)
            c.fill(eye, C(0x0A1030))
            c.fill(circle(P(0.5 + s * 0.13, 0.41), 0.03), C(0x3CF0FF))
        }
        let maw = polygon([P(0.38, 0.6), P(0.45, 0.56), P(0.5, 0.62), P(0.55, 0.56), P(0.62, 0.6), P(0.56, 0.7), P(0.44, 0.7)], round: 0.015)
        c.fill(maw, C(0x0A1030))

    case .kaiju:
        drawWarningRim(c, tier: 2, small: small)
        // Dorsal plates first, then the scaly body, molten eyes and a roar.
        for (x, y, s) in [(0.24, 0.24, 0.08), (0.36, 0.14, 0.1), (0.5, 0.1, 0.11), (0.64, 0.14, 0.1), (0.76, 0.24, 0.08)] as [(CGFloat, CGFloat, CGFloat)] {
            let plate = polygon([P(x - s * 0.8, y + s), P(x, y - s * 1.1), P(x + s * 0.8, y + s)], round: 0.01)
            c.fill(plate, C(0x0E1410))
            c.fill(polygon([P(x - s * 0.35, y + s * 0.6), P(x, y - s * 0.5), P(x + s * 0.35, y + s * 0.6)]), C(0xFF6A1F, 0.85))
        }
        gloss(c, mid, r, .kaiju, small: small, halo: 0, spec: 0.5)
        if !small {
            c.with {
                c.clip(circle(mid, r * 0.95))
                for y in stride(from: CGFloat(0.22), to: 0.86, by: 0.09) {
                    for x in stride(from: CGFloat(0.18) + (Int(y * 100) % 2 == 0 ? 0 : 0.045), to: 0.86, by: 0.09) {
                        c.stroke(quad(P(x - 0.03, y), P(x, y + 0.03), P(x + 0.03, y)), C(0x0E1410, 0.45), 0.008)
                    }
                }
            }
        }
        for s in [CGFloat(-1), 1] {
            let slit = polygon([P(0.5 + s * 0.07, 0.4), P(0.5 + s * 0.27, 0.33), P(0.5 + s * 0.24, 0.45), P(0.5 + s * 0.08, 0.46)], round: 0.015)
            c.fill(slit, C(0x0E1410))
            c.fill(ellipse(P(0.5 + s * 0.17, 0.41), 0.06, 0.035), C(0xFF8A1F))
            c.fill(ellipse(P(0.5 + s * 0.17, 0.41), 0.012, 0.03), C(0x0E1410))
        }
        let mouth = polygon([P(0.3, 0.56), P(0.7, 0.56), P(0.64, 0.74), P(0.36, 0.74)], round: 0.03)
        c.fill(mouth, C(0x2A0606))
        c.with {
            c.clip(mouth)
            c.glow(C(0xFF6A1F), P(0.5, 0.74), 0.16, 0.9)
            for i in 0..<5 {
                let x = 0.34 + CGFloat(i) * 0.08
                c.fill(polygon([P(x, 0.55), P(x + 0.06, 0.55), P(x + 0.03, 0.61)]), C(0xF4F0E0))
            }
        }

    case .mimic:
        // It passes for a golden bubble. The tell: a seam of tiny teeth across its middle and a sly, narrow look.
        drawWarningRim(c, tier: 2, small: small, reach: 0.44)
        drawGoldenRays(c, r, small: small)
        gloss(c, mid, r, .mimic, small: small, halo: 0.5)
        var eye = Eye(dx: 0.4, y: -0.22, rx: 0.24, ry: 0.2, pupilRx: 0.1, pupilRy: 0.14, pupilIn: -0.05, lid: 0.45, slope: 18, lidColor: C(0xE88A00))
        eye.outlineColor = C(0x4A2200); eye.pupil = C(0x2A1000)
        drawEyes(c, mid, r, eye, small: small)
        let seam = CGMutablePath()
        seam.move(to: P(0.18, 0.56)); seam.addQuadCurve(to: P(0.82, 0.56), control: P(0.5, 0.66))
        c.stroke(seam, C(0x4A1400), small ? 0.03 : 0.022)
        let n = small ? 6 : 9
        for i in 0..<n {
            let t = (CGFloat(i) + 0.5) / CGFloat(n)
            let x = 0.2 + t * 0.6, y = 0.56 + 4 * t * (1 - t) * 0.05
            c.fill(polygon([P(x - 0.022, y - 0.004), P(x + 0.022, y - 0.004), P(x, y + 0.04)]), .white)
            c.fill(polygon([P(x - 0.018, y + 0.004), P(x + 0.018, y + 0.004), P(x, y - 0.032)]), C(0xFFF8E0))
        }
        c.fill(ellipse(P(0.76, 0.62), 0.04, 0.03, rot: 30), C(0xFF2E63))

    case .overlord:
        drawWarningRim(c, tier: 3, small: small)
        // Antenna spikes, armour plates, rivets, and one great red eye.
        for a in [CGFloat(-130), -90, -50] {
            let base = P(0.5 + cos(rad(a)) * 0.3, 0.5 + sin(rad(a)) * 0.3)
            let tip = P(0.5 + cos(rad(a)) * 0.47, 0.5 + sin(rad(a)) * 0.47)
            c.stroke(polyline([base, tip]), C(0x06080E), 0.03)
            c.fill(circle(tip, 0.022), C(0xFF1F45))
        }
        gloss(c, mid, r, .overlord, small: small, halo: 0, spec: 0.6)
        c.with {
            c.clip(circle(mid, r * 0.95))
            c.stroke(polyline([P(0.1, 0.3), P(0.9, 0.3)]), C(0x06080E, 0.7), 0.014)
            c.stroke(polyline([P(0.1, 0.7), P(0.9, 0.7)]), C(0x06080E, 0.7), 0.014)
            if !small { for x in stride(from: CGFloat(0.22), through: 0.78, by: 0.14) { c.fill(circle(P(x, 0.74), 0.012), C(0xC8D4E8)) } }
        }
        c.fill(ellipse(P(0.5, 0.48), 0.27, 0.15), C(0x06080E))
        c.glow(C(0xFF1F45), P(0.5, 0.48), 0.22, 0.9)
        c.fillRadial(circle(P(0.5, 0.48), 0.11), grad([(0, .white), (0.25, C(0xFF8C9C)), (0.6, C(0xFF1F45)), (1, C(0x7A0010))]), P(0.5, 0.48), 0.11)
        c.fill(circle(P(0.5, 0.48), 0.035), C(0x2A0006))
        c.fill(circle(P(0.47, 0.45), 0.015), .white)
        // A visor grille for a mouth.
        for i in 0..<5 { c.fill(polygon([P(0.36 + CGFloat(i) * 0.06, 0.61), P(0.4 + CGFloat(i) * 0.06, 0.61), P(0.4 + CGFloat(i) * 0.06, 0.66), P(0.36 + CGFloat(i) * 0.06, 0.66)]), C(0x06080E)) }

    case .void:
        drawWarningRim(c, tier: 3, small: small)
        // A swirl of violet around a black maw ringed with teeth, stars falling in.
        gloss(c, mid, r, .void, small: small, halo: 0, spec: 0.35)
        c.with {
            c.clip(circle(mid, r * 0.95))
            for i in 0..<3 {
                let rr = r * (0.85 - CGFloat(i) * 0.18)
                c.stroke(ellipse(mid, rr, rr * 0.82, rot: CGFloat(i) * 35), C(0xB88CFF, 0.5 - CGFloat(i) * 0.12), 0.014)
            }
        }
        let maw = circle(mid, r * 0.5)
        c.fill(maw, C(0x000000))
        c.with {
            c.clip(maw)
            for (x, y, s) in [(0.46, 0.45, 0.012), (0.55, 0.52, 0.009), (0.5, 0.56, 0.007), (0.43, 0.54, 0.008)] as [(CGFloat, CGFloat, CGFloat)] { c.fill(circle(P(x, y), s), C.white.alpha(0.85)) }
        }
        let teeth = small ? 8 : 12
        for i in 0..<teeth {
            let a = CGFloat(i) / CGFloat(teeth) * 2 * .pi
            let o = r * 0.5
            let base1 = P(0.5 + cos(a - 0.18) * o, 0.5 + sin(a - 0.18) * o), base2 = P(0.5 + cos(a + 0.18) * o, 0.5 + sin(a + 0.18) * o)
            let tip = P(0.5 + cos(a) * o * 0.72, 0.5 + sin(a) * o * 0.72)
            c.fill(polygon([base1, base2, tip]), C(0xF0E8FF))
        }
        c.stroke(maw, C(0xFF2E9A, 0.9), 0.012)
        // Two small, watchful eyes above the maw.
        for s in [CGFloat(-1), 1] {
            c.fill(ellipse(P(0.5 + s * 0.13, 0.25), 0.04, 0.025, rot: s * 20), C(0xFF2E9A))
        }
    }
}
