import SwiftUI

struct CardOrderingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var preview = false
    @State private var selected = 2
    @GestureState private var drag: CGFloat = 0
    // The provided Figma uses the same artwork in each carousel slot.
    private let designs = Array(0..<5)
    private var transition: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.62, dampingFraction: 0.84)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let cardWidth = width - 52
                let cardHeight = cardWidth * 187 / 323
                let stride = cardWidth + 12
                let expandedWidth = min(height - 38, (width - 64) * 484 / 309)
                let expandedHeight = expandedWidth * 309 / 484
                let centerY = preview ? height / 2 : height * 0.35

                ZStack {
                    ForEach(designs, id: \.self) { index in
                        let active = index == selected
                        MetalCard(interactive: preview && active, prepareForInteraction: active)
                            .frame(width: preview && active ? expandedWidth : cardWidth,
                                   height: preview && active ? expandedHeight : cardHeight)
                            .contentShape(Rectangle())
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(preview ? "Metal card preview" : "Sand dunes, design \(index + 1) of 5")
                            .accessibilityIdentifier(active ? "activeCard" : "card\(index)")
                            .accessibilityHidden(preview && !active)
                            .accessibilityAddTraits(preview ? [] : .isButton)
                            .accessibilityAction { if !preview { open(index) } }
                            .gesture(TapGesture().onEnded { open(index) }, including: preview ? .subviews : .all)
                            .rotationEffect(.degrees(preview && active ? 90 : 0))
                            .position(x: width / 2 + CGFloat(index - selected) * stride + (preview ? 0 : drag),
                                      y: centerY)
                            .opacity(preview && !active ? 0 : 1)
                            .zIndex(active ? 1 : 0)
                            .allowsHitTesting(!preview || active)
                    }

                    VStack(spacing: 18) {
                        Text("Sand dunes")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Color("CardTitle"))
                        Button { open(selected) } label: {
                            HStack(spacing: 3) {
                                Image("settings").resizable().frame(width: 12, height: 12)
                                Text("Set up card").font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color("SetupBadge"), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .position(x: width / 2, y: centerY + cardHeight / 2 + 68)
                    .opacity(preview ? 0 : 1)
                    .allowsHitTesting(!preview)
                    .accessibilityHidden(preview)

                    HStack(spacing: 7) {
                        ForEach(designs, id: \.self) { index in
                            Circle().fill(index == selected ? Color.primary : Color.secondary.opacity(0.24))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .position(x: width / 2, y: height - 24)
                    .opacity(preview ? 0 : 1)
                    .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .updating($drag) { value, state, _ in
                            guard !preview else { return }
                            let x = value.translation.width
                            state = (selected == 0 && x > 0) || (selected == designs.count - 1 && x < 0) ? x * 0.25 : x
                        }
                        .onEnded { value in
                            guard !preview else { return }
                            let projected = value.predictedEndTranslation.width
                            let step = projected < -55 ? 1 : projected > 55 ? -1 : 0
                            withAnimation(transition) {
                                selected = min(max(selected + step, 0), designs.count - 1)
                            }
                        }, including: preview ? .subviews : .all
                )
                .animation(transition, value: drag == 0)
                .accessibilityAdjustableAction { direction in
                    guard !preview else { return }
                    withAnimation(transition) {
                        if direction == .increment { selected = min(selected + 1, designs.count - 1) }
                        if direction == .decrement { selected = max(selected - 1, 0) }
                    }
                }
            }
            .clipped()
            .background(Color("ModalBackground"))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    if preview { closePreview() }
                    // Ordering is intentionally a no-op in this prototype.
                } label: {
                    Text(preview ? "Back to designs" : "Order for 799 ₽")
                        .font(.system(size: 17, weight: .medium))
                        .contentTransition(.interpolate)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .foregroundStyle(.white)
                        .background(.black, in: RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bottomAction")
                .padding(.horizontal, 20).padding(.bottom, 20).padding(.top, 8)
                .background(Color("ModalBackground"))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(preview ? "Card preview" : "Plastic card")
                        .font(.system(size: 20, weight: .semibold))
                        .contentTransition(.interpolate)
                        .animation(transition, value: preview)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if preview { closePreview() } else { dismiss() }
                    } label: { Image(systemName: "chevron.left") }
                    .tint(.primary)
                    .accessibilityLabel(preview ? "Back to designs" : "Close card selection")
                }
            }
            .toolbarBackground(Color("ModalBackground"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .interactiveDismissDisabled(preview)
    }

    private func open(_ index: Int) {
        withAnimation(transition) { selected = index; preview = true }
    }

    private func closePreview() {
        withAnimation(transition) { preview = false }
    }
}
