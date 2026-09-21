import SwiftUI
import UIKit

/// Three review entry points: new-card sheet, gallery via Withdraw, Metal via Transfer.
struct AccountTabsView: View {
    var openNewCard: () -> Void
    var openGallery: () -> Void
    var openMetalDemo: () -> Void
    private enum AccountTab: Hashable { case home, pay, invest, invite, support }

    var body: some View {
        TabView(selection: .constant(AccountTab.home)) {
            Tab("Home", image: "account-tab-home", value: AccountTab.home) {
                AccountView(openNewCard: openNewCard, openMetalDemo: openMetalDemo)
                    .background(AccountTabBarConfiguration())
            }
            Tab("Pay", image: "account-tab-pay", value: AccountTab.pay) { Color.clear }
            Tab("Invest", image: "account-tab-invest", value: AccountTab.invest) { Color.clear }
            Tab("Invite", image: "account-tab-invite", value: AccountTab.invite) { Color.clear }
            // The search role supplies iOS 26's separate trailing tab, using the design's icon.
            Tab("", image: "account-tab-support", value: AccountTab.support, role: .search) {
                Color.clear
            }
        }
        .tint(Color("AccentColor"))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openGallery) {
                    HStack(spacing: 4) {
                        AccountAsset("account-withdraw", size: 20)
                        Text("Withdraw").font(.body.weight(.medium))
                    }
                    .padding(.horizontal, 6)
                    .foregroundStyle(AccountPalette.primary)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("AccountWithdraw"))
                .accessibilityIdentifier("withdrawGalleryButton")
            }
        }
        .softNavigationScrollEdge()
    }
}

struct AccountView: View {
    var openNewCard: () -> Void
    var openMetalDemo: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @ScaledMetric(relativeTo: .largeTitle) private var balanceSize = 44

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                accountHeader
                    // The iOS 26 toolbar adds 10 pt to the reference's 44 pt navbar.
                    .padding(.top, ifModernToolbar(-10))
                VStack(spacing: 20) {
                    quickActions
                    transactions
                    creditPayment
                    clabeDeposit
                    aboutAccount
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 58)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("accountScrollView")
        .scrollIndicators(.hidden)
        .background(Color("ModalBackground"))
        .foregroundStyle(AccountPalette.primary)
        .onReceive(clock) { now = $0 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
    }

    private func ifModernToolbar(_ value: CGFloat) -> CGFloat {
        if #available(iOS 26.0, *) { return value }
        return 0
    }

    private var accountHeader: some View {
        VStack(spacing: 0) {
            Text("$4,975")
                .font(.system(size: balanceSize, weight: .semibold))
                .frame(height: 44)
                .padding(.top, 28)
            HStack(spacing: 4) {
                Text("Total balance: $1,520.50").font(.body)
                AccountAsset("account-balance-chevron", size: 16)
            }
            .frame(height: 20)
            .padding(.top, 8)
            HStack(spacing: 10) {
                Image("account-card-physical")
                    .resizable().frame(width: 70, height: 48)
                    .accessibilityLabel("Physical card ending in 6994")
                Image("account-card-digital")
                    .resizable().frame(width: 70, height: 48)
                    .accessibilityLabel("Digital card ending in 7361")
                Button(action: openNewCard) {
                    Image("account-card-add")
                        .resizable().frame(width: 70, height: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open a new card")
                .accessibilityIdentifier("openNewCardButton")
            }
            .padding(.top, 60)
            .padding(.bottom, 56)
        }
        .frame(maxWidth: .infinity)
    }

    private var quickActions: some View {
        HStack(spacing: 21) {
            quickAction("Deposit", asset: "account-deposit")
            quickAction("Bill pay", asset: "account-bill-pay")
            Button(action: openMetalDemo) {
                quickAction("Transfer", asset: "account-transfer")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("transferMetalDemoButton")
        }
    }

    private func quickAction(_ title: String, asset: String) -> some View {
        VStack(spacing: 6) {
            AccountAsset(asset, size: 32)
            Text(title).font(.footnote.weight(.semibold)).frame(height: 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 86)
        .background(.background, in: RoundedRectangle(cornerRadius: 28))
        .accessibilityElement(children: .combine)
    }

    private var transactions: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Transactions").font(.title3.weight(.bold)).foregroundStyle(Color("CardTitle"))
                Text("$13,180 spent in \(AccountDates(now: now).month)").font(.subheadline)
            }
            Spacer(minLength: 0)
            // Figma exports the 48 pt sphere together with its 4.17 pt side glow
            // and 9 pt bottom shadow. Keep that overflow at its original scale.
            Image("account-transactions-sphere")
                .resizable().frame(width: 170.0 / 3.0, height: 57)
                .offset(y: 2.5)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .frame(height: 88)
        .background(.background, in: RoundedRectangle(cornerRadius: 28))
        .accessibilityElement(children: .combine)
    }

    private var creditPayment: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Credit payment", subtitle: AccountDates(now: now).paymentDue, details: true)
            // The design intentionally crops the third option. Horizontal scrolling keeps
            // its complete text reachable without introducing another actionable button.
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    paymentOption("$75.50", subtitle: "Minimum", primary: true)
                    paymentOption("$330.75", subtitle: "Minimum + MSI")
                    paymentOption("$1,299.30", subtitle: "Full monthly\npayment")
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 20)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 28))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private func paymentOption(_ amount: String, subtitle: String, primary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(amount).font(.body.weight(.bold)).frame(height: 20)
            Text(subtitle).font(.footnote).lineSpacing(0).padding(.top, 4)
            Spacer(minLength: 8)
            Text("Pay")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primary ? Color.white : AccountPalette.cardText)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(primary ? Color("AccountPaymentAccent") : Color(.systemBackground),
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(12)
        .frame(width: 124, height: 148)
        .background(AccountPalette.neutral, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var clabeDeposit: some View {
        VStack(spacing: 0) {
            sectionHeader("Deposit with CLABE", details: true)
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("706 000 0000 0000 0000")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    AccountAsset("account-copy", size: 16)
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(AccountPalette.neutral, in: RoundedRectangle(cornerRadius: 16))
                AccountAsset("account-share", size: 16)
                    .frame(width: 48, height: 48)
                    .background(AccountPalette.neutral, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 28))
    }

    private var aboutAccount: some View {
        VStack(spacing: 0) {
            sectionHeader("Acerca de")
            List {
                accountDetail("Límite de crédito", value: "$7,000", disclosure: false)
                accountDetail("Saldo total", value: "$560.90")
                accountDetail("Estados de cuenta")
                accountDetail("Comisiones y condiciones")
                accountDetail("Documentos legales")
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .contentMargins(.all, 0)
            .environment(\.defaultMinListRowHeight, 56)
            .frame(height: 280)
            .padding(.bottom, 8)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 28))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private func accountDetail(_ title: String, value: String? = nil, disclosure: Bool = true) -> some View {
        HStack(spacing: 0) {
            Text(title).font(.body)
            Spacer(minLength: 8)
            if let value { Text(value).font(.body).foregroundStyle(AccountPalette.secondary) }
            if disclosure { AccountAsset("account-chevron", size: 16) }
        }
        .frame(height: 56)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color(.systemBackground))
        .accessibilityElement(children: .combine)
    }

    private func sectionHeader(_ title: String, subtitle: String? = nil, details: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.title3.weight(.bold))
                Spacer(minLength: 4)
                if details {
                    Text("Details").font(.subheadline.weight(.semibold)).foregroundStyle(Color("AccountDetails"))
                }
            }
            .frame(height: 24)
            if let subtitle { Text(subtitle).font(.subheadline).frame(height: 18) }
        }
        .padding(20)
    }
}

private enum AccountPalette {
    static let primary = Color("AccountTextPrimary")
    static let secondary = Color("AccountTextSecondary")
    static let cardText = Color("AccountCardText")
    static let neutral = Color("AccountNeutral")
}

private struct AccountAsset: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat) { self.name = name; self.size = size }

    var body: some View {
        Image(name).resizable().renderingMode(.original)
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// Configure the real UITabBar without replacing its layout, materials or accessibility.
/// Interaction is deliberately off for this prototype; the selected Home tab stays intact.
private struct AccountTabBarConfiguration: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ConfigurationController { ConfigurationController() }
    func updateUIViewController(_ controller: ConfigurationController, context: Context) { controller.configure() }

    final class ConfigurationController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configure()
        }

        func configure() {
            guard let bar = tabBarController?.tabBar else { return }
            bar.isUserInteractionEnabled = false
            bar.unselectedItemTintColor = UIColor(named: "AccountTextSecondary")
        }
    }
}
