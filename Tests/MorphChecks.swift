import Foundation

@main
struct MorphChecks {
    static func main() {
        checkNames()
        checkPairs()
        checkEngines()
        print("PASS: names, identity, reading order, whitespace, word survival, empty input, "
              + "\(MorphStyle.allCases.count) engines at rest")
    }

    // MARK: Character diff

    private static func checkNames() {
        precondition(CardTitles.all == ["Sand dunes", "Classic Plata", "Metal Plata", "Beautiful nature"])

        // A name morphing into itself keeps every visible character; spaces never pair.
        let visible = [9, 12, 10, 15]
        for (slot, title) in CardTitles.all.enumerated() {
            let characters = Array(title)
            let pairs = morphPairs(from: characters, to: characters)
            precondition(pairs.count == visible[slot], "Identity morph must keep every glyph")
            precondition(pairs.allSatisfy { $0.from == $0.to }, "Identity morph must not move glyphs")
        }
    }

    private static func checkPairs() {
        // Shared characters found between every ordered pair of names.
        let expected: [[Int]] = [[0, 2, 1, 4], [2, 0, 6, 5], [1, 6, 0, 5], [4, 5, 5, 0]]
        for (from, old) in CardTitles.all.enumerated() {
            for (to, new) in CardTitles.all.enumerated() where from != to {
                let before = Array(old)
                let after = Array(new)
                let pairs = morphPairs(from: before, to: after)
                precondition(pairs.count == expected[from][to],
                             "\(old) -> \(new) should share \(expected[from][to]) glyphs, got \(pairs.count)")
                var lastFrom = -1
                var lastTo = -1
                for pair in pairs {
                    precondition(pair.from > lastFrom && pair.to > lastTo, "Pairs must keep reading order")
                    precondition(before[pair.from] == after[pair.to], "A pair must be the same glyph")
                    precondition(!before[pair.from].isWhitespace, "Whitespace must never pair")
                    lastFrom = pair.from
                    lastTo = pair.to
                }
            }
        }

        // The point of the diff engine: a whole word survives instead of fading out and back in.
        let classic = Array("Classic Plata")
        let metal = Array("Metal Plata")
        let carried = String(morphPairs(from: classic, to: metal).map { classic[$0.from] })
        precondition(carried == "aPlata", "Expected the word Plata to travel, got \(carried)")

        precondition(morphPairs(from: [], to: metal).isEmpty)
        precondition(morphPairs(from: metal, to: []).isEmpty)
        precondition(morphPairs(from: Array("   "), to: Array("   ")).isEmpty, "Blank names share nothing")
    }

    // MARK: Engines

    private static func checkEngines() {
        precondition(MorphStyle.allCases.first == .diff, "The diff engine is the default")
        precondition(MorphStyle.allCases.filter(\.usesPairing) == [.diff],
                     "Only the diff engine matches characters between names")

        for style in MorphStyle.allCases {
            precondition(!style.title.isEmpty && !style.source.isEmpty && !style.detail.isEmpty,
                         "\(style) needs a name, a source and a description")
            // The wave divides by 1 - spread, so a full-width wave would never finish.
            precondition(style.spread >= 0 && style.spread < 1, "\(style) has an unusable wave")

            atRest(style.leaving(0), "\(style) must start at rest")
            precondition(gone(style.leaving(1)), "\(style) must leave nothing behind")
            precondition(gone(style.arriving(0, seed: 0)), "\(style) must arrive from nothing")
            atRest(style.arriving(1, seed: 0), "\(style) must settle at rest")
            // Seeds are per character, so the resting frame has to ignore them.
            atRest(style.arriving(1, seed: 7), "\(style) must settle at rest for every character")
        }

        // None of the remaining engines draws anything other than the real character.
        for style in MorphStyle.allCases {
            for step in [0.25, 0.5, 0.75] {
                precondition(style.leaving(step).substitute == nil, "\(style) must not swap characters")
                precondition(style.arriving(step, seed: 3).substitute == nil,
                             "\(style) must not swap characters")
            }
        }
    }

    private static func atRest(_ look: GlyphAppearance, _ message: String) {
        precondition(close(look.opacity, 1), message + " (opacity)")
        precondition(close(look.scale, 1), message + " (scale)")
        precondition(close(look.dx, 0) && close(look.dy, 0), message + " (offset)")
        precondition(close(look.blur, 0), message + " (blur)")
        precondition(close(look.rotation, 0), message + " (rotation)")
        precondition(look.substitute == nil, message + " (character)")
    }

    private static func gone(_ look: GlyphAppearance) -> Bool { close(look.opacity, 0) }
    private static func close(_ value: Double, _ target: Double) -> Bool { abs(value - target) < 1e-9 }
}
