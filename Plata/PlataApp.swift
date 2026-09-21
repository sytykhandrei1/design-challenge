import SwiftUI

@main
struct PlataApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--plata-metal-v1-demo") {
                PlataMetalCardDemoView()
            } else {
                BankRootView()
            }
            #else
            BankRootView()
            #endif
        }
    }
}

struct BankRootView: View {
    @State private var showsOrderSheet = false
    @State private var opensGalleryAfterDismiss = false
    @State private var showsGallery = false
    @State private var galleryKind: CardOrderKind = .physical

    var body: some View {
        NavigationStack {
            PreviewEntryView(openCardPreview: { showsOrderSheet = true })
                .navigationDestination(isPresented: $showsGallery) { CardOrderingView(kind: galleryKind) }
        }
        .tint(.primary)
        .preferredColorScheme(.light)
        .task {
            // Warm the physical gallery while the preview entry is visible.
            // Only immutable gallery resources warm here, not a demo/ARView.
            async let plastic: Void? = try? CardGalleryResources.prewarmPlastic()
            async let metal: Void? = try? PlataMetalCardView.prewarmGalleryResources()
            _ = await (plastic, metal)
        }
        .task(id: showsOrderSheet) {
            // Prepare resource data while the type menu is open,
            // without creating a hidden ARView or blocking a navigation push.
            guard showsOrderSheet else { return }
            try? await PlataDigitalMaterialCache.shared.prewarm(around: .amanecer, includeShared: true)
        }
        .sheet(isPresented: $showsOrderSheet, onDismiss: {
            // Complete the modal choice before entering the main navigation stack.
            // onDismiss avoids overlapping native dismiss/push transitions.
            guard opensGalleryAfterDismiss else { return }
            opensGalleryAfterDismiss = false
            showsGallery = true
        }) {
            CardOrderSheet { kind in
                // A new gallery may prewarm again after an earlier memory warning.
                // Never reset this on color changes inside the same gallery.
                if kind == .physical { PlataPlasticCardMaterial.beginPrewarmingSession() }
                galleryKind = kind
                opensGalleryAfterDismiss = true
                showsOrderSheet = false
            }
        }
    }
}

private struct PreviewEntryView: View {
    var openCardPreview: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: openCardPreview) {
                Text("Card preview").frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .tint(Color("AccentColor"))
                .accessibilityIdentifier("cardPreviewButton")
        }
        .font(.body.weight(.medium))
        .controlSize(.large)
        .frame(maxWidth: 360)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("ModalBackground"))
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .softNavigationScrollEdge()
    }
}

extension View {
    /// Keep native bar materials; iOS 27's automatic edge is deliberately not
    /// used, since this flow calls for the softer iOS 26-style transition.
    @ViewBuilder
    func softNavigationScrollEdge() -> some View {
        if #available(iOS 26.0, *) {
            self.toolbarBackground(.automatic, for: .navigationBar)
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self.toolbarBackground(.automatic, for: .navigationBar)
        }
    }
}

/// A stationary interactive canvas still needs a native scroll container for
/// the system to blend content under its navigation bar. Its pan is disabled;
/// child 3D gestures remain the only source of card movement.
struct NavigationCanvas<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                // Keyboard/navigation transitions can briefly propose a
                // negative available height before the next layout pass.
                content.frame(width: max(0, geometry.size.width), height: max(0, geometry.size.height))
            }
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .softNavigationScrollEdge()
    }
}
