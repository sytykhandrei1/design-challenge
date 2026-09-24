import SwiftUI
import UIKit
import Combine

struct CardOrderingView: View {
    var kind: CardOrderKind = .physical
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var preview = false
    @State private var previewOffset: CGFloat = 0
    @State private var lastPreviewDragDistance: CGFloat = 0
    @State private var peakPreviewZoom: Double = 1
    @State private var selected = 0
    @State private var finishes: [CardCategory: Int] = [:]
    @State private var typePosition: CGFloat = 0
    @State private var typeSession: CardSelectionDrag?
    @GestureState private var typeContact = false
    @State private var hapticCount = 0
    @State private var selectionFeedback = UIImpactFeedbackGenerator(style: .light)

    private var categories: [CardCategory] { kind.categories }
    private var category: CardCategory { categories[selected] }
    private var selectedDesign: CardDesign { category.design(finish: finishes[category, default: 0]) }
    private var transition: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.62, dampingFraction: 0.84)
    }
    private var previewTransition: Animation {
        reduceMotion ? .easeOut(duration: 0.16)
            : .timingCurve(0.22, 0, 0.18, 1, duration: CardPhysics.previewEntranceDuration)
    }

    var body: some View {
        galleryScrollView
        .modifier(CardGalleryActionBar {
            Button {} label: {
                CardGalleryAction()
            }
            .buttonStyle(CardGalleryDisplayOnlyButtonStyle())
            .disabled(true)
            .accessibilityLabel(category.action)
            .accessibilityIdentifier("bottomAction")
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .allowsHitTesting(false)
        })
        .background(Color("ModalBackground").ignoresSafeArea())
        .navigationTitle(preview ? "Card preview" : "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(preview)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if preview {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: closePreview) { Image(systemName: "chevron.left") }
                        .tint(.primary)
                        .accessibilityLabel("Back to designs")
                }
            }
        }
        .softNavigationScrollEdge()
        .onChange(of: typeContact) { _, touching in
            if !touching {
                // GestureState can reset before onEnded. Let release projection
                // commit first; this fallback only settles cancelled gestures.
                DispatchQueue.main.async { if !typeContact { finishTypeDrag() } }
            }
        }
    }

    private var galleryScrollView: some View {
      ScrollView(.vertical) {
        GeometryReader { geometry in
            // Native navigation transitions can briefly propose negative space.
            let width = max(0, geometry.size.width)
            // The native bottom bar reserves 84 pt. Keep the reviewed gallery
            // coordinates in the old full safe-area space, not the smaller
            // scroll viewport; the 25% dismissal boundary also stays unchanged.
            let height = max(0, geometry.size.height) / 3 + 84
            let cardWidth = max(width - 56, 1)
            let referenceCardHeight = cardWidth * 211 / 346
            let cardHeight = cardWidth * CGFloat(PlataMetalV1Geometry.height / PlataMetalV1Geometry.width)
            // Both physical collections use the same undistorted ID-1 geometry.
            // Keep the real edge-to-edge gap at 16 pt, including the next-card peek.
            let metalWidth = min(cardWidth, cardHeight * CGFloat(PlataMetalV1Geometry.width / PlataMetalV1Geometry.height))
            let typeStep = metalWidth + 16
            let bottomPadding: CGFloat = 20
            let viewportHeight = max(height - 56 - bottomPadding - 8, 1)
            let expandedWidth = max(1, min(viewportHeight - 78, (width - 92) * 1.72))
            let expandedHeight = expandedWidth / 1.72
            // Figma 5274:41141: hero centre 383.5, info top 501,
            // hint centre 249, colour centre 680 on the 402 × 874 canvas.
            // Keep the physical ID-1 model undistorted at the reference width.
            let galleryCenterY = max(cardHeight / 2 + 28, 267.5 + (height - 724) / 2)
            let centerY = preview ? viewportHeight * 0.48 : galleryCenterY

            ZStack(alignment: .topLeading) {
                cardStage(width: width, viewportHeight: viewportHeight,
                          cardWidth: cardWidth, cardHeight: cardHeight, typeStep: typeStep,
                          expandedWidth: expandedWidth, expandedHeight: expandedHeight,
                          centerY: centerY)
                    .frame(width: width, height: viewportHeight)

                HStack(spacing: 4) {
                    Image(systemName: "hand.tap")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 16, height: 18)
                    Text("Tap for a closer look")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(LinearGradient(stops: [
                    .init(color: Color(red: 145 / 255, green: 148 / 255, blue: 154 / 255), location: 0),
                    .init(color: Color(red: 145 / 255, green: 148 / 255, blue: 154 / 255).opacity(0.42), location: 0.46875),
                    .init(color: Color(red: 145 / 255, green: 148 / 255, blue: 154 / 255), location: 1)
                ], startPoint: .leading, endPoint: UnitPoint(x: 1.0388, y: 0.5)))
                .fixedSize()
                .position(x: width / 2, y: galleryCenterY - referenceCardHeight / 2 - 29)
                .opacity(preview ? 0 : 1)
                .accessibilityIdentifier("galleryPreviewHint")
                .accessibilityHidden(preview)
                .allowsHitTesting(false)

                VStack(spacing: 8) {
                    MorphingTitle(text: selectedDesign.galleryTitle, style: .stagger, fontSize: 24,
                                  tracking: 0.36, color: Color(white: 0.2))
                        .accessibilityAddTraits(.isHeader)
                    MorphingTitle(text: category.subtitle(finish: finishes[category, default: 0]),
                                  style: .stagger,
                                  fontSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
                                  color: Color(white: 0.2), weight: .regular,
                                  accessibilityID: "galleryDescription")
                }
                .frame(width: max(0, min(width - 32, 343)))
                .padding(.vertical, 12)
                .fixedSize()
                .frame(width: width, alignment: .top)
                .offset(y: galleryCenterY + referenceCardHeight / 2 + 12)
                .opacity(preview ? 0 : 1)
                .accessibilityHidden(preview)
                .allowsHitTesting(false)

                CardColorRail(category: category, selection: Binding(
                    get: { finishes[category, default: 0] },
                    set: { selectFinish($0) }
                ))
                .frame(width: width, height: 64)
                .offset(y: height - 160 - 32)
                .opacity(preview ? 0 : 1)
                .allowsHitTesting(!preview)
                .accessibilityHidden(preview)

            }
            .frame(width: width, height: viewportHeight, alignment: .topLeading)
            .coordinateSpace(name: "cardGallery")
            // The real scroll content includes an equal overscan region at
            // both ends. Native edge effects otherwise treat this stationary
            // canvas as already at BOTH content ends and disappear on zoom.
            .padding(.vertical, viewportHeight)
        }
        .containerRelativeFrame(.horizontal)
        .containerRelativeFrame(.vertical) { viewport, _ in viewport * 3 }
      }
      // The scroll view itself fills the hosting controller, underneath its
      // native bars. Card gestures own movement; no extra scroll pan is added.
      .scrollDisabled(true)
      .defaultScrollAnchor(.center)
      .scrollIndicators(.hidden)
      .scrollClipDisabled()
    }

    private func cardStage(width: CGFloat, viewportHeight: CGFloat, cardWidth: CGFloat,
                           cardHeight: CGFloat, typeStep: CGFloat, expandedWidth: CGFloat,
                           expandedHeight: CGFloat, centerY: CGFloat) -> some View {
        ZStack {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, item in
                let active = index == selected
                MetalCard(design: item.design(finish: finishes[item, default: 0]),
                          // Keep both physical pages prepared while the gallery
                          // is visible. Crossing the midpoint must not destroy
                          // and rebuild the plastic scene on every reversal.
                          interactive: preview && active, prepareForInteraction: true,
                          quarterTurned: preview && active,
                          animatePreviewEntrance: !reduceMotion,
                          onPreviewDrag: preview && active ? { event in
                    handlePreviewDrag(event, cardHeight: item.design(finish: finishes[item, default: 0]).usesRealityKit
                                      ? min(expandedWidth, expandedHeight * CGFloat(PlataMetalV1Geometry.width / PlataMetalV1Geometry.height))
                                      : expandedWidth,
                                      centerY: centerY, viewportHeight: viewportHeight)
                } : nil,
                          onPreviewZoomEnd: gestureProbeEnabled && preview && active ? { peak in
                    peakPreviewZoom = peak
                } : nil)
                .frame(width: preview && active ? expandedWidth : cardWidth,
                       height: preview && active ? expandedHeight : cardHeight)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(preview ? "\(item.title) card preview"
                                    : kind == .digital ? "Digital card"
                                    : "\(item.title), type \(index + 1) of \(categories.count)")
                .accessibilityIdentifier(active ? "activeCard" : "card\(index)")
                .accessibilityValue(Text(gestureProbeValue))
                .accessibilityHidden(preview && !active)
                .accessibilityAddTraits(preview ? [] : .isButton)
                .accessibilityAction { if !preview { open(index) } }
                .accessibilityActions {
                    if !preview && kind == .physical {
                        Button("Next card type") { select(min(selected + 1, categories.count - 1)) }
                        Button("Previous card type") { select(max(selected - 1, 0)) }
                    }
                }
                .gesture(TapGesture().onEnded { open(index) }, including: preview ? .subviews : .all)
                // The type gesture belongs only to the card, never the color rail.
                .simultaneousGesture(typeDrag(step: typeStep), including: preview ? .subviews : .all)
                .rotationEffect(.degrees(preview && active ? 90 : 0))
                .position(x: width / 2 + (CGFloat(index) - (preview ? CGFloat(selected) : typePosition)) * typeStep,
                          y: centerY + (preview && active ? previewOffset : 0))
                .opacity(preview && !active ? 0 : 1)
                .zIndex(active ? 1 : 0)
                .allowsHitTesting(!preview || active)
            }
        }
    }

    private func typeDrag(step: CGFloat) -> some Gesture {
        // Measure in the stationary viewport, not the moving card's local space.
        DragGesture(minimumDistance: 12, coordinateSpace: .named("cardGallery"))
            .updating($typeContact) { _, state, _ in state = true }
            .onChanged { value in
                guard !preview, kind == .physical,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                var session = typeSession ?? CardSelectionDrag()
                if typeSession == nil {
                    session.begin(selection: selected, at: value.time.timeIntervalSinceReferenceDate)
                    selectionFeedback.prepare()
                }
                let crossings = session.update(translation: -value.translation.width,
                                               step: CardTypePaging.dragStep(step), count: categories.count,
                                               at: value.time.timeIntervalSinceReferenceDate)
                typeSession = session
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { typePosition = session.position }
                for next in crossings { selected = next; selectionHaptic() }
            }
            .onEnded { value in
                if let session = typeSession {
                    let next = CardTypePaging.releaseSelection(
                        position: session.position, selection: selected,
                        translation: -value.translation.width,
                        predictedExtra: -(value.predictedEndTranslation.width - value.translation.width),
                        pageWidth: step, count: categories.count)
                    if next != selected { selected = next; selectionHaptic() }
                }
                finishTypeDrag()
            }
    }

    private func finishTypeDrag() {
        guard typeSession != nil else { return }
        typeSession = nil
        withAnimation(.easeOut(duration: reduceMotion ? 0.16 : 0.22)) {
            typePosition = CGFloat(selected)
        }
    }

    private func select(_ index: Int) {
        guard index != selected else { return }
        selectionHaptic()
        withAnimation(transition) { selected = index; typePosition = CGFloat(index) }
    }

    private func selectFinish(_ index: Int) {
        guard index != finishes[category, default: 0] else { return }
        finishes[category] = index
        selectionHaptic()
    }

    private func selectionHaptic() {
        selectionFeedback.impactOccurred(intensity: 1.0)
        selectionFeedback.prepare()
        if gestureProbeEnabled { hapticCount += 1 }
    }

    private func open(_ index: Int) {
        guard !preview else { return }
        if index != selected { select(index) }
        peakPreviewZoom = 1
        withAnimation(previewTransition) { preview = true }
    }

    private func closePreview() {
        selectionHaptic()
        withAnimation(previewTransition) { previewOffset = 0; preview = false }
    }

    private func handlePreviewDrag(_ event: CardPreviewDragEvent, cardHeight: CGFloat,
                                   centerY: CGFloat, viewportHeight: CGFloat) {
        guard preview else { return }
        switch event {
        case .changed(let offset):
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { previewOffset = offset }
        case .ended(let offset, let cancelled):
            if gestureProbeEnabled { lastPreviewDragDistance = offset }
            if !cancelled && CardPreviewDrag.shouldDismiss(translation: offset, cardHeight: cardHeight,
                                                           centerY: centerY, viewportHeight: viewportHeight) {
                closePreview()
            } else {
                withAnimation(reduceMotion ? .easeOut(duration: 0.16)
                              : .spring(response: 0.48, dampingFraction: 0.73)) { previewOffset = 0 }
            }
        }
    }

    private var gestureProbeEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--card-gesture-probe")
        #else
        false
        #endif
    }
    private var gestureProbeValue: String {
        gestureProbeEnabled ? "\(Int(lastPreviewDragDistance))|haptics:\(hapticCount)|zoom:\(peakPreviewZoom)" : ""
    }
}

private struct CardGalleryActionBar<Bar: View>: ViewModifier {
    @ViewBuilder var bar: Bar

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .bottom, spacing: 0) { bar }
                .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) { bar }
        }
    }
}

/// UIScrollView lays out the content; a non-inertial pan owns selection.
/// Only the circles scroll; the selection ring is a sibling, not scroll content.
private struct CardColorRail: UIViewRepresentable {
    var category: CardCategory
    @Binding var selection: Int

    func makeUIView(context: Context) -> CardColorRailView { CardColorRailView() }
    func updateUIView(_ view: CardColorRailView, context: Context) {
        view.configure(category: category, selection: selection) { selection = $0 }
    }
}

private final class CardColorRailView: UIView, UIScrollViewDelegate {
    private let scroll = UIScrollView()
    private let ring = CardColorSelectionRing()
    private var buttons: [UIButton] = []
    private var category: CardCategory?
    private var selected = 0
    private var onSelection: ((Int) -> Void)?
    private var configuring = false
    private var scrollingToColor = false
    private var lastWidth: CGFloat = 0
    private var dragSession = CardSelectionDrag()
    private var finishPan: CardColorPanGesture!
    private var paletteAnimator: UIViewPropertyAnimator?
    private var dissolveHost: UIHostingController<PaletteDissolveView>?
    private var paletteRevision = 0
    private var changingPalette = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "colorPicker"
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.decelerationRate = .fast
        scroll.alwaysBounceHorizontal = true
        scroll.delegate = self
        scroll.panGestureRecognizer.isEnabled = false
        finishPan = CardColorPanGesture(target: self, action: #selector(dragColors(_:)))
        finishPan.maximumNumberOfTouches = 1
        scroll.addGestureRecognizer(finishPan)
        addSubview(scroll)
        ring.layer.borderWidth = 1
        ring.layer.borderColor = UIColor(red: 0x86 / 255.0, green: 0x89 / 255.0,
                                         blue: 0x8F / 255.0, alpha: 1).cgColor
        ring.layer.cornerRadius = 24
        ring.isUserInteractionEnabled = false
        ring.isAccessibilityElement = true
        ring.accessibilityLabel = "Selected color"
        ring.accessibilityIdentifier = "colorSelectionFrame"
        ring.accessibilityTraits = [.adjustable]
        ring.adjust = { [weak self] step in
            guard let self else { return }
            move(to: min(max(selected + step, 0), buttons.count - 1))
        }
        addSubview(ring)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(category: CardCategory, selection: Int, onSelection: @escaping (Int) -> Void) {
        self.onSelection = onSelection
        if self.category != category {
            settlePalette()
            let oldSelection = selected
            let oldButtons = buttons
            let oldColors = oldButtons.map { $0.backgroundColor ?? .clear }
            let oldCenters = oldButtons.map { $0.convert(CGPoint(x: 20, y: 20), to: self) }
            let animate = self.category != nil && bounds.width > 0
            configuring = true
            scroll.setContentOffset(scroll.contentOffset, animated: false)
            scrollingToColor = false
            finishPan.isEnabled = false
            finishPan.isEnabled = true
            self.category = category
            selected = selection
            // Match slots relative to the fixed selection ring, not color names.
            // Shared slots keep their actual UIButton and animate only its color.
            var reused = Set<Int>()
            var incoming = Set<Int>()
            buttons = category.colors.enumerated().map { index, finish in
                let previous = index - selection + oldSelection
                let button: UIButton
                if oldButtons.indices.contains(previous) {
                    button = oldButtons[previous]
                    reused.insert(previous)
                } else {
                    button = CardColorButton(type: .custom)
                    button.backgroundColor = finish.uiColor
                    button.layer.cornerRadius = 20
                    button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
                    scroll.addSubview(button)
                    incoming.insert(index)
                }
                button.tag = index
                button.accessibilityIdentifier = "cardColor\(index)"
                button.accessibilityLabel = "\(category.title) \(finish.name)"
                return button
            }
            var dissolves: [PaletteDissolveItem] = []
            for index in oldButtons.indices where !reused.contains(index) {
                if animate {
                    dissolves.append(.init(id: index, center: oldCenters[index],
                                           color: oldColors[index], entering: false))
                }
                oldButtons[index].removeFromSuperview()
            }
            lastWidth = 0
            configuring = false
            setNeedsLayout()
            layoutIfNeeded()
            if animate {
                for index in incoming {
                    let button = buttons[index]
                    dissolves.append(.init(id: oldButtons.count + index,
                        center: button.convert(CGPoint(x: 20, y: 20), to: self),
                        color: category.colors[index].uiColor, entering: true))
                    button.alpha = 0
                }
                animatePalette(dissolves: dissolves)
            } else {
                for (button, finish) in zip(buttons, category.colors) {
                    button.backgroundColor = finish.uiColor
                }
            }
        } else if selection != selected && !scroll.isTracking && !scroll.isDecelerating && !scrollingToColor {
            selected = selection
            resetOffset()
        }
        updateAccessibility()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configuring = true
        scroll.frame = bounds
        scroll.contentInset = UIEdgeInsets(top: 0, left: bounds.width / 2 - 20,
                                          bottom: 0, right: bounds.width / 2 - 20)
        scroll.contentSize = CGSize(width: CGFloat(max(buttons.count - 1, 0)) * CardColorRailMetrics.step + 40,
                                    height: bounds.height)
        for (index, button) in buttons.enumerated() {
            if !changingPalette { button.transform = .identity }
            button.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
            button.center = CGPoint(x: CGFloat(index) * CardColorRailMetrics.step + 20, y: bounds.height / 2)
        }
        ring.frame = CGRect(x: (bounds.width - 48) / 2, y: (bounds.height - 48) / 2, width: 48, height: 48)
        if lastWidth != bounds.width {
            lastWidth = bounds.width
            resetOffset()
        }
        updateCircleSpacing()
        configuring = false
    }

    private func resetOffset() {
        scroll.setContentOffset(CGPoint(x: CardColorRailMetrics.offset(index: selected, width: bounds.width), y: 0),
                                animated: false)
    }

    private func move(to index: Int) {
        guard buttons.indices.contains(index) else { return }
        settlePalette()
        scrollingToColor = true
        scroll.setContentOffset(CGPoint(x: CardColorRailMetrics.offset(index: index, width: bounds.width), y: 0),
                                animated: !UIAccessibility.isReduceMotionEnabled)
        if UIAccessibility.isReduceMotionEnabled { scrollingToColor = false }
    }

    @objc private func dragColors(_ gesture: CardColorPanGesture) {
        if gesture.state == .began {
            settlePalette()
            scroll.setContentOffset(scroll.contentOffset, animated: false)
            scrollingToColor = false
            resetOffset()
            dragSession.begin(selection: selected, at: gesture.contactStartTime)
        }
        if gesture.state == .began || gesture.state == .changed || gesture.state == .ended {
            let crossings = dragSession.update(translation: -gesture.fullTranslation.x,
                                               step: CardColorRailMetrics.step,
                                               count: buttons.count, at: CACurrentMediaTime())
            configuring = true
            scroll.contentOffset.x = dragSession.position * CardColorRailMetrics.step - (bounds.width / 2 - 20)
            configuring = false
            updateCircleSpacing()
            for next in crossings {
                selected = next
                updateAccessibility()
                onSelection?(next)
            }
        }
        if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            move(to: selected)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCircleSpacing()
        guard !configuring, scrollingToColor, bounds.width > 0 else { return }
        let next = CardColorRailMetrics.selection(offset: scroll.contentOffset.x,
                                                 width: bounds.width, count: buttons.count)
        guard selected != next else { return }
        selected = next
        updateAccessibility()
        onSelection?(next)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { scrollingToColor = false }

    private func updateCircleSpacing() {
        guard !changingPalette else { return }
        let center = scroll.contentOffset.x + bounds.width / 2
        for (index, button) in buttons.enumerated() {
            let distance = CGFloat(index) * CardColorRailMetrics.step + 20 - center
            button.transform = CGAffineTransform(translationX: CardColorRailMetrics.clearance(distance: distance), y: 0)
        }
    }

    @objc private func colorTapped(_ button: UIButton) { move(to: button.tag) }

    private func animatePalette(dissolves: [PaletteDissolveItem]) {
        guard let category else { return }
        paletteRevision += 1
        let revision = paletteRevision
        let calm = UIAccessibility.isReduceMotionEnabled
        let duration = calm ? 0.16 : 0.28
        let state = PaletteDissolveState()
        if !dissolves.isEmpty {
            let host = UIHostingController(rootView: PaletteDissolveView(state: state, items: dissolves, calm: calm))
            host.view.backgroundColor = .clear
            host.view.isUserInteractionEnabled = false
            host.view.accessibilityElementsHidden = true
            host.view.frame = bounds
            insertSubview(host.view, belowSubview: ring)
            host.view.layoutIfNeeded()
            dissolveHost = host
        }
        changingPalette = true
        let colors = category.colors.map(\.uiColor)
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeInOut)
        animator.addAnimations { [weak self] in
            guard let self else { return }
            for (button, color) in zip(buttons, colors) { button.backgroundColor = color }
        }
        animator.addCompletion { [weak self] _ in
            guard let self, paletteRevision == revision else { return }
            dissolveHost?.view.removeFromSuperview()
            dissolveHost = nil
            paletteAnimator = nil
            changingPalette = false
            for button in buttons { button.alpha = 1 }
            updateCircleSpacing()
        }
        paletteAnimator = animator
        animator.startAnimation()
        withAnimation(.easeInOut(duration: duration)) { state.progress = 1 }
    }

    /// A new color gesture takes priority over the cosmetic type transition.
    private func settlePalette() {
        guard paletteAnimator != nil else { return }
        paletteRevision += 1
        paletteAnimator?.stopAnimation(false)
        paletteAnimator?.finishAnimation(at: .end)
        paletteAnimator = nil
        dissolveHost?.view.removeFromSuperview()
        dissolveHost = nil
        changingPalette = false
        for button in buttons { button.alpha = 1 }
        updateCircleSpacing()
    }

    private func updateAccessibility() {
        guard let category else { return }
        ring.accessibilityValue = "\(category.colors[selected].name), \(selected + 1) of \(buttons.count)"
        for (index, button) in buttons.enumerated() {
            button.accessibilityTraits = index == selected ? [.button, .selected] : [.button]
        }
    }
}

private struct PaletteDissolveItem: Identifiable {
    let id: Int
    let center: CGPoint
    let color: UIColor
    let entering: Bool
}

private final class PaletteDissolveState: ObservableObject {
    @Published var progress: CGFloat = 0
}

/// Native SwiftUI blur is confined to the few surplus 40pt circles.
/// Shared colors stay in UIKit; the card rendering never enters an offscreen blur.
private struct PaletteDissolveView: View {
    @ObservedObject var state: PaletteDissolveState
    let items: [PaletteDissolveItem]
    let calm: Bool

    var body: some View {
        ZStack {
            ForEach(items) { item in
                let visible = item.entering ? state.progress : 1 - state.progress
                Circle()
                    .fill(Color(uiColor: item.color))
                    .frame(width: 40, height: 40)
                    .blur(radius: calm ? 0 : (1 - visible) * 8)
                    .opacity(visible)
                    .position(item.center)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// UIPan's translation begins after its recognition slop. Keep the full physical
/// touch path so the visual midpoint is precisely half of the 52 pt stop distance.
private final class CardColorPanGesture: UIPanGestureRecognizer {
    private var origin = CGPoint.zero
    private(set) var fullTranslation = CGPoint.zero
    private(set) var contactStartTime: Double = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first {
            origin = touch.location(in: view?.window)
            fullTranslation = .zero
            contactStartTime = touch.timestamp
        }
        super.touchesBegan(touches, with: event)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        update(touches)
        super.touchesMoved(touches, with: event)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        update(touches)
        super.touchesEnded(touches, with: event)
    }
    private func update(_ touches: Set<UITouch>) {
        guard let point = touches.first?.location(in: view?.window) else { return }
        fullTranslation = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
    }
}

private final class CardColorSelectionRing: UIView {
    var adjust: ((Int) -> Void)?
    override var accessibilityValue: String? {
        get {
            let value = super.accessibilityValue
            guard PlataPlasticDiagnostics.enabled else { return value }
            return (value ?? "") + "; " + PlataPlasticCardMaterial.diagnosticSummary
        }
        set { super.accessibilityValue = newValue }
    }
    override func accessibilityIncrement() { adjust?(1) }
    override func accessibilityDecrement() { adjust?(-1) }
}

private final class CardColorButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -2, dy: -2).contains(point)
    }
}

/// Keep the reviewed artwork unchanged while exposing disabled semantics.
private struct CardGalleryDisplayOnlyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

private struct CardGalleryAction: View {
    var body: some View {
        Text("Choose this design")
        .font(.body.weight(.medium))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color("AccentColor"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .circular))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}
