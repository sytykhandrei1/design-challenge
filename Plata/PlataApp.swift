import SwiftUI

@main
struct PlataApp: App {
    var body: some Scene {
        WindowGroup { BankRootView().preferredColorScheme(.light) }
    }
}

struct BankRootView: View {
    var body: some View {
        NavigationStack { HomeScreen() }
            .tint(.primary)
    }
}

private struct HomeScreen: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color("ModalBackground").ignoresSafeArea()
            Image("home-background")
                .resizable().scaledToFill().frame(height: 430)
                .blur(radius: 28).opacity(0.78).clipped().ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 20) {
                    profile
                    HStack(spacing: 20) {
                        metricCard(title: "Cashback", value: "$467.18", footer: "%  ♙  ◫  ◉", accent: true)
                        metricCard(title: "MSI to defer", value: "12", footer: "109 partners")
                    }
                    transactions
                    creditAccount
                    debitAccount
                    inviteBanner
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 32)
            }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { MorphSettingsView() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings").accessibilityIdentifier("settingsButton")
            }
        }
        .accessibilityIdentifier("homeScreen")
    }

    private var profile: some View {
        HStack(spacing: 20) {
            Image("profile-avatar").resizable().scaledToFill()
                .frame(width: 56, height: 56).clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Santiago").font(.headline)
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.palette).foregroundStyle(.white, .orange)
                }
                Text("1 month with Plata").font(.subheadline)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func metricCard(title: String, value: String, footer: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline)
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(accent ? Color.orange : Color.primary)
            Spacer(minLength: 4)
            Text(footer).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 84).padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var transactions: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Transactions").font(.title3.weight(.semibold))
                Text("$14,157 spent in October").font(.subheadline)
            }
            Spacer(); SpendingSphere()
        }
        .padding(20).frame(height: 86)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var creditAccount: some View {
        NavigationLink { AccountScreen() } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text("$4,975").font(.title3.weight(.semibold)); Spacer()
                    Text("Pay by Nov 4").font(.caption).foregroundStyle(.secondary)
                }
                HStack { Text("Available in Crédito").font(.subheadline); Spacer(); MiniCardStack() }
            }
            .padding(20).frame(height: 86)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain).accessibilityLabel("Available in Crédito, $4,975")
        .accessibilityIdentifier("accountCell")
    }

    private var debitAccount: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("$15,104.57").font(.title3.weight(.semibold)); Spacer()
                Text("$23.78 earned").font(.caption).foregroundStyle(.green)
            }
            HStack { Text("Cuenta").font(.subheadline); Spacer(); MastercardMark().frame(width: 28, height: 18) }
        }
        .padding(20).frame(height: 86)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var inviteBanner: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Get $300").font(.headline)
                (Text("Invite a friend · ") + Text("2 days left").foregroundStyle(.orange)).font(.subheadline)
            }
            Spacer()
            Image("home-banner").resizable().scaledToFit().frame(width: 92, height: 82)
        }
        .foregroundStyle(.white).padding(.leading, 20).padding(.trailing, 8).frame(height: 84)
        .background(LinearGradient(colors: [Color(red: 0.09, green: 0.10, blue: 0.11),
                                            Color(red: 0.28, green: 0.31, blue: 0.39)],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct AccountScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 3) {
                    Text("Available in Crédito").font(.body)
                    Text("$4,975").font(.system(size: 44, weight: .semibold))
                    HStack(spacing: 4) {
                        Text("Total balance: $1,520.50")
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }.font(.body)
                }
                HStack(spacing: 10) {
                    AccountCardThumbnail(lastFour: "6994", style: .silver)
                    AccountCardThumbnail(lastFour: "7361", style: .gradient)
                    NavigationLink { RecipientScreen() } label: {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground)).frame(width: 70, height: 49)
                            .overlay { Image(systemName: "plus").font(.title2).foregroundStyle(.secondary) }
                    }
                    .buttonStyle(.plain).accessibilityLabel("Add a new card").accessibilityIdentifier("addCard")
                }
                HStack(spacing: 16) {
                    QuickAction(title: "Deposit", symbol: "plus.circle")
                    QuickAction(title: "Bill pay", symbol: "circle.grid.2x2")
                    QuickAction(title: "Transfer", symbol: "arrow.right.circle")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transactions").font(.title3.weight(.semibold))
                        Text("$13,180 spent in October").font(.subheadline)
                    }
                    Spacer(); SpendingSphere()
                }
                .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                creditPayment
                accountDetails
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .background(Color("ModalBackground").ignoresSafeArea())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Withdraw", systemImage: "circle.lefthalf.filled") { }.tint(.primary)
            }
        }
        .accessibilityIdentifier("accountScreen")
    }

    private var creditPayment: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Credit payment").font(.title3.weight(.semibold))
                    Text("Due by 17 October").font(.subheadline)
                }
                Spacer(); Text("Details").foregroundStyle(.blue)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    PaymentOption(amount: "$75.50", caption: "Minimum", selected: true)
                    PaymentOption(amount: "$330.75", caption: "Minimum + MSI")
                    PaymentOption(amount: "$1,299", caption: "Full monthly payment")
                }
            }
        }
        .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var accountDetails: some View {
        VStack(spacing: 0) {
            DetailRow(title: "Deposit with CLABE", value: "706 000 0000 0000 0000")
            DetailRow(title: "Credit limit", value: "$7,000")
            DetailRow(title: "Total balance", value: "$560.90")
            DetailRow(title: "Statements")
            DetailRow(title: "Fees and conditions")
            DetailRow(title: "Legal documents")
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct RecipientScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Who to issue extra\ncard for")
                .font(.system(size: 30, weight: .bold)).padding(.top, 28).padding(.bottom, 38)
            NavigationLink { CardTypeScreen() } label: {
                FlowChoiceRow(title: "Me", subtitle: "Physical or digital card") {
                    Image("profile-avatar").resizable().scaledToFill()
                        .frame(width: 40, height: 40).clipShape(Circle())
                }
            }
            .buttonStyle(.plain).accessibilityIdentifier("meOption")
            NavigationLink { CardTypeScreen() } label: {
                FlowChoiceRow(title: "Another person", subtitle: "They will spend from your Crédito") {
                    Image(systemName: "plus").font(.title2).frame(width: 40, height: 40)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
            }
            .buttonStyle(.plain).padding(.top, 20).accessibilityIdentifier("anotherPersonOption")
            Spacer()
        }
        .padding(.horizontal, 20).background(Color("ModalBackground").ignoresSafeArea())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }
}

private struct CardTypeScreen: View {
    @State private var ordering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select card type").font(.system(size: 30, weight: .bold))
                .padding(.top, 28).padding(.bottom, 34)
            Button { ordering = true } label: {
                FlowChoiceRow(title: "Physical", subtitle: "Pay everywhere") { EmptyView() }
            }
            .buttonStyle(.plain).accessibilityIdentifier("physicalOption")
            Button { } label: {
                FlowChoiceRow(title: "Digital", subtitle: "Ready to use") { EmptyView() }
            }
            .buttonStyle(.plain).padding(.top, 20).accessibilityIdentifier("digitalOption")
            Spacer()
        }
        .padding(.horizontal, 20).background(Color("ModalBackground").ignoresSafeArea())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $ordering) {
            CardOrderingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(40)
        }
    }
}

private struct FlowChoiceRow<Leading: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct QuickAction: View {
    let title: String
    let symbol: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 28, weight: .medium))
                .symbolRenderingMode(.palette).foregroundStyle(.primary, .orange)
            Text(title).font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity).frame(height: 86)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private enum AccountCardStyle { case silver, gradient }

private struct AccountCardThumbnail: View {
    let lastFour: String
    let style: AccountCardStyle
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(style == .silver ? AnyShapeStyle(Color(.systemGray5)) : AnyShapeStyle(Color.white))
            if style == .gradient { Image("account-card-skin").resizable().scaledToFill() }
            HStack(spacing: 5) {
                Text(lastFour).font(.caption).foregroundStyle(.secondary)
                MastercardMark().frame(width: 18, height: 12)
            }.padding(8)
        }
        .frame(width: 70, height: 49).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.08)))
    }
}

private struct MastercardMark: View {
    var body: some View {
        HStack(spacing: -4) { Circle().fill(.red); Circle().fill(.orange).opacity(0.9) }
    }
}

private struct MiniCardStack: View {
    var body: some View {
        HStack(spacing: -9) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index == 0 ? Color(.systemGray4) : Color(red: 0.82, green: 0.80, blue: 0.98))
                    .frame(width: 26, height: 18)
                    .overlay { if index == 0 { MastercardMark().frame(width: 14, height: 9) } }
            }
        }
    }
}

private struct SpendingSphere: View {
    var body: some View {
        Circle().fill(AngularGradient(colors: [.red, .orange, .white, .blue, .purple, .red], center: .center))
            .frame(width: 48, height: 48).shadow(color: .purple.opacity(0.2), radius: 8, y: 6)
    }
}

private struct PaymentOption: View {
    let amount: String
    let caption: String
    var selected = false
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(amount).font(.headline)
            Text(caption).font(.caption).frame(height: 32, alignment: .topLeading)
            Text("Pay").font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 8)
                .foregroundStyle(selected ? .white : .primary)
                .background(selected ? Color.orange : Color.white, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(12).frame(width: 124, height: 126, alignment: .topLeading)
        .background(Color("ModalBackground"), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct DetailRow: View {
    let title: String
    var value: String? = nil
    var body: some View {
        HStack {
            Text(title); Spacer()
            if let value { Text(value).foregroundStyle(.secondary) }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .font(.body).padding(.horizontal, 20).frame(minHeight: 54)
    }
}
