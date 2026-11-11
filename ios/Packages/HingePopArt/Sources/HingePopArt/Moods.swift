import CoreGraphics
import Foundation

// MARK: - Landmarks

/// Where each biome hides its secret: centre and tap radius, in points, y down. `Secrets.spot` in the core
/// mirrors these formulas exactly; change both together. The painters draw each landmark here.
func landmarkSpot(_ k: ArenaKind, _ s: CGSize) -> (x: CGFloat, y: CGFloat, r: CGFloat) {
    let w = s.width, h = s.height, u = min(w, h)
    switch k {
    case .classic: return (w * 0.14, min(h * 0.92, h - u * 0.1), u * 0.13)
    case .neon: return (w * 0.5, h - max(u * 0.30, h * 0.20), u * 0.22)
    case .forest: return (w * 0.93, h - max(u * 0.26, h * 0.16) - u * 0.12, u * 0.16)
    case .space: return (w * 0.80, h * 0.87, u * 0.17)
    case .frost: return (w * 0.85, h - max(u * 0.26, h * 0.16) - u * 0.15, u * 0.15)
    case .reef: return (w * 0.08, h - max(u * 0.2, h * 0.12) - u * 0.1, u * 0.16)
    case .magma: return (w * 0.97, h - max(u * 0.3, h * 0.2) - u * 0.38, u * 0.14)
    case .candy: return (w * 0.15, h - max(u * 0.24, h * 0.15) - u * 0.30, u * 0.15)
    case .dunes: return (w * 0.82, h - max(u * 0.16, h * 0.1), u * 0.13)
    case .storm: return (w * 0.76, h * 0.12 + u * 0.06, u * 0.15)
    case .crystal: return (w * 0.84, h - max(u * 0.34, h * 0.22), u * 0.15)
    case .haunted: return (w * 0.78, h - max(u * 0.38, h * 0.26), u * 0.12)
    case .circuit: return (w * 0.18, h - max(u * 0.44, h * 0.3), u * 0.13)
    case .jungle: return (w * 0.5, h - max(u * 0.12, h * 0.08), u * 0.13)
    case .clouds: return (w * 0.83, h * 0.12 + u * 0.04, u * 0.14)
    case .clockwork: return (w * 0.5, h * 0.14 + u * 0.06, u * 0.17)
    }
}

// MARK: - Relighting the original seven

/// A new time of day for one of the original arenas, laid over its finished painting: a colour wash that
/// keeps the painting's light and shade, a gradient that darkens or warms, a glow, and its own props.
struct Relight {
    var wash: C? = nil            // recolour (keeps luminosity)
    var washA: CGFloat = 0
    var top: C = C(0xFFFFFF, 0)   // darkening veil, top of screen
    var bottom: C = C(0xFFFFFF, 0)
    var glow: (at: CGPoint, r: CGFloat, col: C, a: CGFloat)? = nil   // in fractions of w, h and u
    var props: ((CGContext, CGSize) -> Void)? = nil

    func apply(_ c: CGContext, _ s: CGSize) {
        let u = min(s.width, s.height)
        let all = CGRect(origin: .zero, size: s)
        if let wash, washA > 0 {
            c.with { c.setBlendMode(.color); c.setFillColor(wash.alpha(washA).cg); c.fill(all) }
        }
        if top.a > 0 || bottom.a > 0 {
            // A plain alpha gradient, not a multiply: it reads the same on these dark scenes and costs far less.
            c.linear(grad([(0, top), (1, bottom)]), P(0, 0), P(0, s.height))
        }
        if let g = glow {
            c.with { c.setBlendMode(.screen); c.glow(g.col, P(s.width * g.at.x, s.height * g.at.y), u * g.r, g.a) }
        }
        props?(c, s)
    }
}

func relight(_ k: ArenaKind, _ v: Int) -> Relight? {
    switch (k, v) {
    // Classic: dawn, teal deep, meteor shower.
    case (.classic, 1): return Relight(wash: C(0xD04A8A), washA: 0.35, glow: (P(0.5, 1.0), 0.9, C(0xFF7A6A), 0.4))
    case (.classic, 2): return Relight(wash: C(0x1AA0A0), washA: 0.45, bottom: C(0x0A2030, 0.4))
    case (.classic, 3): return Relight(top: C(0x2A1A60, 0.3), props: { c, s in
        let u = min(s.width, s.height); var d = Dice(301)
        for _ in 0..<7 {
            let x = d.range(0, s.width), y = d.range(0, s.height * 0.6), l = u * d.range(0.12, 0.25)
            c.fillLinear(taper(P(x, y), P(x - l * 0.8, y - l * 0.6), width: u * 0.006, at: 0.05), grad([(0, C(0xFFFFFF, 0.9)), (1, C(0xA0C8FF, 0))]), P(x, y), P(x - l * 0.8, y - l * 0.6))
            c.glow(C(0xC8E0FF), P(x, y), u * 0.015, 0.8)
        }
    })
    // Neon: sunrise, rain, ice.
    case (.neon, 1): return Relight(wash: C(0xFF7A30), washA: 0.4, glow: (P(0.5, 0.75), 0.8, C(0xFFA040), 0.35))
    case (.neon, 2): return Relight(wash: C(0x3A50C8), washA: 0.35, top: C(0x101030, 0.35), props: { c, s in
        let u = min(s.width, s.height)
        streaks(c, s, seed: 311, C(0xC8D0FF, 0.22), count: max(120, Int(s.width * s.height / 2500)), len: u * 0.07, angle: 8, width: max(0.7, u * 0.0022))
    })
    case (.neon, 3): return Relight(wash: C(0x30D8F0), washA: 0.5, bottom: C(0x0A2040, 0.3))
    // Forest: golden hour, moonlit moor, misty rain.
    case (.forest, 1): return Relight(wash: C(0xFF9A40), washA: 0.32, glow: (P(0.3, 0.55), 0.9, C(0xFFB060), 0.4))
    case (.forest, 2): return Relight(wash: C(0x3A5AC8), washA: 0.5, top: C(0x101838, 0.35), bottom: C(0x080C20, 0.35), props: { c, s in
        motes(c, s, seed: 321, C(0xC8FF8A), count: 30, in: CGRect(x: 0, y: s.height * 0.4, width: s.width, height: s.height * 0.6), size: 1...2.2, glow: 0.4)
    })
    case (.forest, 3): return Relight(wash: C(0x5A8A9A), washA: 0.45, props: { c, s in
        let u = min(s.width, s.height)
        hazeBand(c, s, y: s.height * 0.72, h: u * 0.12, C(0xB8D0E0), 0.35)
        streaks(c, s, seed: 322, C(0xD0E0F0, 0.2), count: max(100, Int(s.width * s.height / 3000)), len: u * 0.06, angle: 12, width: max(0.7, u * 0.002))
    })
    // Space: marshmallow pink, teal nebula, red giant.
    case (.space, 1): return Relight(wash: C(0xFF7AC0), washA: 0.4, glow: (P(0.2, 0.3), 0.8, C(0xFFB0D8), 0.25))
    case (.space, 2): return Relight(wash: C(0x20C0B0), washA: 0.45)
    case (.space, 3): return Relight(wash: C(0xE04A2A), washA: 0.45, glow: (P(0.5, 0.0), 1.0, C(0xFF6A3A), 0.4))
    // Frost: mirror-lake twilight, blizzard, golden dawn.
    case (.frost, 1): return Relight(wash: C(0xC070E0), washA: 0.35, glow: (P(0.5, 0.85), 0.9, C(0xFFA0D0), 0.3))
    case (.frost, 2): return Relight(wash: C(0x8AA0C0), washA: 0.4, props: { c, s in
        let u = min(s.width, s.height)
        streaks(c, s, seed: 331, C(0xFFFFFF, 0.35), count: max(150, Int(s.width * s.height / 2000)), len: u * 0.025, angle: 65, width: max(1, u * 0.004))
        hazeBand(c, s, y: s.height * 0.8, h: u * 0.15, C(0xE0F0FF), 0.3)
    })
    case (.frost, 3): return Relight(wash: C(0xFFB050), washA: 0.3, glow: (P(0.7, 0.75), 0.9, C(0xFFD080), 0.45))
    // Reef: bright lagoon, waterfall vault, bioluminescent night.
    case (.reef, 1): return Relight(wash: C(0x30E0C0), washA: 0.3, glow: (P(0.5, 0.0), 1.0, C(0xC0FFF0), 0.35))
    case (.reef, 2): return Relight(wash: C(0x2A60C8), washA: 0.45, top: C(0x0A1830, 0.25), props: { c, s in
        let u = min(s.width, s.height)
        for x in [0.04, 0.96] as [CGFloat] {
            c.blob(softGrad(C(0xE0FFFF), 0.3), P(s.width * x, s.height * 0.4), u * 0.07, s.height * 0.7)
        }
    })
    case (.reef, 3): return Relight(wash: C(0x1A2A80), washA: 0.55, top: C(0x050A20, 0.45), bottom: C(0x050A20, 0.3), props: { c, s in
        let u = min(s.width, s.height)
        motes(c, s, seed: 341, C(0x5AFFE0), count: 40, in: CGRect(origin: .zero, size: s), size: u * 0.002...u * 0.005, glow: 0.5)
    })
    // Magma: golden hoard, ash storm, blue fire.
    case (.magma, 1): return Relight(wash: C(0xFFC030), washA: 0.4, glow: (P(0.5, 0.8), 0.9, C(0xFFD060), 0.35))
    case (.magma, 2): return Relight(wash: C(0x8A5A50), washA: 0.4, props: { c, s in
        let u = min(s.width, s.height)
        streaks(c, s, seed: 351, C(0x2A1A1A, 0.3), count: max(100, Int(s.width * s.height / 3000)), len: u * 0.04, angle: 70, width: max(1, u * 0.004))
    })
    case (.magma, 3): return Relight(wash: C(0x3A8AFF), washA: 0.55)
    default: return nil
    }
}
