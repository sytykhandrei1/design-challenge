import Foundation

/// Card names shown under the card. The settings screen morphs between them.
enum CardTitles {
    static let all = ["Sand dunes", "Classic Plata", "Metal Plata", "Beautiful nature"]
}

/// The three candidate techniques for the animated title, compared side by side in settings.
enum MorphStyle: Int, CaseIterable, Identifiable {
    /// SwiftUI's own `contentTransition(.interpolate)`, as used by the navigation title today.
    case native
    /// Characters present in both strings travel to their new position; the rest fade.
    case diff
    /// Every character leaves and arrives with a per-character delay, as in AnimateText.
    case stagger

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .native: return "Native"
        case .diff: return "Diff"
        case .stagger: return "Stagger"
        }
    }

    var detail: String {
        switch self {
        case .native:
            return "SwiftUI contentTransition(.interpolate). No layout work, the whole label cross-fades."
        case .diff:
            return "Shared characters keep their identity and slide to the new position; only the rest fade."
        case .stagger:
            return "Every character leaves upwards and the new ones arrive from below, one after another."
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
