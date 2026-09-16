import Foundation

/// Card names shown under the card. The settings screen morphs between them.
enum CardTitles {
    static let all = ["Sand dunes", "Classic Plata", "Metal Plata", "Beautiful nature"]
}

/// Which way a glyph is rotated. Turned into a SwiftUI axis where the title is drawn.
enum MorphAxis {
    case x, y, z
}

/// How one glyph looks part way through a transition. Every engine is written as this struct over
/// a local progress from 0 to 1, so adding a technique is arithmetic rather than new drawing code.
struct GlyphAppearance {
    var opacity: Double = 1
    var scale: Double = 1
    var dx: Double = 0
    var dy: Double = 0
    var blur: Double = 0
    /// Degrees.
    var rotation: Double = 0
    var axis: MorphAxis = .z
    /// Drawn in place of the real character while it is still spinning.
    var substitute: Character?
}

/// The candidate techniques, each modelled on the open-source project named in `source`.
enum MorphStyle: Int, CaseIterable, Identifiable {
    /// Shared characters travel to their new position instead of fading.
    case diff
    /// Characters leave upwards and arrive from below, one after another.
    case stagger
    /// Old characters shrink away to nothing, new ones grow out of nothing.
    case scale
    /// Old characters drift up and blur out, new ones condense down into place.
    case evaporate
    /// Old characters tip over and drop out of the line, new ones fall in from above.
    case fall
    /// Characters balloon outwards as they leave and shrink in from oversize as they arrive.
    case shapeshift
    /// No movement at all: a left-to-right wipe from the old name to the new one.
    case reveal
    /// Each character turns edge-on and the replacement turns back in behind it.
    case spin
    /// Arriving characters cycle through the alphabet before settling on the real letter.
    case roulette
    /// Pure defocus: the old name blurs out while the new name sharpens up.
    case blur
    /// Characters shrink towards their centre with a narrow left-to-right wave.
    case shrink

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .diff: return "Diff"
        case .stagger: return "Stagger"
        case .scale: return "Scale"
        case .evaporate: return "Evaporate"
        case .fall: return "Fall"
        case .shapeshift: return "Shapeshift"
        case .reveal: return "Reveal"
        case .spin: return "Spin"
        case .roulette: return "Roulette"
        case .blur: return "Blur"
        case .shrink: return "Shrink"
        }
    }

    /// The project this technique is taken from.
    var source: String {
        switch self {
        case .diff: return "textmorph-ios"
        case .stagger: return "AnimateText"
        case .scale, .evaporate: return "LTMorphingLabel"
        case .fall: return "LTMorphingLabel / ZCAnimatedLabel"
        case .shapeshift, .reveal, .spin: return "ZCAnimatedLabel"
        case .roulette, .blur: return "SwiftUI-Text-Animation-Library"
        case .shrink: return "TOMSMorphingLabel"
        }
    }

    var detail: String {
        switch self {
        case .diff:
            return "Shared characters keep their identity and slide to the new position; only the rest fade."
        case .stagger:
            return "Every character leaves upwards and the new ones arrive from below, one after another."
        case .scale:
            return "Old characters shrink away to nothing and the new ones grow out of nothing."
        case .evaporate:
            return "Old characters drift up and blur out while the new ones condense down into place."
        case .fall:
            return "Old characters tip over and drop out of the line; new ones fall in from above."
        case .shapeshift:
            return "Characters balloon outwards as they leave and shrink in from oversize as they arrive."
        case .reveal:
            return "No movement at all: a left-to-right wipe from the old name to the new one."
        case .spin:
            return "Each character turns edge-on and its replacement turns back in behind it."
        case .roulette:
            return "Arriving characters cycle through the alphabet before settling on the real letter."
        case .blur:
            return "Pure defocus: the old name blurs out while the new name sharpens up."
        case .shrink:
            return "Characters shrink towards their centre with a narrow left-to-right wave."
        }
    }

    /// Only the diff engine matches characters between the two names; every other technique
    /// replaces the whole line.
    var usesPairing: Bool { self == .diff }

    /// How much of the timeline the left-to-right wave takes. 0 moves every character together.
    var spread: Double {
        switch self {
        case .diff: return 0
        case .stagger, .spin: return 0.5
        case .scale: return 0.35
        case .evaporate: return 0.7
        case .fall: return 0.45
        case .shapeshift: return 0.3
        case .reveal: return 0.85
        case .roulette: return 0.4
        case .blur: return 0
        case .shrink: return 0.25
        }
    }

    /// A character of the old name, `amount` of the way out. At 0 it sits at rest, at 1 it is gone.
    func leaving(_ amount: Double) -> GlyphAppearance {
        switch self {
        case .diff:
            return GlyphAppearance(opacity: 1 - amount, scale: 1 - 0.22 * amount)
        case .stagger:
            return GlyphAppearance(opacity: 1 - amount, scale: 1 - 0.1 * amount,
                                   dy: -10 * amount, blur: 3 * amount)
        case .scale:
            return GlyphAppearance(opacity: 1 - amount, scale: 1 - amount)
        case .evaporate:
            return GlyphAppearance(opacity: 1 - amount, dy: -24 * amount, blur: 6 * amount)
        case .fall:
            return GlyphAppearance(opacity: 1 - amount, dy: 40 * amount, rotation: 28 * amount)
        case .shapeshift:
            return GlyphAppearance(opacity: 1 - amount, scale: 1 + 1.4 * amount, blur: 5 * amount)
        case .reveal:
            return GlyphAppearance(opacity: 1 - amount)
        case .spin:
            return GlyphAppearance(opacity: 1 - amount, rotation: 90 * amount, axis: .y)
        case .roulette:
            return GlyphAppearance(opacity: 1 - min(1, amount * 2.5))
        case .blur:
            return GlyphAppearance(opacity: 1 - amount, blur: 8 * amount)
        case .shrink:
            return GlyphAppearance(opacity: 1 - amount, scale: 1 - 0.65 * amount)
        }
    }

    /// A character of the new name, `amount` of the way in. At 1 every engine must be at rest:
    /// full opacity, no scaling, no offset, no blur, no rotation and the real character.
    func arriving(_ amount: Double, seed: Int) -> GlyphAppearance {
        let togo = 1 - amount
        switch self {
        case .diff:
            return GlyphAppearance(opacity: amount, scale: 1 - 0.22 * togo)
        case .stagger:
            return GlyphAppearance(opacity: amount, scale: 1 - 0.1 * togo,
                                   dy: 10 * togo, blur: 3 * togo)
        case .scale:
            return GlyphAppearance(opacity: amount, scale: amount)
        case .evaporate:
            return GlyphAppearance(opacity: amount, dy: 24 * togo, blur: 6 * togo)
        case .fall:
            return GlyphAppearance(opacity: amount, dy: -40 * togo, rotation: -28 * togo)
        case .shapeshift:
            return GlyphAppearance(opacity: amount, scale: 1 + 1.4 * togo, blur: 5 * togo)
        case .reveal:
            return GlyphAppearance(opacity: amount)
        case .spin:
            return GlyphAppearance(opacity: amount, rotation: -90 * togo, axis: .y)
        case .roulette:
            return GlyphAppearance(opacity: min(1, amount * 2.5),
                                   substitute: amount >= 1 ? nil : MorphStyle.spinning(seed: seed, amount: amount))
        case .blur:
            return GlyphAppearance(opacity: amount, blur: 8 * togo)
        case .shrink:
            return GlyphAppearance(opacity: amount, scale: 1 - 0.65 * togo)
        }
    }

    private static let wheel = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")

    /// A letter off the wheel. Stepping on `amount` rather than a timer keeps it in sync with the
    /// spring and repeatable frame to frame.
    static func spinning(seed: Int, amount: Double) -> Character {
        let tick = Int(amount * 16) + seed * 5
        return wheel[((tick % wheel.count) + wheel.count) % wheel.count]
    }
}

/// One character that exists in both strings, addressed by its index in each.
struct MorphPair: Equatable {
    let from: Int
    let to: Int
}

/// Longest common subsequence of the two character arrays. Every pair is a glyph that appears in
/// both strings in the same order, so it can travel instead of fading out and back in.
/// Whitespace never pairs: it draws nothing, and matching it would spend the budget that visible
/// glyphs need — `Classic Plata` → `Metal Plata` keeps the whole word `Plata` this way.
func morphPairs(from old: [Character], to new: [Character]) -> [MorphPair] {
    guard !old.isEmpty, !new.isEmpty else { return [] }
    // table[i][j] is the match count of old[i...] against new[j...].
    var table = [[Int]](repeating: [Int](repeating: 0, count: new.count + 1), count: old.count + 1)
    for i in stride(from: old.count - 1, through: 0, by: -1) {
        for j in stride(from: new.count - 1, through: 0, by: -1) {
            if old[i] == new[j] && !old[i].isWhitespace {
                table[i][j] = table[i + 1][j + 1] + 1
            } else {
                table[i][j] = max(table[i + 1][j], table[i][j + 1])
            }
        }
    }
    var pairs: [MorphPair] = []
    var i = 0
    var j = 0
    while i < old.count && j < new.count {
        if old[i] == new[j] && !old[i].isWhitespace {
            pairs.append(MorphPair(from: i, to: j))
            i += 1
            j += 1
        } else if table[i + 1][j] >= table[i][j + 1] {
            i += 1
        } else {
            j += 1
        }
    }
    return pairs
}
