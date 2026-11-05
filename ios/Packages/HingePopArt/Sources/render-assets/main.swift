import CoreGraphics
import CoreText
import Foundation
import HingePopArt
import ImageIO
import UniformTypeIdentifiers

// swift run render-assets <outDir>
// Writes sheet.png, arena-<kind>-<w>x<h>.png, logo.png and AppIcon-1024.png.

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func writePNG(_ img: CGImage, _ name: String) {
    let url = out.appendingPathComponent(name)
    guard let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("no destination \(name)") }
    CGImageDestinationAddImage(d, img, nil)
    guard CGImageDestinationFinalize(d) else { fatalError("could not write \(name)") }
    print("wrote", url.path)
}

// `--sprites` writes each asset alone, for the website and store art, and stops.
if CommandLine.arguments.contains("--sprites") {
    for k in BubbleKind.allCases { writePNG(Art.bubble(k, size: 256, scale: 2), "bubble-\(k.rawValue).png") }
    for k in CameoKind.allCases { writePNG(Art.cameo(k, size: 160, scale: 2), "cameo-\(k.rawValue).png") }
    for k in PowerKind.allCases { writePNG(Art.power(k, size: 160, scale: 2), "power-\(k.rawValue).png") }
    for g in UIGlyph.allCases { writePNG(Art.glyph(g, size: 96, scale: 2), "glyph-\(g.rawValue).png") }
    for a in ArenaKind.allCases {
        writePNG(Art.arena(a, size: CGSize(width: 1600, height: 1000), scale: 1), "arena-\(a.rawValue)-wide.png")
        writePNG(Art.arena(a, size: CGSize(width: 800, height: 1400), scale: 1), "arena-\(a.rawValue)-tall.png")
    }
    writePNG(Art.logo(width: 900, scale: 2), "logo.png")
    writePNG(Art.fx(.popBurst, size: 200, scale: 2), "fx-popBurst.png")
    writePNG(Art.fx(.particleStar, size: 64, scale: 2), "fx-particleStar.png")
    exit(0)
}

// MARK: Sheet layout. Points, y down.

let scale: CGFloat = 2
let W: CGFloat = 1500, H: CGFloat = 1700
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(W * scale), height: Int(H * scale), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.translateBy(x: 0, y: H * scale)
ctx.scaleBy(x: scale, y: -scale)
ctx.interpolationQuality = .high

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
}

func put(_ img: CGImage, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
    // Context is y-down, and CGContext.draw expects y-up, so undo the flip per image.
    ctx.saveGState()
    ctx.translateBy(x: x, y: y + h)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    ctx.restoreGState()
}

func label(_ s: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: CGFloat = 0.3, color: CGColor = rgb(0xFFFFFF), center: Bool = false) {
    let base = CTFontCreateUIFontForLanguage(.system, size, nil)!
    let d = CTFontDescriptorCreateCopyWithAttributes(CTFontCopyFontDescriptor(base),
        [kCTFontTraitsAttribute as String: [kCTFontWeightTrait as String: weight, "NSCTFontUIFontDesignTrait": "NSCTFontUIFontDesignRounded"]] as CFDictionary)
    let font = CTFontCreateWithFontDescriptor(d, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorAttributeName as NSAttributedString.Key: color,
    ]))
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    ctx.saveGState()
    ctx.translateBy(x: center ? x - CGFloat(width) / 2 : x, y: y)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func panel(_ r: CGRect, _ title: String) {
    let p = CGPath(roundedRect: r, cornerWidth: 16, cornerHeight: 16, transform: nil)
    ctx.addPath(p); ctx.setFillColor(rgb(0x1A0C48, 0.72)); ctx.fillPath()
    ctx.addPath(p); ctx.setStrokeColor(rgb(0x8E6CF0, 0.75)); ctx.setLineWidth(1.5); ctx.strokePath()
    label(title, x: r.minX + 20, y: r.minY + 34, size: 22, weight: 0.4)
}

// Background.
ctx.setFillColor(rgb(0x120638)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
let bg = CGGradient(colorsSpace: space, colors: [rgb(0x3A1486), rgb(0x120638)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(bg, startCenter: CGPoint(x: W / 2, y: 420), startRadius: 0, endCenter: CGPoint(x: W / 2, y: 420), endRadius: 1100, options: .drawsAfterEndLocation)

let display: (BubbleKind) -> String = {
    switch $0 {
    case .basic: return "Basic"; case .fast: return "Fast"; case .armored: return "Armored"
    case .armoredCracked: return "Cracked"; case .magnetic: return "Magnetic"; case .repel: return "Repel"
    case .golden: return "Golden"; case .frozen: return "Frozen"; case .boss: return "Boss"; case .bossHurt: return "Boss Hurt"
    }
}

label("GAME ASSETS", x: 26, y: 46, size: 34, weight: 0.5)
label("HingePopArt contact sheet, everything drawn in CoreGraphics", x: 268, y: 46, size: 18, weight: 0.1, color: rgb(0xD8C8FF))

// Bubble actors: 180pt in two rows of five, 36pt and 28pt next to each.
panel(CGRect(x: 16, y: 66, width: W - 32, height: 590), "BUBBLE ACTORS")
let kinds = BubbleKind.allCases
for (i, k) in kinds.enumerated() {
    let col = CGFloat(i % 5), row = CGFloat(i / 5)
    let cw = (W - 56) / 5
    let x = 28 + col * cw, y = 108 + row * 270
    let big = Art.bubble(k, size: 180, scale: scale)
    put(big, x: x + 8, y: y, w: 180, h: 180)
    label(display(k), x: x + 98, y: y + 202, size: 17, weight: 0.3, center: true)
    label(String(format: "body %.2f", Art.bodyFraction(k)), x: x + 98, y: y + 222, size: 12, weight: 0, color: rgb(0xC8B8F0), center: true)
    put(Art.bubble(k, size: 36, scale: scale), x: x + 192, y: y + 68, w: 36, h: 36)
    put(Art.bubble(k, size: 28, scale: scale), x: x + 196, y: y + 112, w: 28, h: 28)
}

// Power-ups.
panel(CGRect(x: 16, y: 668, width: 830, height: 220), "POWER-UPS & ITEMS")
let powerNames: [(PowerKind, String)] = [(.overcharge, "Overcharge"), (.freeze, "Freeze"), (.focus, "Focus"), (.shield, "Shield"), (.chainBurst, "Chain Burst")]
for (i, (k, n)) in powerNames.enumerated() {
    let x = 36 + CGFloat(i) * 160
    put(Art.power(k, size: 110, scale: scale), x: x, y: 716, w: 110, h: 110)
    put(Art.power(k, size: 36, scale: scale), x: x + 112, y: 760, w: 36, h: 36)
    label(n, x: x + 55, y: 860, size: 16, center: true)
}

// UI.
panel(CGRect(x: 858, y: 668, width: W - 874, height: 220), "UI ELEMENTS")
let glyphs: [UIGlyph] = [.shieldOn, .shieldOff, .starOn, .starOff]
for (i, g) in glyphs.enumerated() {
    put(Art.glyph(g, size: 66, scale: scale), x: 876 + CGFloat(i) * 76, y: 714, w: 66, h: 66)
    put(Art.glyph(g, size: 28, scale: scale), x: 896 + CGFloat(i) * 76, y: 786, w: 28, h: 28)
}
let buttons: [UIGlyph] = [.play, .pause, .settings, .lock]
for (i, g) in buttons.enumerated() {
    let x = 1190 + CGFloat(i % 2) * 138, y = 708 + CGFloat(i / 2) * 84
    put(Art.glyph(g, size: 76, scale: scale), x: x, y: y, w: 76, h: 76)
    put(Art.glyph(g, size: 36, scale: scale), x: x + 80, y: y + 20, w: 36, h: 36)
}

// Environment and FX.
panel(CGRect(x: 16, y: 900, width: W - 32, height: 340), "ENVIRONMENT & FX")
let arenaNames: [(ArenaKind, String)] = [(.classic, "Arena - Classic"), (.neon, "Arena - Neon"), (.forest, "Arena - Forest"), (.space, "Arena - Space")]
for (i, (k, n)) in arenaNames.enumerated() {
    let x = 34 + CGFloat(i) * 150
    let a = Art.arena(k, size: CGSize(width: 130, height: 240), scale: scale)
    let r = CGRect(x: x, y: 946, width: 130, height: 240)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 12, cornerHeight: 12, transform: nil)); ctx.clip()
    put(a, x: r.minX, y: r.minY, w: r.width, h: r.height)
    ctx.restoreGState()
    label(n, x: x + 65, y: 1214, size: 14, center: true)
}
let fxList: [(FXKind, String)] = [(.popBurst, "Pop Burst"), (.shockwave, "Shockwave"), (.particleStar, "Particle Star")]
for (i, (k, n)) in fxList.enumerated() {
    let x = 650 + CGFloat(i) * 200
    put(Art.fx(k, size: 170, scale: scale), x: x, y: 966, w: 170, h: 170)
    label(n, x: x + 85, y: 1214, size: 15, center: true)
}
for i in 0..<Art.confettiVariants {
    let x = 1252 + CGFloat(i % 4) * 54, y = 1000 + CGFloat(i / 4) * 66
    put(Art.fx(.confetti(i), size: 48, scale: scale), x: x, y: y, w: 48, h: 48)
}
label("Confetti", x: 1360, y: 1214, size: 15, center: true)

// Branding.
panel(CGRect(x: 16, y: 1252, width: W - 32, height: 432), "BRANDING")
let logo = Art.logo(width: 440, scale: scale)
let lh = 440 * CGFloat(logo.height) / CGFloat(logo.width)
put(logo, x: 60, y: 1290, w: 440, h: lh)
put(Art.logo(width: 150, scale: scale), x: 520, y: 1440, w: 150, h: 150 * lh / 440)
let iconPath = CGPath(roundedRect: CGRect(x: 760, y: 1290, width: 360, height: 360), cornerWidth: 80, cornerHeight: 80, transform: nil)
ctx.saveGState(); ctx.addPath(iconPath); ctx.clip()
put(Art.appIcon(pixels: 720), x: 760, y: 1290, w: 360, h: 360)
ctx.restoreGState()
ctx.saveGState(); ctx.addPath(CGPath(roundedRect: CGRect(x: 1160, y: 1500, width: 120, height: 120), cornerWidth: 27, cornerHeight: 27, transform: nil)); ctx.clip()
put(Art.appIcon(pixels: 240), x: 1160, y: 1500, w: 120, h: 120)
ctx.restoreGState()
ctx.saveGState(); ctx.addPath(CGPath(roundedRect: CGRect(x: 1300, y: 1560, width: 60, height: 60), cornerWidth: 14, cornerHeight: 14, transform: nil)); ctx.clip()
put(Art.appIcon(pixels: 120), x: 1300, y: 1560, w: 60, h: 60)
ctx.restoreGState()

writePNG(ctx.makeImage()!, "sheet.png")

// MARK: Full size files

for k in ArenaKind.allCases {
    writePNG(Art.arena(k, size: CGSize(width: 390, height: 844), scale: 2), "arena-\(k.rawValue)-390x844.png")
    writePNG(Art.arena(k, size: CGSize(width: 1366, height: 1024), scale: 1), "arena-\(k.rawValue)-1366x1024.png")
}
writePNG(Art.logo(width: 1000, scale: 1), "logo.png")
writePNG(Art.appIcon(pixels: 1024), "AppIcon-1024.png")
