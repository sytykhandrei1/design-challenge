import SwiftUI

/// Open from Account → Transfer, or use --plata-metal-v1-demo in Debug.
struct PlataMetalCardDemoView: View {
    @State private var collection = ProcessInfo.processInfo.arguments.contains("--plata-plastic-default") ? "Plastic" :
        (ProcessInfo.processInfo.arguments.contains("--plata-digital-default") ? "Digital" : "Metal")
    @State private var finish: PlataMetalFinish = .plata
    @State private var poseRevision = 0
    @State private var pose: PlataMetalV1Pose = .frontGrazing

    var body: some View {
        NavigationCanvas {
        VStack(spacing: 0) {
            Picker("Card collection", selection: $collection) {
                Text("Metal").tag("Metal")
                Text("Digital").tag("Digital")
                Text("Plastic").tag("Plastic")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("plata-card-collection")
            .padding(.horizontal, 24).padding(.top, 8)
            if collection == "Digital" {
                PlataDigitalCardDemoView()
            } else if collection == "Plastic" {
                PlataPlasticCardDemoView()
            } else {
                metalContent
            }
        }
        }
        .background(Color(white: 0.045))
        .preferredColorScheme(.dark)
    }

    private var metalContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Metal").font(.title2.bold())
                    .accessibilityIdentifier("plata-metal-demo-title")
                Text(finish.subtitle)
                    .font(.subheadline).multilineTextAlignment(.center)
                    .accessibilityIdentifier("plata-metal-demo-subtitle")
                Text("85.60 × 53.98 × 0.76 mm").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.horizontal)

            Picker("Metal finish", selection: $finish) {
                ForEach(PlataMetalFinish.allCases) { finish in
                    Text(finish.title).tag(finish)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("plata-metal-finish-picker")
            .padding(.horizontal, 24)

            PlataMetalCardView(pose: pose, poseRevision: poseRevision, finish: finish)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("Drag to rotate · Pinch to zoom\nDouble tap to reset zoom")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                poseButton("Front", .front)
                poseButton("Light", .frontGrazing)
                poseButton("Back", .back)
                poseButton("Edge", .edge)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(white: 0.045))
        .preferredColorScheme(.dark)
    }

    private func poseButton(_ title: String, _ value: PlataMetalV1Pose) -> some View {
        Button(title) {
            pose = value
            poseRevision += 1
        }
            .accessibilityIdentifier("plata-metal-v1-\(value.rawValue)")
    }
}

#if DEBUG
#Preview("PLATA Metal — Plata & Obsidiana") {
    PlataMetalCardDemoView()
}
#endif
