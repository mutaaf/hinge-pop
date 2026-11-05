import CoreGraphics
import XCTest
@testable import HingePopArt

final class ArtTests: XCTestCase {
    private func alphaBytes(_ img: CGImage) -> (bytes: [UInt8], w: Int, h: Int) {
        let w = img.width, h = img.height
        var data = [UInt8](repeating: 0, count: w * h)
        data.withUnsafeMutableBytes { raw in
            let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return (data, w, h)
    }

    func testEveryBubbleRendersAtRightSize() {
        for k in BubbleKind.allCases {
            let i = Art.bubble(k, size: 64, scale: 3)
            XCTAssertEqual(i.width, 192, k.rawValue); XCTAssertEqual(i.height, 192, k.rawValue)
            XCTAssertGreaterThan(Art.bodyFraction(k), 0.5, k.rawValue)
            XCTAssertLessThan(Art.bodyFraction(k), 0.9, k.rawValue)
        }
    }

    func testEverythingElseRenders() {
        for k in PowerKind.allCases { XCTAssertEqual(Art.power(k, size: 40, scale: 2).width, 80, k.rawValue) }
        for k in UIGlyph.allCases { XCTAssertEqual(Art.glyph(k, size: 44, scale: 3).height, 132, k.rawValue) }
        var fx: [FXKind] = [.popBurst, .shockwave, .particleStar]
        fx += (0..<Art.confettiVariants).map { .confetti($0) }
        for k in fx {
            let i = Art.fx(k, size: 32, scale: 2)
            XCTAssertEqual(i.width, 64); XCTAssertEqual(i.height, 64)
            XCTAssertGreaterThan(alphaBytes(i).bytes.reduce(0) { $0 + Int($1) }, 0, "\(k) is blank")
        }
        XCTAssertGreaterThanOrEqual(Art.confettiVariants, 6)
    }

    func testConfettiWrapsAnyIndex() {
        XCTAssertTrue(Art.fx(.confetti(-1), size: 20, scale: 1) === Art.fx(.confetti(Art.confettiVariants - 1), size: 20, scale: 1))
        XCTAssertTrue(Art.fx(.confetti(Art.confettiVariants), size: 20, scale: 1) === Art.fx(.confetti(0), size: 20, scale: 1))
    }

    func testArenaSizesAndOpaque() {
        for k in ArenaKind.allCases {
            for (s, scale) in [(CGSize(width: 320, height: 568), 2.0), (CGSize(width: 1366, height: 1366), 1.0), (CGSize(width: 844, height: 390), 1.0)] as [(CGSize, CGFloat)] {
                let i = Art.arena(k, size: s, scale: scale)
                XCTAssertEqual(i.width, Int(s.width * scale)); XCTAssertEqual(i.height, Int(s.height * scale))
                XCTAssertEqual(i.alphaInfo, .noneSkipLast, k.rawValue)
            }
        }
    }

    func testLogoAspectFromArt() {
        let i = Art.logo(width: 300, scale: 2)
        XCTAssertEqual(i.width, 600)
        XCTAssertEqual(i.height, Int((600 * logoAspect).rounded()))
    }

    func testAppIconHasNoAlpha() {
        let i = Art.appIcon(pixels: 1024)
        XCTAssertEqual(i.width, 1024); XCTAssertEqual(i.height, 1024)
        XCTAssertEqual(i.alphaInfo, .noneSkipLast)
    }

    /// Nothing may reach the outer ring of pixels, at any size a bubble really appears.
    func testBubblesDoNotClip() {
        for size: CGFloat in [28, 36, 56, 180] {
            for scale: CGFloat in [1, 3] {
                for k in BubbleKind.allCases {
                    let (a, w, h) = alphaBytes(Art.bubble(k, size: size, scale: scale))
                    var worst: UInt8 = 0
                    for x in 0..<w { worst = max(worst, a[x], a[(h - 1) * w + x]) }
                    for y in 0..<h { worst = max(worst, a[y * w], a[y * w + w - 1]) }
                    XCTAssertEqual(worst, 0, "\(k) at \(size)@\(scale) touches the edge, alpha \(worst)")
                }
            }
        }
    }

    /// Body circle check: opaque where bodyFraction says body is, in the middle band of each axis.
    func testBodyFillsItsCircle() {
        for k in BubbleKind.allCases {
            let (a, w, _) = alphaBytes(Art.bubble(k, size: 100, scale: 2))
            let inside = Int(CGFloat(w) * (0.5 - Art.bodyFraction(k) / 2 * 0.92))
            XCTAssertEqual(a[w * (w / 2) + inside], 255, "\(k) has no body at its left edge")
        }
    }

    /// RGBA readback where row 0 is the top of the picture, as any viewer shows it.
    private func rgba(_ img: CGImage) -> (px: [UInt8], w: Int, h: Int) {
        let w = img.width, h = img.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        px.withUnsafeMutableBytes { raw in
            let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return (px, w, h)
    }

    /// The mouth has to be under the middle of the face, not over it.
    func testFacesAreUpright() {
        let (px, w, h) = rgba(Art.bubble(.basic, size: 100, scale: 2))
        func luma(_ yFrac: CGFloat) -> Int {
            let i = (Int(yFrac * CGFloat(h)) * w + w / 2) * 4
            return (Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2])) / 3
        }
        XCTAssertLessThan(luma(0.5 + 0.36 * 0.45), 70, "dark open mouth expected below centre")
        XCTAssertGreaterThan(luma(0.5 - 0.36 * 0.45), 120, "bright forehead expected above centre")
    }

    /// HINGE is blue and on top, POP is orange and below.
    func testLogoWordsAreRightWayUp() {
        let (px, w, h) = rgba(Art.logo(width: 300, scale: 1))
        func redMinusBlue(_ rows: Range<Int>) -> Int {
            var sum = 0
            for y in rows { for x in 0..<w { sum += Int(px[(y * w + x) * 4]) - Int(px[(y * w + x) * 4 + 2]) } }
            return sum
        }
        XCTAssertLessThan(redMinusBlue(h / 5..<(h * 2 / 5)), 0)
        XCTAssertGreaterThan(redMinusBlue(h * 3 / 5..<(h * 4 / 5)), 0)
    }

    /// Forest hills and foliage are greener than the night sky above them.
    func testArenaIsUpright() {
        let (px, w, h) = rgba(Art.arena(.forest, size: CGSize(width: 200, height: 400), scale: 1))
        func green(_ row: Int) -> Int { (0..<w).reduce(0) { $0 + Int(px[(row * w + $1) * 4 + 1]) } }
        XCTAssertGreaterThan(green(h - 20), green(10), "hills belong at the bottom")
    }

    /// Composed, not stretched: a wide arena is not a resample of a tall one.
    func testArenasComposeToShape() {
        let tall = rgba(Art.arena(.neon, size: CGSize(width: 200, height: 400), scale: 1))
        let wide = rgba(Art.arena(.neon, size: CGSize(width: 400, height: 200), scale: 1))
        // The horizon sits in the lower part of both, at about the same fraction of height,
        // and the wide one must not have squashed peaks: its floor takes a larger share.
        XCTAssertEqual(tall.w, 200); XCTAssertEqual(wide.w, 400)
        func rowBright(_ a: (px: [UInt8], w: Int, h: Int), _ y: Int) -> Int { (0..<a.w).reduce(0) { $0 + Int(a.px[(y * a.w + $1) * 4]) } / a.w }
        func horizon(_ a: (px: [UInt8], w: Int, h: Int)) -> Int { (a.h / 2..<a.h).max { rowBright(a, $0) < rowBright(a, $1) }! }
        XCTAssertGreaterThan(CGFloat(horizon(tall)) / 400, 0.7)
        XCTAssertLessThan(CGFloat(horizon(wide)) / 200, CGFloat(horizon(tall)) / 400)
    }

    func testCacheReturnsSameImage() {
        XCTAssertTrue(Art.bubble(.basic, size: 77, scale: 2) === Art.bubble(.basic, size: 77, scale: 2))
        XCTAssertFalse(Art.bubble(.basic, size: 77, scale: 2) === Art.bubble(.basic, size: 78, scale: 2))
        XCTAssertFalse(Art.bubble(.basic, size: 77, scale: 2) === Art.bubble(.fast, size: 77, scale: 2))
        let s = CGSize(width: 111, height: 222)
        XCTAssertTrue(Art.arena(.neon, size: s, scale: 1) === Art.arena(.neon, size: s, scale: 1))
        XCTAssertTrue(Art.appIcon(pixels: 64) === Art.appIcon(pixels: 64))
    }

    func testCacheIsThreadSafe() {
        let results = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 64)
        defer { results.deallocate() }
        results.initialize(repeating: nil, count: 64)
        DispatchQueue.concurrentPerform(iterations: 64) { i in
            let img = Art.bubble(.golden, size: 90, scale: 3)
            _ = Art.power(.freeze, size: CGFloat(20 + i % 4), scale: 2)
            results[i] = UnsafeRawPointer(Unmanaged.passUnretained(img).toOpaque())
        }
        for i in 1..<64 { XCTAssertEqual(results[i], results[0]) }
    }

    // MARK: Speed. Budgets from the brief, with slack for a loaded machine and debug builds.

    func testBubbleSpeedBudget() {
        for k in BubbleKind.allCases {
            let t = bestOf(3) { i in _ = Art.bubble(k, size: 200 + CGFloat(i) * 0.25, scale: 3) }
            print("bubble \(k.rawValue) 200pt@3x \(ms(t)) ms")
            XCTAssertLessThan(t, 0.030, "\(k) budget is about 15 ms")
        }
    }

    func testArenaSpeedBudget() {
        for k in ArenaKind.allCases {
            let t = bestOf(2) { i in _ = Art.arena(k, size: CGSize(width: 390 + CGFloat(i), height: 844), scale: 3) }
            print("arena \(k.rawValue) 390x844@3x \(ms(t)) ms")
            XCTAssertLessThan(t, 0.200, "\(k) budget is about 100 ms")
        }
    }

    func testLaunchPreRender() {
        let start = CFAbsoluteTimeGetCurrent()
        for k in BubbleKind.allCases { _ = Art.bubble(k, size: 96.5, scale: 3) }
        for k in PowerKind.allCases { _ = Art.power(k, size: 60.5, scale: 3) }
        for k in UIGlyph.allCases { _ = Art.glyph(k, size: 44.5, scale: 3) }
        for i in 0..<Art.confettiVariants { _ = Art.fx(.confetti(i), size: 16.5, scale: 3) }
        let t = CFAbsoluteTimeGetCurrent() - start
        print("launch set \(ms(t)) ms")
        XCTAssertLessThan(t, 0.35)
    }

    private func ms(_ t: Double) -> String { String(format: "%.1f", t * 1000) }

    private func bestOf(_ n: Int, _ work: (Int) -> Void) -> Double {
        var best = Double.infinity
        for i in 0..<n {
            let start = CFAbsoluteTimeGetCurrent()
            work(i)
            best = min(best, CFAbsoluteTimeGetCurrent() - start)
        }
        return best
    }
}
