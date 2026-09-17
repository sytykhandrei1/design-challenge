import SwiftUI

@main
struct PlataApp: App {
    var body: some Scene {
        WindowGroup { BankRootView().preferredColorScheme(.light) }
    }
}

struct BankRootView: View {
    @State private var ordering = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Button { ordering = true } label: {
                    Text("start flow")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 1, green: 80.0 / 255.0, blue: 0),
                                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("startFlowButton")
                .padding(.horizontal, 20)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("ModalBackground").ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { MorphSettingsView() } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settingsButton")
                }
            }
        }
        .tint(.primary)
        .sheet(isPresented: $ordering) {
            CardOrderingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(40)
        }
    }
}
