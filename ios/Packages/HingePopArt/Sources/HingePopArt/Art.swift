import CoreGraphics
import Foundation

public enum BubbleKind: String, CaseIterable, Sendable {
    case basic, fast, armored, armoredCracked, magnetic, repel, golden, frozen, boss, bossHurt
}
public enum PowerKind: String, CaseIterable, Sendable { case overcharge, freeze, focus, shield, chainBurst }
public enum ArenaKind: String, CaseIterable, Sendable { case classic, neon, forest, space }
public enum UIGlyph: String, CaseIterable, Sendable { case shieldOn, shieldOff, starOn, starOff, play, pause, settings, lock }
public enum FXKind: Hashable, Sendable { case popBurst, shockwave, particleStar, confetti(Int) }

public enum Art {
    /// Number of distinct confetti pieces. `FXKind.confetti(n)` wraps, so any Int is valid.
    public static let confettiVariants = confettiCount

    /// Renders at size * scale, with alpha. Results are cached by (item, size, scale); thread safe.
    public static func bubble(_ kind: BubbleKind, size: CGFloat, scale: CGFloat) -> CGImage {
        cached(.bubble(kind), size, size, scale) {
            let small = size < smallBelow
            return unitSprite(pixels: px(size, scale)) { drawBubble(kind, $0, small: small) }
        }
    }

    public static func power(_ kind: PowerKind, size: CGFloat, scale: CGFloat) -> CGImage {
        cached(.power(kind), size, size, scale) {
            unitSprite(pixels: px(size, scale)) { drawPower(kind, $0) }
        }
    }

    public static func glyph(_ glyph: UIGlyph, size: CGFloat, scale: CGFloat) -> CGImage {
        cached(.glyph(glyph), size, size, scale) {
            unitSprite(pixels: px(size, scale)) { drawGlyph(glyph, $0) }
        }
    }

    public static func fx(_ kind: FXKind, size: CGFloat, scale: CGFloat) -> CGImage {
        let norm: FXKind
        if case .confetti(let n) = kind { norm = .confetti(((n % confettiCount) + confettiCount) % confettiCount) } else { norm = kind }
        return cached(.fx(norm), size, size, scale) {
            unitSprite(pixels: px(size, scale)) { drawFX(norm, $0) }
        }
    }

    /// Opaque. Composed for the requested shape rather than stretched.
    public static func arena(_ kind: ArenaKind, size: CGSize, scale: CGFloat) -> CGImage {
        cached(.arena(kind), size.width, size.height, scale) {
            makeImage(pxW: px(size.width, scale), pxH: px(size.height, scale), opaque: true,
                      unitsX: size.width, unitsY: size.height) { drawArena(kind, $0, size: size) }
        }
    }

    /// Height follows from `logoAspect`, height / width.
    public static func logo(width: CGFloat, scale: CGFloat) -> CGImage {
        cached(.logo, width, width, scale) {
            let pw = px(width, scale)
            let ph = max(Int((CGFloat(pw) * logoAspect).rounded()), 1)
            return makeImage(pxW: pw, pxH: ph, opaque: false, unitsX: 1, unitsY: logoAspect) { drawLogo($0) }
        }
    }

    /// Opaque square.
    public static func appIcon(pixels: Int) -> CGImage {
        cached(.appIcon, CGFloat(pixels), CGFloat(pixels), 1) {
            makeImage(pxW: pixels, pxH: pixels, opaque: true, unitsX: 1, unitsY: 1) { drawAppIcon($0) }
        }
    }

    /// Body circle diameter / image size. The body is always centred in the image.
    public static func bodyFraction(_ kind: BubbleKind) -> CGFloat {
        switch kind {
        case .boss, .bossHurt: return bossBodyRadius * 2
        default: return bodyRadius * 2
        }
    }

    // MARK: Cache

    private enum Item: Hashable {
        case bubble(BubbleKind), power(PowerKind), glyph(UIGlyph), fx(FXKind), arena(ArenaKind), logo, appIcon
    }
    private struct Key: Hashable { let item: Item; let w: CGFloat; let h: CGFloat; let scale: CGFloat }

    private static let lock = NSLock()
    private static var images: [Key: CGImage] = [:]
    private static var order: [Key] = []
    private static var bytes = 0
    /// Enough for every arena and sprite the app can hold at once. Oldest goes first past this.
    private static let byteLimit = 384 * 1024 * 1024

    private static func px(_ v: CGFloat, _ scale: CGFloat) -> Int { max(Int((v * scale).rounded()), 1) }

    private static func cached(_ item: Item, _ w: CGFloat, _ h: CGFloat, _ scale: CGFloat, _ render: () -> CGImage) -> CGImage {
        let key = Key(item: item, w: w, h: h, scale: scale)
        lock.lock()
        if let hit = images[key] { lock.unlock(); return hit }
        lock.unlock()

        // Rendered outside the lock so a big arena does not stall sprite lookups on other
        // threads. If two threads race, the first one stored wins and both return it.
        let image = render()

        lock.lock(); defer { lock.unlock() }
        if let hit = images[key] { return hit }
        images[key] = image
        order.append(key)
        bytes += image.bytesPerRow * image.height
        while bytes > byteLimit, order.count > 1 {
            let old = order.removeFirst()
            if let gone = images.removeValue(forKey: old) { bytes -= gone.bytesPerRow * gone.height }
        }
        return image
    }
}
