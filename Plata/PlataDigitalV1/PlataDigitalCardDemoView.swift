import SwiftUI

struct PlataDigitalCardDemoView: View {
    @State private var skin: PlataDigitalSkin = .amanecer
    @State private var pose: PlataMetalV1Pose = .frontGrazing
    @State private var poseRevision = 0
    @State private var light: PlataDigitalLight = .studio

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 5) {
                Text("Digital").font(.title2.bold()).accessibilityIdentifier("plata-digital-title")
                Text(skin.subtitle).font(.subheadline).multilineTextAlignment(.center)
                    .accessibilityIdentifier("plata-digital-subtitle")
                Text("Ready instantly").font(.caption.weight(.medium))
                    .foregroundStyle(Color(red: 0.67, green: 0.86, blue: 0.87))
            }.padding(.horizontal)
            HStack(spacing: 0) {
                ForEach(PlataDigitalSkin.allCases) { value in
                    Button {
                        skin = value
                    } label: {
                        VStack(spacing: 5) {
                            Circle().fill(Color(uiColor: value.edgeColor))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(.white.opacity(skin == value ? 1 : 0), lineWidth: 2))
                            Text(value.title).font(.caption)
                                .foregroundStyle(skin == value ? .white : Color(white: 0.6))
                        }.frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .accessibilityIdentifier("plata-digital-skin-\(value.rawValue)")
                    .accessibilityAddTraits(skin == value ? .isSelected : [])
                }
            }.padding(.horizontal, 16)

            PlataDigitalCardView(skin: skin, pose: pose,
                                 poseRevision: poseRevision, light: light)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("Drag to rotate · Pinch to zoom · Double tap to reset")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            HStack {
                poseButton("Front", .front)
                poseButton("Light", .frontGrazing)
                poseButton("Back", .back)
                poseButton("Edge", .edge)
            }.buttonStyle(.bordered)
            HStack(spacing: 16) {
                Picker("Lighting", selection: $light) {
                    ForEach(PlataDigitalLight.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("plata-digital-light")
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
        .padding(.top, 8)
        .background(Color(white: 0.045))
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
    private func poseButton(_ title: String, _ value: PlataMetalV1Pose) -> some View {
        Button(title) { pose = value; poseRevision += 1 }
            .accessibilityIdentifier("plata-digital-pose-\(value.rawValue)")
    }
}

#if DEBUG
#Preview("PLATA Digital — four light studies") { PlataDigitalCardDemoView() }
#endif
