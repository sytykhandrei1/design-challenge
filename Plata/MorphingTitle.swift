import SwiftUI
import UIKit
import CoreText

/// One place to keep the display font and the font used to measure glyph positions in step.
/// `Font.system(size:weight:)` and `UIFont.systemFont(ofSize:weight:)` resolve to the same face at
/// a fixed point size, so measured offsets match what SwiftUI draws.
enum MorphTypography {
    static let size: CGFloat = 30
    static let uiFont = UIFont.systemFont(ofSize: size, weight: .bold)
    static let font = Font.system(size: size, weight: .bold)
    static var lineHeight: CGFloat { uiFont.lineHeight }
}

/// Horizontal position of every character of a single-line string.
struct GlyphRun {
    let characters: [Character]
    /// One entry per character boundary, so it holds `characters.count + 1` values.
    private let offsets: [CGFloat]

    init(_ text: String) {
        characters = Array(text)
        let attributed = NSAttributedString(string: text, attributes: [.font: MorphTypography.uiFont])
        let line = CTLineCreateWithAttributedString(attributed)
        // CoreText indexes UTF-16, which only matches character indices for plain ASCII.
        var boundaries = [0]
        var utf16 = 0
        for character in characters {
            utf16 += String(character).utf16.count
            boundaries.append(utf16)
        }
        offsets = boundaries.map { CTLineGetOffsetForStringIndex(line, $0, nil) }
    }

    var width: CGFloat { offsets.last ?? 0 }
    var visibleIndices: [Int] { characters.indices.filter { !characters[$0].isWhitespace } }
    func center(of index: Int) -> CGFloat { (offsets[index] + offsets[index + 1]) / 2 }
}

/// Everything both engines need for one transition, measured once when the text changes.
struct MorphPlan {
    struct Placed {
        let id: Int
        let character: Character
        let x: CGFloat
        /// Index in its own string; drives the left-to-right delay of the stagger engine.
        let order: Int
    }

    struct Travelling {
        let id: Int
        let character: Character
        let fromX: CGFloat
        let toX: CGFloat
    }

    /// Characters shared by both strings, used by the diff engine.
    let moved: [Travelling]
    let removed: [Placed]
    let inserted: [Placed]
    /// Every visible character of each string, used by the stagger engine.
    let outgoing: [Placed]
    let incoming: [Placed]
    let size: CGSize

    init(from old: String, to new: String) {
        let before = GlyphRun(old)
        let after = GlyphRun(new)
        let width = max(before.width, after.width)
        size = CGSize(width: width, height: MorphTypography.lineHeight)
        // Both strings stay centred in a box wide enough for either of them.
        let beforeOrigin = (width - before.width) / 2
        let afterOrigin = (width - after.width) / 2

        var identifier = 0
        func next() -> Int {
            identifier += 1
            return identifier
        }

        var pairedBefore = Set<Int>()
        var pairedAfter = Set<Int>()
        var travelling: [Travelling] = []
        for pair in morphPairs(from: before.characters, to: after.characters) {
            pairedBefore.insert(pair.from)
            pairedAfter.insert(pair.to)
            travelling.append(Travelling(id: next(),
                                         character: after.characters[pair.to],
                                         fromX: beforeOrigin + before.center(of: pair.from),
                                         toX: afterOrigin + after.center(of: pair.to)))
        }
        moved = travelling
        removed = before.visibleIndices
            .filter { !pairedBefore.contains($0) }
            .map { Placed(id: next(), character: before.characters[$0],
                          x: beforeOrigin + before.center(of: $0), order: $0) }
        inserted = after.visibleIndices
            .filter { !pairedAfter.contains($0) }
            .map { Placed(id: next(), character: after.characters[$0],
                          x: afterOrigin + after.center(of: $0), order: $0) }
        outgoing = before.visibleIndices
            .map { Placed(id: next(), character: before.characters[$0],
                          x: beforeOrigin + before.center(of: $0), order: $0) }
        incoming = after.visibleIndices
            .map { Placed(id: next(), character: after.characters[$0],
                          x: afterOrigin + after.center(of: $0), order: $0) }
    }
}

/// Draws one frame of a transition. Conforming to `Animatable` lets SwiftUI interpolate `progress`
/// itself, so the spring runs on the animation system and no display link or timer is needed.
struct MorphStage: View, Animatable {
    var progress: Double
    var plan: MorphPlan
    var style: MorphStyle
    var reduceMotion: Bool
    var color: Color

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ZStack {
            if style == .stagger {
                staggerGlyphs
            } else {
                diffGlyphs
            }
        }
        .frame(width: plan.size.width, height: plan.size.height)
    }

    // MARK: Diff

    @ViewBuilder private var diffGlyphs: some View {
        // Departures clear the way before arrivals land, with a short overlap in the middle.
        let leaving = clamp(progress / 0.4)
        let arriving = clamp((progress - 0.3) / 0.7)
        // Reduce Motion keeps the shared characters where they end up and only cross-fades.
        let travel = reduceMotion ? 1 : progress
        ForEach(plan.moved, id: \.id) { item in
            diffGlyph(item.character, x: lerp(item.fromX, item.toX, travel), opacity: 1, scale: 1)
        }
        ForEach(plan.removed, id: \.id) { item in
            diffGlyph(item.character, x: item.x,
                      opacity: 1 - leaving, scale: 1 - 0.22 * leaving * motion)
        }
        ForEach(plan.inserted, id: \.id) { item in
            diffGlyph(item.character, x: item.x,
                      opacity: arriving, scale: 1 - 0.22 * (1 - arriving) * motion)
        }
    }

    private func diffGlyph(_ character: Character, x: CGFloat, opacity: Double, scale: Double) -> some View {
        Text(String(character))
            .font(MorphTypography.font)
            .foregroundStyle(color)
            .fixedSize()
            .scaleEffect(CGFloat(scale))
            .opacity(opacity)
            .position(x: x, y: plan.size.height / 2)
    }

    // MARK: Stagger

    @ViewBuilder private var staggerGlyphs: some View {
        ForEach(plan.outgoing, id: \.id) { item in
            let step = staggered(item.order, count: plan.outgoing.count)
            staggerGlyph(item.character, x: item.x, opacity: 1 - step,
                         scale: 1 - 0.1 * step * motion,
                         blur: 3 * step * motion, dy: -10 * step * motion)
        }
        ForEach(plan.incoming, id: \.id) { item in
            let step = staggered(item.order, count: plan.incoming.count)
            staggerGlyph(item.character, x: item.x, opacity: step,
                         scale: 1 - 0.1 * (1 - step) * motion,
                         blur: 3 * (1 - step) * motion, dy: 10 * (1 - step) * motion)
        }
    }

    private func staggerGlyph(_ character: Character, x: CGFloat, opacity: Double,
                              scale: Double, blur: Double, dy: Double) -> some View {
        Text(String(character))
            .font(MorphTypography.font)
            .foregroundStyle(color)
            .fixedSize()
            .scaleEffect(CGFloat(scale))
            .blur(radius: CGFloat(blur))
            .opacity(opacity)
            .position(x: x, y: plan.size.height / 2 + CGFloat(dy))
    }

    /// Local progress of one character: the wave crosses the line over the first half of the
    /// timeline, and every character still reaches 1 exactly when the transition ends.
    private func staggered(_ order: Int, count: Int) -> Double {
        guard !reduceMotion, count > 1 else { return clamp(progress) }
        let spread = 0.5
        let start = spread * Double(order) / Double(count - 1)
        return clamp((progress - start) / (1 - spread))
    }

    // MARK: Helpers

    /// Scales the decorative part of each effect down to nothing under Reduce Motion.
    private var motion: Double { reduceMotion ? 0 : 1 }
    private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
    private func lerp(_ from: CGFloat, _ to: CGFloat, _ amount: Double) -> CGFloat {
        from + (to - from) * CGFloat(amount)
    }
}

/// A title that animates from its previous value to the current one using the selected technique.
struct MorphingTitle: View {
    let text: String
    let style: MorphStyle
    var identifier = "morphTitle"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: String
    @State private var plan: MorphPlan
    @State private var progress: Double

    init(text: String, style: MorphStyle, identifier: String = "morphTitle") {
        self.text = text
        self.style = style
        self.identifier = identifier
        _displayed = State(initialValue: text)
        _plan = State(initialValue: MorphPlan(from: text, to: text))
        _progress = State(initialValue: 1)
    }

    var body: some View {
        content
            .frame(height: MorphTypography.lineHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityIdentifier(identifier)
            .onChange(of: text) { _, updated in retarget(to: updated) }
            .onChange(of: style) { _, _ in settle() }
    }

    @ViewBuilder private var content: some View {
        if style == .native {
            Text(text)
                .font(MorphTypography.font)
                .foregroundStyle(Color("CardTitle"))
                .contentTransition(.interpolate)
                .animation(animation, value: text)
        } else {
            MorphStage(progress: progress, plan: plan, style: style,
                       reduceMotion: reduceMotion, color: Color("CardTitle"))
        }
    }

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.55, dampingFraction: 0.86)
    }

    /// Lays out the new transition at rest, then lets the animation system run it to completion.
    /// The two steps have to land in separate updates: the first one has to be visible on screen
    /// before the second can animate away from it.
    private func retarget(to updated: String) {
        let next = MorphPlan(from: displayed, to: updated)
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            plan = next
            displayed = updated
            progress = 0
        }
        DispatchQueue.main.async {
            withAnimation(self.animation) { self.progress = 1 }
        }
    }

    /// Switching technique is not a transition: show the current text at rest right away.
    private func settle() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            plan = MorphPlan(from: text, to: text)
            displayed = text
            progress = 1
        }
    }
}
