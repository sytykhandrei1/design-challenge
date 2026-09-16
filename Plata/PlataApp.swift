import SwiftUI

@main
struct PlataApp: App {
    var body: some Scene {
        WindowGroup { BankRootView().preferredColorScheme(.light) }
    }
}

struct BankRootView: View {
    @State private var ordering = true

    var body: some View {
        TabView {
            NavigationStack {
                VStack(spacing: 24) {
                    Text("Available in Crédito").font(.body)
                    Text("$4,975").font(.system(size: 44, weight: .semibold))
                    Button("Choose your card") { ordering = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding(.top, 32)
                .frame(maxWidth: .infinity)
                .background(Color("ModalBackground"))
                .navigationTitle("Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { MorphSettingsView() } label: {
                            Image(systemName: "gearshape")
                        }
                        .tint(.primary)
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("settingsButton")
                    }
                }
            }
            .tabItem { Label("Home", systemImage: "house") }
            NavigationStack { Text("Pay").navigationTitle("Pay") }
                .tabItem { Label("Pay", systemImage: "arrow.left.arrow.right") }
            NavigationStack { Text("Invest").navigationTitle("Invest") }
                .tabItem { Label("Invest", systemImage: "chart.line.uptrend.xyaxis") }
            NavigationStack { Text("Invite").navigationTitle("Invite") }
                .tabItem { Label("Invite", systemImage: "gift") }
            NavigationStack { Text("Support").navigationTitle("Support") }
                .tabItem { Label("Support", systemImage: "message") }
        }
        .sheet(isPresented: $ordering) {
            CardOrderingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(40)
        }
    }
}
