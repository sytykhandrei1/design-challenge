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

extension MorphAxis {
    var vector: (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch self {
        case .x: return (1, 0, 0)
        case .y: return (0, 1, 0)
        case .z: return (0, 0, 1)
        }
    }
}

/// Horizontal position of every character of a single-line string.
struct GlyphRun {
    let characters: [Character]
    /// One entry per character boundary, so it holds `characters.count + 1` values.
    private let offsets: [CGFloat]

    init(_ text: String, font: UIFont = MorphTypography.uiFont, tracking: CGFloat = 0) {
        characters = Array(text)
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .kern: tracking])
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

/// Everything the engines need for one transition, measured once when the text changes.
struct MorphPlan {
    struct Placed {
        let id: Int
        let character: Character
        let x: CGFloat
        /// Index in its own string; drives the left-to-right wave.
        let order: Int
    }

    struct Travelling {
        let id: Int
        let character: Character
        let fromX: CGFloat
        let toX: CGFloat
    }

    /// Characters shared by both names, used by the diff engine.
    let moved: [Travelling]
    let removed: [Placed]
    let inserted: [Placed]
    /// Every visible character of each name, used by every other engine.
    let outgoing: [Placed]
    let incoming: [Placed]
    let size: CGSize
    let fontSize: CGFloat
    let weight: UIFont.Weight

    init(from old: String, to new: String, fontSize: CGFloat = MorphTypography.size,
         tracking: CGFloat = 0, weight: UIFont.Weight = .bold, pairsCharacters: Bool = true) {
        self.fontSize = fontSize
        self.weight = weight
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let before = GlyphRun(old, font: font, tracking: tracking)
        let after = GlyphRun(new, font: font, tracking: tracking)
        let width = max(before.width, after.width)
        size = CGSize(width: width, height: font.lineHeight)
        // Both names stay centred in a box wide enough for either of them.
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
        for pair in pairsCharacters ? morphPairs(from: before.characters, to: after.characters) : [] {
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
            .enumerated().map { order, index in
                Placed(id: next(), character: before.characters[index],
                       x: beforeOrigin + before.center(of: index), order: order)
            }
        incoming = after.visibleIndices
            .enumerated().map { order, index in
                Placed(id: next(), character: after.characters[index],
                       x: afterOrigin + after.center(of: index), order: order)
            }
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
        Group {
            if style == .stagger || style == .diff {
                staggerCanvas
            } else {
                ZStack {
                    if style.usesPairing {
                        pairedGlyphs
                    } else {
                        replacedGlyphs
                    }
                }
            }
        }
        .frame(width: plan.size.width, height: plan.size.height)
    }

    /// Keep the reviewed per-character wave, but submit one drawing instead of
    /// rebuilding two trees of Text/blur/transform views on every animation frame.
    /// Symbols are laid out independently of `progress` and reused by Canvas.
    private var staggerCanvas: some View {
        Canvas { context, _ in
            // Canvas rasterizes to its own bounds. Leave room for the existing
            // ±10 pt stagger and blur rather than clipping moving ascenders.
            context.translateBy(x: 16, y: 24)
            if style.usesPairing {
                for item in plan.moved {
                    draw(.init(id: item.id, character: item.character,
                               x: lerp(item.fromX, item.toX, reduceMotion ? 1 : progress), order: 0),
                         look: GlyphAppearance(), in: context)
                }
                for item in plan.removed {
                    draw(item, look: style.leaving(clamp(progress / 0.4)), in: context)
                }
                for item in plan.inserted {
                    draw(item, look: style.arriving(clamp((progress - 0.3) / 0.7), seed: item.order), in: context)
                }
            } else {
                for item in plan.outgoing {
                    draw(item, look: style.leaving(wave(item.order, count: plan.outgoing.count)), in: context)
                }
                for item in plan.incoming {
                    draw(item, look: style.arriving(wave(item.order, count: plan.incoming.count), seed: item.order), in: context)
                }
            }
        } symbols: {
            ForEach(canvasSymbols, id: \.id) { item in
                Text(String(item.character))
                    .font(Font(UIFont.systemFont(ofSize: plan.fontSize, weight: plan.weight)))
                    .foregroundStyle(color)
                    .fixedSize()
                    .tag(item.id)
            }
        }
        .frame(width: plan.size.width + 32, height: plan.size.height + 48)
        .frame(width: plan.size.width, height: plan.size.height)
    }

    private var canvasSymbols: [MorphPlan.Placed] {
        if style.usesPairing {
            return plan.moved.map { .init(id: $0.id, character: $0.character, x: $0.toX, order: 0) }
                + plan.removed + plan.inserted
        }
        return plan.outgoing + plan.incoming
    }

    private func draw(_ item: MorphPlan.Placed, look: GlyphAppearance, in context: GraphicsContext) {
        let shown = calm(look)
        guard shown.opacity > 0, let symbol = context.resolveSymbol(id: item.id) else { return }
        var glyphContext = context
        glyphContext.opacity = shown.opacity
        glyphContext.translateBy(x: item.x + shown.dx, y: plan.size.height / 2 + shown.dy)
        glyphContext.scaleBy(x: shown.scale, y: shown.scale)
        if shown.blur > 0 { glyphContext.addFilter(.blur(radius: shown.blur)) }
        glyphContext.draw(symbol, at: .zero)
    }

    /// The diff engine: shared characters travel, and departures clear the way before arrivals
    /// land, with a short overlap in the middle.
    @ViewBuilder private var pairedGlyphs: some View {
        // Reduce Motion keeps the shared characters where they end up and only cross-fades.
        let travel = reduceMotion ? 1 : progress
        ForEach(plan.moved, id: \.id) { item in
            glyph(item.character, x: lerp(item.fromX, item.toX, travel), look: GlyphAppearance())
        }
        ForEach(plan.removed, id: \.id) { item in
            glyph(item.character, x: item.x, look: style.leaving(clamp(progress / 0.4)))
        }
        ForEach(plan.inserted, id: \.id) { item in
            glyph(item.character, x: item.x,
                  look: style.arriving(clamp((progress - 0.3) / 0.7), seed: item.order))
        }
    }

    /// Every other engine: the whole old name leaves and the whole new name arrives.
    @ViewBuilder private var replacedGlyphs: some View {
        ForEach(plan.outgoing, id: \.id) { item in
            glyph(item.character, x: item.x,
                  look: style.leaving(wave(item.order, count: plan.outgoing.count)))
        }
        ForEach(plan.incoming, id: \.id) { item in
            glyph(item.character, x: item.x,
                  look: style.arriving(wave(item.order, count: plan.incoming.count), seed: item.order))
        }
    }

    private func glyph(_ character: Character, x: CGFloat, look: GlyphAppearance) -> some View {
        let shown = calm(look)
        return Text(String(shown.substitute ?? character))
            .font(Font(UIFont.systemFont(ofSize: plan.fontSize, weight: plan.weight)))
            .foregroundStyle(color)
            .fixedSize()
            .scaleEffect(CGFloat(shown.scale))
            .rotation3DEffect(.degrees(shown.rotation), axis: shown.axis.vector)
            .blur(radius: CGFloat(shown.blur))
            .opacity(shown.opacity)
            .position(x: x + CGFloat(shown.dx), y: plan.size.height / 2 + CGFloat(shown.dy))
    }

    /// Reduce Motion drops every moving part of an effect and leaves the cross-fade.
    private func calm(_ look: GlyphAppearance) -> GlyphAppearance {
        guard reduceMotion else { return look }
        var quiet = look
        quiet.scale = 1
        quiet.dx = 0
        quiet.dy = 0
        quiet.blur = 0
        quiet.rotation = 0
        return quiet
    }

    /// Local progress of one character. The wave crosses the line over the first `spread` of the
    /// timeline, and every character still reaches 1 exactly when the transition ends.
    private func wave(_ order: Int, count: Int) -> Double {
        let spread = style.spread
        guard !reduceMotion, spread > 0, count > 1 else { return clamp(progress) }
        let start = spread * Double(order) / Double(count - 1)
        return clamp((progress - start) / (1 - spread))
    }

    private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
    private func lerp(_ from: CGFloat, _ to: CGFloat, _ amount: Double) -> CGFloat {
        from + (to - from) * CGFloat(amount)
    }
}

/// A title that animates from its previous value to the current one using the selected technique.
struct MorphingTitle: View {
    let text: String
    let style: MorphStyle
    let fontSize: CGFloat
    let tracking: CGFloat
    let color: Color
    let weight: UIFont.Weight
    let accessibilityID: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: String
    @State private var plan: MorphPlan?
    @State private var progress: Double
    @State private var generation = 0

    init(text: String, style: MorphStyle, fontSize: CGFloat = MorphTypography.size,
         tracking: CGFloat = 0, color: Color = Color("CardTitle"),
         weight: UIFont.Weight = .bold, accessibilityID: String = "morphTitle") {
        self.text = text
        self.style = style
        self.fontSize = fontSize
        self.tracking = tracking
        self.color = color
        self.weight = weight
        self.accessibilityID = accessibilityID
        _displayed = State(initialValue: text)
        // SwiftUI invokes this initializer for every parent drag update. Never
        // measure CoreText or compute an LCS in a State initialValue expression.
        _plan = State(initialValue: nil)
        _progress = State(initialValue: 1)
    }

    var body: some View {
        Group {
            if let plan {
                MorphStage(progress: progress, plan: plan, style: style,
                           reduceMotion: reduceMotion, color: color)
            } else {
                // Keep the presented value until onChange installs its plan;
                // otherwise the destination flashes for one frame before morphing.
                Text(displayed)
                    .font(Font(UIFont.systemFont(ofSize: fontSize, weight: weight)))
                    .tracking(tracking)
                    .foregroundStyle(color)
                    .fixedSize()
            }
        }
        .frame(height: UIFont.systemFont(ofSize: fontSize, weight: weight).lineHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier(accessibilityID)
        .onChange(of: text) { _, updated in retarget(to: updated) }
        .onChange(of: style) { _, _ in settle() }
    }

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.55, dampingFraction: 0.86)
    }

    /// Lays out the new transition at rest, then lets the animation system run it to completion.
    /// The two steps have to land in separate updates: the first one has to be visible on screen
    /// before the second can animate away from it.
    private func retarget(to updated: String) {
        generation += 1
        let revision = generation
        let next = MorphPlan(from: displayed, to: updated, fontSize: fontSize, tracking: tracking,
                             weight: weight, pairsCharacters: style.usesPairing)
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            plan = next
            displayed = updated
            progress = 0
        }
        DispatchQueue.main.async {
            guard revision == self.generation else { return }
            withAnimation(self.animation, completionCriteria: .removed) {
                self.progress = 1
            } completion: {
                // A rapid midpoint reversal must not let the previous animation
                // clear the newer plan. At rest only a native Text remains.
                guard revision == self.generation else { return }
                self.plan = nil
            }
        }
    }

    /// Switching technique is not a transition: show the current name at rest right away.
    private func settle() {
        generation += 1
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            plan = nil
            displayed = text
            progress = 1
        }
    }
}
