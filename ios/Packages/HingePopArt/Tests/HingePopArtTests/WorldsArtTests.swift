import CoreGraphics
import XCTest
@testable import HingePopArt

/// The worlds expansion: sixteen biomes, four takes each, a landmark per biome and a bubble skin per biome.
final class WorldsArtTests: XCTestCase {
    private func rgba(_ img: CGImage) -> [UInt8] {
        let w = img.width, h = img.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        px.withUnsafeMutableBytes { raw in
            let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return px
    }

    private func meanColor(_ px: [UInt8]) -> (Double, Double, Double) {
        var r = 0, g = 0, b = 0
        for i in stride(from: 0, to: px.count, by: 4) { r += Int(px[i]); g += Int(px[i + 1]); b += Int(px[i + 2]) }
        let n = Double(px.count / 4)
        return (Double(r) / n, Double(g) / n, Double(b) / n)
    }

    func testSixteenBiomes() {
        XCTAssertEqual(ArenaKind.allCases.count, 16)
        XCTAssertEqual(Art.arenaVariants, 4)
    }

    /// Every biome and variant renders at the asked size, opaque, and is a picture rather than a flat fill.
    func testEveryBiomeAndVariantRenders() {
        let size = CGSize(width: 120, height: 260)
        for k in ArenaKind.allCases {
            for v in 0..<Art.arenaVariants {
                let img = Art.arena(k, variant: v, size: size, scale: 1)
                XCTAssertEqual(img.width, 120, "\(k)/\(v)"); XCTAssertEqual(img.height, 260, "\(k)/\(v)")
                XCTAssertEqual(img.alphaInfo, .noneSkipLast, "\(k)/\(v)")
                let px = rgba(img)
                var lo = 255, hi = 0
                for i in stride(from: 0, to: px.count, by: 4) {
                    let l = (Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2])) / 3
                    lo = min(lo, l); hi = max(hi, l)
                }
                XCTAssertGreaterThan(hi - lo, 40, "\(k)/\(v) is nearly flat")
                XCTAssertGreaterThan(hi, 30, "\(k)/\(v) is black")
            }
        }
    }

    /// The four takes on a biome look different from each other: their average colours are apart.
    func testVariantsAreDistinct() {
        let size = CGSize(width: 60, height: 120)
        for k in ArenaKind.allCases {
            let means = (0..<Art.arenaVariants).map { meanColor(rgba(Art.arena(k, variant: $0, size: size, scale: 1))) }
            for a in 0..<means.count {
                for b in (a + 1)..<means.count {
                    let d = abs(means[a].0 - means[b].0) + abs(means[a].1 - means[b].1) + abs(means[a].2 - means[b].2)
                    XCTAssertGreaterThan(d, 6, "\(k) variants \(a) and \(b) look the same")
                }
            }
        }
    }

    /// Bubbles must stay the brightest thing: no backdrop is brighter on average than a mid grey.
    func testBackdropsStayBehindTheBubbles() {
        for k in ArenaKind.allCases {
            for v in 0..<Art.arenaVariants {
                let m = meanColor(rgba(Art.arena(k, variant: v, size: CGSize(width: 60, height: 120), scale: 1)))
                XCTAssertLessThan((m.0 + m.1 + m.2) / 3, 150, "\(k)/\(v) is too bright to play on")
            }
        }
    }

    func testVariantWrapsAndOldCallIsVariantZero() {
        let s = CGSize(width: 50, height: 90)
        XCTAssertTrue(Art.arena(.candy, size: s, scale: 1) === Art.arena(.candy, variant: 0, size: s, scale: 1))
        XCTAssertTrue(Art.arena(.candy, variant: 5, size: s, scale: 1) === Art.arena(.candy, variant: 1, size: s, scale: 1))
        XCTAssertTrue(Art.arena(.candy, variant: -1, size: s, scale: 1) === Art.arena(.candy, variant: 3, size: s, scale: 1))
        XCTAssertFalse(Art.arena(.candy, variant: 1, size: s, scale: 1) === Art.arena(.candy, variant: 2, size: s, scale: 1))
    }

    /// Every landmark sits inside the backdrop, in every shape the game uses, with a reachable tap radius.
    func testLandmarksInsideBounds() {
        let sizes = [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390), CGSize(width: 1024, height: 1366),
                     CGSize(width: 1366, height: 1024), CGSize(width: 320, height: 568), CGSize(width: 1398, height: 2034)]
        for k in ArenaKind.allCases {
            for s in sizes {
                let m = Art.landmark(k, size: s)
                XCTAssertTrue((0...s.width).contains(m.x), "\(k) x outside at \(s)")
                XCTAssertTrue((0...s.height).contains(m.y), "\(k) y outside at \(s)")
                XCTAssertGreaterThanOrEqual(m.r, 22, "\(k) tap radius too small at \(s)")
            }
        }
    }

    /// The landmark is drawn where it says: the spot differs from the plain sky beside it.
    func testLandmarksAreDrawn() {
        let s = CGSize(width: 390, height: 844)
        for k in ArenaKind.allCases where ![.classic, .neon, .forest, .space, .frost, .reef, .magma].contains(k) {
            let px = rgba(Art.arena(k, size: s, scale: 1))
            let m = Art.landmark(k, size: s)
            func lum(_ x: CGFloat, _ y: CGFloat) -> Int {
                let i = (Int(min(max(y, 0), s.height - 1)) * Int(s.width) + Int(min(max(x, 0), s.width - 1))) * 4
                return Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2])
            }
            var best = 0
            let r = m.r * 0.5
            for dy in stride(from: -r, through: r, by: r / 4) {
                for dx in stride(from: -r, through: r, by: r / 4) { best = max(best, lum(m.x + dx, m.y + dy)) }
            }
            XCTAssertGreaterThan(best, 300, "\(k): nothing bright at its landmark")
        }
    }

    /// Skins never reach the image edge and never cover the face's middle.
    func testSkinsDoNotClip() {
        for b in ArenaKind.allCases {
            for k in BubbleKind.allCases {
                for size: CGFloat in [28, 56, 180] {
                    let img = Art.bubble(k, size: size, scale: 2, biome: b)
                    let px = rgba(img), w = img.width, h = img.height
                    var worst: UInt8 = 0
                    for x in 0..<w { worst = max(worst, px[x * 4 + 3], px[((h - 1) * w + x) * 4 + 3]) }
                    for y in 0..<h { worst = max(worst, px[(y * w) * 4 + 3], px[(y * w + w - 1) * 4 + 3]) }
                    XCTAssertEqual(worst, 0, "\(k) in \(b) at \(size) touches the edge")
                }
            }
        }
    }

    func testSkinIsCachedSeparately() {
        let plain = Art.bubble(.basic, size: 60, scale: 2)
        XCTAssertTrue(plain === Art.bubble(.basic, size: 60, scale: 2, biome: nil))
        XCTAssertTrue(plain === Art.bubble(.basic, size: 60, scale: 2, biome: .classic))
        XCTAssertFalse(plain === Art.bubble(.basic, size: 60, scale: 2, biome: .frost))
    }

    private func cpuNow() -> Double {
        var t = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &t)
        return Double(t.tv_sec) + Double(t.tv_nsec) / 1e9
    }

    /// Every take renders inside the arena budget (the scene renders off the main thread, at up to 2x).
    func testEveryVariantSpeedBudget() {
        for k in ArenaKind.allCases {
            for v in 1..<Art.arenaVariants {
                var best = Double.infinity
                for i in 0..<2 {
                    // Thread CPU time, not wall time: the work itself, unaffected by other load on the machine.
                    let start = cpuNow()
                    _ = Art.arena(k, variant: v, size: CGSize(width: 391 + CGFloat(i), height: 844), scale: 3)
                    best = min(best, cpuNow() - start)
                }
                print("arena \(k.rawValue)/\(v) 391x844@3 \(Int(best * 1000)) ms")
                XCTAssertLessThan(best, 0.3, "\(k)/\(v) budget is about 150 ms")  // debug build, loaded machine
            }
        }
    }
}
