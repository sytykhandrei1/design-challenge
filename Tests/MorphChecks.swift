import Foundation

@main
struct MorphChecks {
    static func main() {
        let titles = CardTitles.all
        precondition(titles == ["Sand dunes", "Classic Plata", "Metal Plata", "Beautiful nature"])

        // A string morphing into itself keeps every visible character; spaces never pair.
        let visible = [9, 12, 10, 15]
        for (slot, title) in titles.enumerated() {
            let characters = Array(title)
            let pairs = morphPairs(from: characters, to: characters)
            precondition(pairs.count == visible[slot], "Identity morph must keep every glyph")
            precondition(pairs.allSatisfy { $0.from == $0.to }, "Identity morph must not move glyphs")
        }

        // Shared characters found between every ordered pair of names.
        let expected: [[Int]] = [[0, 2, 1, 4], [2, 0, 6, 5], [1, 6, 0, 5], [4, 5, 5, 0]]
        for (from, old) in titles.enumerated() {
            for (to, new) in titles.enumerated() where from != to {
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
        precondition(morphPairs(from: Array("   "), to: Array("   ")).isEmpty, "Blank strings share nothing")

        print("PASS: identity, reading order, glyph equality, whitespace, word survival, empty input")
    }
}
