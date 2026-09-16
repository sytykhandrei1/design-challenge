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
    /// Drawn in place of the real character. No engine substitutes today; the hook is left in
    /// because the renderer already honours it.
    var substitute: Character?
}

/// The candidate techniques, each modelled on the open-source project named in `source`.
enum MorphStyle: Int, CaseIterable, Identifiable {
    /// Shared characters travel to their new position instead of fading.
    case diff
    /// Characters leave upwards and arrive from below, one after another.
    case stagger
    /// Characters balloon outwards as they leave and shrink in from oversize as they arrive.
    case shapeshift
    /// Pure defocus: the old name blurs out while the new name sharpens up.
    case blur

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .diff: return "Diff"
        case .stagger: return "Stagger"
        case .shapeshift: return "Shapeshift"
        case .blur: return "Blur"
        }
    }

    /// The project this technique is taken from.
    var source: String {
        switch self {
        case .diff: return "textmorph-ios"
        case .stagger: return "AnimateText"
        case .shapeshift: return "ZCAnimatedLabel"
        case .blur: return "SwiftUI-Text-Animation-Library"
        }
    }

    var detail: String {
        switch self {
        case .diff:
            return "Shared characters keep their identity and slide to the new position; only the rest fade."
        case .stagger:
            return "Every character leaves upwards and the new ones arrive from below, one after another."
        case .shapeshift:
            return "Characters balloon outwards as they leave and shrink in from oversize as they arrive."
        case .blur:
            return "Pure defocus: the old name blurs out while the new name sharpens up."
        }
    }

    /// Only the diff engine matches characters between the two names; every other technique
    /// replaces the whole line.
    var usesPairing: Bool { self == .diff }

    /// How much of the timeline the left-to-right wave takes. 0 moves every character together.
    var spread: Double {
        switch self {
        case .diff: return 0
        case .stagger: return 0.5
        case .shapeshift: return 0.3
        case .blur: return 0
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
        case .shapeshift:
            return GlyphAppearance(opacity: 1 - amount, scale: 1 + 1.4 * amount, blur: 5 * amount)
        case .blur:
            return GlyphAppearance(opacity: 1 - amount, blur: 8 * amount)
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
        case .shapeshift:
            return GlyphAppearance(opacity: amount, scale: 1 + 1.4 * togo, blur: 5 * togo)
        case .blur:
            return GlyphAppearance(opacity: amount, blur: 8 * togo)
        }
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
