import CoreGraphics
import XCTest
@testable import HingePopArt

final class VillainArtTests: XCTestCase {
    /// RGBA bytes, so tests can look at colour as well as coverage.
    private func rgba(_ img: CGImage) -> [UInt8] {
        let w = img.width, h = img.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        data.withUnsafeMutableBytes { raw in
            let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return data
    }

    func testEveryVillainRendersAtSizeBigAndSmall() {
        for k in VillainSprite.allCases {
            for (size, scale) in [(CGFloat(160), CGFloat(2)), (44, 3)] {
                let i = Art.villain(k, size: size, scale: scale)
                XCTAssertEqual(i.width, Int(size * scale), k.rawValue)
                XCTAssertEqual(i.height, Int(size * scale), k.rawValue)
                let px = rgba(i)
                let covered = stride(from: 3, to: px.count, by: 4).filter { px[$0] > 128 }.count
                XCTAssertGreaterThan(Double(covered) / Double(i.width * i.height), 0.35, "\(k) is mostly empty")
            }
        }
    }

    func testEveryVillainLooksDifferent() {
        let shots = VillainSprite.allCases.map { rgba(Art.villain($0, size: 48, scale: 1)) }
        for i in shots.indices {
            for j in shots.indices where j > i {
                let diff = zip(shots[i], shots[j]).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
                XCTAssertGreaterThan(diff / shots[i].count, 8, "\(VillainSprite.allCases[i]) and \(VillainSprite.allCases[j]) look alike")
            }
        }
    }

    /// The warning rim is the tell: every villain shows its tier's colour around the body, even the Mimic, whose
    /// golden rays sit over it. Checked on a ring just outside the body.
    func testTheWarningRimShowsTheTier() {
        for k in VillainSprite.allCases {
            let n = 200, i = Art.villain(k, size: CGFloat(n), scale: 1), px = rgba(i)
            let want = warningColor(k.tier)
            var hits = 0, samples = 0
            for a in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 90) {
                for f in [0.40, 0.42, 0.44] {
                    let x = Int(Double(n) * (0.5 + cos(a) * f)), y = Int(Double(n) * (0.5 + sin(a) * f))
                    let o = (y * n + x) * 4
                    samples += 1
                    guard px[o + 3] > 200 else { continue }
                    let r = Double(px[o]) / 255, g = Double(px[o + 1]) / 255, b = Double(px[o + 2]) / 255
                    if abs(r - want.r) < 0.22 && abs(g - want.g) < 0.22 && abs(b - want.b) < 0.22 { hits += 1 }
                }
            }
            XCTAssertGreaterThan(Double(hits) / Double(samples), k == .mimic || k == .phantom ? 0.02 : 0.08, "\(k)'s rim doesn't read as tier \(k.tier)")
        }
        XCTAssertEqual(Set(VillainSprite.allCases.map(\.tier)), [1, 2, 3])
    }

    func testVillainsAreCached() {
        XCTAssertTrue(Art.villain(.void, size: 50, scale: 2) === Art.villain(.void, size: 50, scale: 2))
        XCTAssertFalse(Art.villain(.void, size: 50, scale: 2) === Art.villain(.hex, size: 50, scale: 2))
    }
}
