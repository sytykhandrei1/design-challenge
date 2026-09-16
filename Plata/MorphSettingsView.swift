import SwiftUI

/// Compares the candidate title-morphing techniques on the card names. Swiping the slider changes
/// the name, and the title morphs from the old value into the new one with the selected technique.
struct MorphSettingsView: View {
    @State private var style: MorphStyle = .diff
    @State private var index = 0
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.34, dampingFraction: 0.82)))
    private var drag: CGFloat = 0

    private var title: String { CardTitles.all[index] }

    var body: some View {
        VStack(spacing: 18) {
            techniques

            VStack(spacing: 4) {
                Text(style.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(style.source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(height: 54, alignment: .top)
            .padding(.horizontal, 20)

            slider

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("ModalBackground"))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var techniques: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MorphStyle.allCases) { option in
                    Button { style = option } label: {
                        Text(option.title)
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(option == style ? Color.white : Color.primary)
                            .background(option == style ? Color.black : Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("style-\(option.rawValue)")
                    .accessibilityAddTraits(option == style ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 20)
        }
        .accessibilityIdentifier("styleRow")
    }

    private var slider: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                MorphingTitle(text: title, style: style)
            }
            .frame(height: 132)
            .padding(.horizontal, 20)
            .offset(x: drag)

            HStack(spacing: 7) {
                ForEach(CardTitles.all.indices, id: \.self) { slot in
                    Circle()
                        .fill(slot == index ? Color.primary : Color.secondary.opacity(0.24))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityHidden(true)

            Text("Swipe to change the name")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .gesture(swipe)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("morphSlider")
        .accessibilityLabel("Card name")
        .accessibilityValue(title)
        .accessibilityAdjustableAction { direction in
            if direction == .increment { index = min(index + 1, CardTitles.all.count - 1) }
            if direction == .decrement { index = max(index - 1, 0) }
        }
    }

    /// The plate nudges with the finger and springs back; the name itself never travels sideways,
    /// it changes in place so the morph is what you watch. Thresholds match the card carousel.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($drag) { value, state, _ in
                let translation = value.translation.width
                let atEdge = (index == 0 && translation > 0)
                    || (index == CardTitles.all.count - 1 && translation < 0)
                state = translation * (atEdge ? 0.05 : 0.2)
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.width
                let step = projected < -55 ? 1 : projected > 55 ? -1 : 0
                index = min(max(index + step, 0), CardTitles.all.count - 1)
            }
    }
}
