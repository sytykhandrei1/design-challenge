import SwiftUI

struct PlataPlasticCardDemoView: View {
    @State private var skin: PlataPlasticFinish = .plata
    @State private var details = PlataPlasticDetails()
    @State private var draftDetails = PlataPlasticDetails()
    @State private var pose: PlataMetalV1Pose = .frontGrazing
    @State private var poseRevision = 0
    @State private var light: PlataPlasticLight = .studio
    @State private var showsDetails = false

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 5) {
                Text("Plastic").font(.title2.bold()).accessibilityIdentifier("plata-plastic-title")
                Text(skin.subtitle).font(.subheadline).multilineTextAlignment(.center)
                    .accessibilityIdentifier("plata-plastic-subtitle")

            }.padding(.horizontal)
            HStack(spacing: 0) {
                ForEach(PlataPlasticFinish.allCases) { value in
                    Button {
                        skin = value
                    } label: {
                        VStack(spacing: 5) {
                            Circle().fill(Color(uiColor: value.color))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(.white.opacity(skin == value ? 1 : 0), lineWidth: 2))
                            Text(value.title).font(.caption)
                                .foregroundStyle(skin == value ? .white : Color(white: 0.6))
                        }.frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .accessibilityIdentifier("plata-plastic-skin-\(value.rawValue)")
                    .accessibilityAddTraits(skin == value ? .isSelected : [])
                }
            }.padding(.horizontal, 16)

            PlataPlasticCardView(skin: skin, details: details, pose: pose,
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
                    ForEach(PlataPlasticLight.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("plata-plastic-light")
                Button { draftDetails = details; showsDetails = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Card details").accessibilityIdentifier("plata-plastic-details")
                    .font(.title3).frame(width: 44, height: 44)
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
        .padding(.top, 8)
        .background(Color(white: 0.045))
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsDetails, onDismiss: { details = draftDetails }) {
            NavigationStack {
                Form {
                    Section("Cardholder") {
                        Toggle("Show name", isOn: $draftDetails.showsName).accessibilityIdentifier("plata-plastic-show-name")
                        TextField("Cardholder name", text: $draftDetails.name)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .accessibilityIdentifier("plata-plastic-name-field")
                    }
                    Section("Demo credentials") {
                        Toggle("Show credentials", isOn: $draftDetails.showsNumber).accessibilityIdentifier("plata-plastic-show-number")
                        TextField("Card number", text: $draftDetails.number).keyboardType(.numbersAndPunctuation)
                        TextField("Valid thru", text: $draftDetails.expiry).keyboardType(.numbersAndPunctuation)
                        TextField("Security code (CVV)", text: $draftDetails.cvc).keyboardType(.numberPad)
                    }
                }
                .navigationTitle("Card details").navigationBarTitleDisplayMode(.inline)
                .softNavigationScrollEdge()
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { details = draftDetails; showsDetails = false }.accessibilityIdentifier("plata-plastic-details-done")
                } }
            }.presentationDetents([.large])
        }
    }
    private func poseButton(_ title: String, _ value: PlataMetalV1Pose) -> some View {
        Button(title) { pose = value; poseRevision += 1 }
            .accessibilityIdentifier("plata-plastic-pose-\(value.rawValue)")
    }
}

#if DEBUG
#Preview("PLATA Plastic — five physical finishes") { PlataPlasticCardDemoView() }
#endif
