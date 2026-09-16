import SwiftUI

/// Compares the three title-morphing techniques on the card names. Swiping the slider changes the
/// name, and the title morphs from the old value into the new one with the selected technique.
struct MorphSettingsView: View {
    @State private var style: MorphStyle = .diff
    @State private var index = 0
    @State private var compareAll = false
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.34, dampingFraction: 0.82)))
    private var drag: CGFloat = 0

    private var title: String { CardTitles.all[index] }

    var body: some View {
        VStack(spacing: 20) {
            Picker("Morphing", selection: $style) {
                ForEach(MorphStyle.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .disabled(compareAll)
            .accessibilityIdentifier("morphStyle")

            Text(compareAll ? "All three techniques run on the same swipe." : style.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 34, alignment: .top)

            Toggle("Compare all three", isOn: $compareAll)
                .font(.subheadline)
                .accessibilityIdentifier("compareAll")

            slider

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("ModalBackground"))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var slider: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                if compareAll {
                    VStack(spacing: 18) {
                        ForEach(MorphStyle.allCases) { option in
                            VStack(spacing: 2) {
                                Text(option.title.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                MorphingTitle(text: title, style: option,
                                              identifier: "morphTitle-\(option.rawValue)")
                            }
                        }
                    }
                } else {
                    MorphingTitle(text: title, style: style)
                }
            }
            .frame(height: compareAll ? 230 : 132)
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
