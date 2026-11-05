import CoreGraphics
import Foundation

// All drawing in this package uses a y-down space: origin at the top left of the
// returned image, so (0,0) is the first row of the CGImage. Sprites draw in a unit
// square (0...1), arenas in points. `makeImage` sets that transform up once.

let sRGB: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

@inline(__always) func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
@inline(__always) func rad(_ d: CGFloat) -> CGFloat { d * .pi / 180 }

/// A plain sRGB colour. Written as hex in the art files so palettes read like a style sheet.
struct C {
    var r, g, b, a: CGFloat
    init(_ hex: UInt32, _ a: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 255) / 255
        g = CGFloat((hex >> 8) & 255) / 255
        b = CGFloat(hex & 255) / 255
        self.a = a
    }
    init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) { self.r = r; self.g = g; self.b = b; self.a = a }
    func alpha(_ v: CGFloat) -> C { C(r: r, g: g, b: b, a: v) }
    func mix(_ o: C, _ t: CGFloat) -> C {
        C(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t, a: a + (o.a - a) * t)
    }
    var cg: CGColor { CGColor(colorSpace: sRGB, components: [r, g, b, a])! }
    static let white = C(0xFFFFFF)
    static let ink = C(0x140A2E)      // the near-black violet every outline uses
}

func grad(_ stops: [(CGFloat, C)]) -> CGGradient {
    var comps = [CGFloat](); comps.reserveCapacity(stops.count * 4)
    var locs = [CGFloat](); locs.reserveCapacity(stops.count)
    for (t, c) in stops { comps += [c.r, c.g, c.b, c.a]; locs.append(t) }
    return CGGradient(colorSpace: sRGB, colorComponents: comps, locations: locs, count: stops.count)!
}

/// A soft blob: full colour in the middle and fully clear at the edge, shaped to feel
/// like a gaussian. This is the package's stand-in for blur.
func softGrad(_ c: C, _ peak: CGFloat = 1) -> CGGradient {
    grad([(0, c.alpha(peak)), (0.25, c.alpha(peak * 0.72)), (0.55, c.alpha(peak * 0.28)), (0.8, c.alpha(peak * 0.07)), (1, c.alpha(0))])
}

extension CGContext {
    func with(_ body: () -> Void) { saveGState(); body(); restoreGState() }

    func fill(_ p: CGPath, _ c: C) { setFillColor(c.cg); addPath(p); fillPath() }

    func stroke(_ p: CGPath, _ c: C, _ w: CGFloat, cap: CGLineCap = .round, join: CGLineJoin = .round) {
        setStrokeColor(c.cg); setLineWidth(w); setLineCap(cap); setLineJoin(join); addPath(p); strokePath()
    }

    func clip(_ p: CGPath) { addPath(p); clip() }

    func linear(_ g: CGGradient, _ a: CGPoint, _ b: CGPoint) {
        drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    func radial(_ g: CGGradient, _ c: CGPoint, _ r: CGFloat, from: CGPoint? = nil, r0: CGFloat = 0, extend: Bool = false) {
        drawRadialGradient(g, startCenter: from ?? c, startRadius: r0, endCenter: c, endRadius: r,
                           options: extend ? [.drawsBeforeStartLocation, .drawsAfterEndLocation] : [])
    }

    func fillLinear(_ p: CGPath, _ g: CGGradient, _ a: CGPoint, _ b: CGPoint) {
        with { clip(p); linear(g, a, b) }
    }

    func fillRadial(_ p: CGPath, _ g: CGGradient, _ c: CGPoint, _ r: CGFloat, from: CGPoint? = nil) {
        with { clip(p); radial(g, c, r, from: from, extend: true) }
    }

    /// Radial gradient squashed into a rotated ellipse. Used for every soft highlight.
    func blob(_ g: CGGradient, _ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, rot: CGFloat = 0) {
        with {
            translateBy(x: c.x, y: c.y); rotate(by: rad(rot)); scaleBy(x: rx, y: ry)
            drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
        }
    }

    func glow(_ c: C, _ at: CGPoint, _ r: CGFloat, _ peak: CGFloat = 1) { radial(softGrad(c, peak), at, r) }

    /// Fills a stroked outline with a gradient, for rims that brighten on one side.
    func strokeLinear(_ p: CGPath, _ w: CGFloat, _ g: CGGradient, _ a: CGPoint, _ b: CGPoint,
                      cap: CGLineCap = .round, join: CGLineJoin = .round) {
        fillLinear(p.copy(strokingWithWidth: w, lineCap: cap, lineJoin: join, miterLimit: 10), g, a, b)
    }
}

// MARK: - Paths

func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil)
}

func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, rot: CGFloat = 0) -> CGPath {
    var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: rad(rot))
    return CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: &t)
}

func polygon(_ pts: [CGPoint], round r: CGFloat = 0) -> CGPath {
    let p = CGMutablePath()
    guard pts.count > 2 else { return p }
    if r <= 0 {
        p.addLines(between: pts); p.closeSubpath(); return p
    }
    let n = pts.count
    let a = pts[n - 1], b = pts[0]
    p.move(to: P((a.x + b.x) / 2, (a.y + b.y) / 2))
    for i in 0..<n { p.addArc(tangent1End: pts[i], tangent2End: pts[(i + 1) % n], radius: r) }
    p.closeSubpath()
    return p
}

func polyline(_ pts: [CGPoint]) -> CGPath {
    let p = CGMutablePath(); p.addLines(between: pts); return p
}

/// Star points, first point straight up unless rotated (degrees).
func starPoints(_ c: CGPoint, _ outer: CGFloat, _ inner: CGFloat, _ n: Int, rot: CGFloat = 0) -> [CGPoint] {
    (0..<(n * 2)).map { i in
        let a = rad(rot - 90) + CGFloat(i) * .pi / CGFloat(n)
        let r = i % 2 == 0 ? outer : inner
        return P(c.x + cos(a) * r, c.y + sin(a) * r)
    }
}

func quad(_ a: CGPoint, _ ctrl: CGPoint, _ b: CGPoint) -> CGPath {
    let p = CGMutablePath(); p.move(to: a); p.addQuadCurve(to: b, control: ctrl); return p
}

/// Catmull-Rom through the points. Hills and mountain haze are built from this.
func smooth(_ pts: [CGPoint], closed: Bool = false) -> CGMutablePath {
    let p = CGMutablePath()
    guard pts.count > 1 else { return p }
    let n = pts.count
    func at(_ i: Int) -> CGPoint {
        closed ? pts[(i % n + n) % n] : pts[min(max(i, 0), n - 1)]
    }
    p.move(to: pts[0])
    for i in 0..<(closed ? n : n - 1) {
        let p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2)
        p.addCurve(to: p2,
                   control1: P(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6),
                   control2: P(p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6))
    }
    if closed { p.closeSubpath() }
    return p
}

/// A tapered petal from `a` to `b`, widest at `at` of the way along. Streaks, marks and spikes.
func taper(_ a: CGPoint, _ b: CGPoint, width w: CGFloat, at t: CGFloat = 0.3) -> CGPath {
    let dx = b.x - a.x, dy = b.y - a.y, len = max(hypot(dx, dy), 0.0001)
    let nx = -dy / len * w / 2, ny = dx / len * w / 2
    let m = P(a.x + dx * t, a.y + dy * t)
    let p = CGMutablePath()
    p.move(to: a)
    p.addQuadCurve(to: b, control: P(m.x + nx * 2, m.y + ny * 2))
    p.addQuadCurve(to: a, control: P(m.x - nx * 2, m.y - ny * 2))
    p.closeSubpath()
    return p
}

// MARK: - Bitmaps

/// Deterministic random numbers, so the same arena always comes out the same.
struct Dice {
    var s: UInt64
    init(_ seed: UInt64) { s = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(1 << 53) }
    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * unit() }
}

/// Makes a bitmap, flips it y-down and scales it, then hands it to `draw`.
/// A normal CGImage's first row is its top, so y-down here means upright everywhere.
func makeImage(pxW: Int, pxH: Int, opaque: Bool, unitsX: CGFloat, unitsY: CGFloat,
               _ draw: (CGContext) -> Void) -> CGImage {
    let w = max(pxW, 1), h = max(pxH, 1)
    let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: sRGB, bitmapInfo: info) else {
        fatalError("HingePopArt: cannot make a \(w)x\(h) bitmap")
    }
    ctx.interpolationQuality = .medium
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: CGFloat(w) / unitsX, y: -CGFloat(h) / unitsY)
    draw(ctx)
    guard let img = ctx.makeImage() else { fatalError("HingePopArt: cannot read back bitmap") }
    return img
}

func unitSprite(pixels: Int, _ draw: (CGContext) -> Void) -> CGImage {
    makeImage(pxW: pixels, pxH: pixels, opaque: false, unitsX: 1, unitsY: 1, draw)
}
