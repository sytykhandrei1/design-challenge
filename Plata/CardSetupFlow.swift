import SwiftUI

struct CardSetupView: View {
    let design: CardDesign

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsCardNumber = true
    @State private var showsCardholderName = false
    @State private var cardholderName = "SANTIAGO D FERNANDEZ"
    @State private var cardHasArrived = false
    @FocusState private var nameIsFocused: Bool

    private var options: CardFaceOptions {
        CardFaceOptions(rendersDynamicDetails: true,
                        showsCardholderName: design.digitalSkin == nil && showsCardholderName,
                        cardholderName: cardholderName,
                        showsCardNumber: design.digitalSkin == nil && showsCardNumber)
    }

    private var layoutAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .easeInOut(duration: 0.4)
    }

    var body: some View {
        NavigationCanvas {
        VStack(spacing: nameIsFocused ? 10 : 22) {
            MetalCard(design: design, options: options,
                      interactive: true, prepareForInteraction: true)
                .frame(width: nameIsFocused ? 176 : 244,
                       height: (nameIsFocused ? 176 : 244) / 1.72)
                .offset(y: cardHasArrived ? 0 : 78)
                .opacity(cardHasArrived ? 1 : 0.5)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Interactive \(design.title) card")
                .accessibilityIdentifier("setupInteractiveCard")

            Text("Set up card")
                .font(.system(size: 20, weight: .semibold))
                .accessibilityAddTraits(.isHeader)

            if design.digitalSkin == nil {
             VStack(spacing: 18) {
                SettingToggle(title: "Card number", detail: "Will print on the back side",
                              identifier: "cardNumberToggle", isOn: $showsCardNumber)
                SettingToggle(title: "Cardholder name", detail: "Will print on the card",
                              identifier: "cardholderNameToggle", isOn: $showsCardholderName)
                    .onChange(of: showsCardholderName) { _, enabled in
                        if !enabled { nameIsFocused = false }
                    }

                VStack(alignment: .leading, spacing: 9) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cardholder name")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("SANTIAGO D FERNANDEZ", text: $cardholderName)
                            .font(.system(size: 15, weight: .regular))
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($nameIsFocused)
                            .disabled(!showsCardholderName)
                            .accessibilityIdentifier("cardholderNameInput")
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 58)
                    .background(Color.black.opacity(showsCardholderName ? 0.035 : 0.022),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(showsCardholderName ? 1 : 0.45)

                    Text("You can change up to 5 letters")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .padding(.leading, 16)
                }
            }
            .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, nameIsFocused ? 2 : 18)
        }
        .background(Color("ModalBackground").ignoresSafeArea())
        .animation(layoutAnimation, value: nameIsFocused)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !nameIsFocused {
                NavigationLink {
                    DeliveryAddressView(design: design, options: options)
                } label: {
                    FlowButtonLabel(text: "Continue")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("setupContinueButton")
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
                .background(Color("ModalBackground"))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .navigationTitle(design.setupTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { nameIsFocused = false }
                    .accessibilityIdentifier("keyboardDoneButton")
            }
        }
        .softNavigationScrollEdge()
        .onAppear {
            withAnimation(layoutAnimation) { cardHasArrived = true }
        }
    }
}

private struct SettingToggle: View {
    let title: String
    let detail: String
    let identifier: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .medium))
                Text(detail).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(red: 0.18, green: 0.78, blue: 0.39))
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
    }
}

struct DeliveryAddressView: View {
    let design: CardDesign
    let options: CardFaceOptions

    @State private var address = "General Pedro Maria De La Anaya 100/22"
    @State private var details = ""

    var body: some View {
        NavigationCanvas {
        VStack(spacing: 0) {
            MapPlaceholder()
                .frame(maxWidth: .infinity)
                .frame(height: 390)

            VStack(spacing: 16) {
                Text("Delivery address")
                    .font(.system(size: 17, weight: .semibold))

                FlowTextField(caption: "06000 Ciudad de México, CDMX", placeholder: "Address",
                              text: $address, identifier: "deliveryAddressInput")
                FlowTextField(caption: nil, placeholder: "Details (optional)",
                              text: $details, identifier: "deliveryDetailsInput")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            Spacer(minLength: 12)
        }
        }
        .background(Color("ModalBackground").ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NavigationLink {
                CheckoutView(design: design, options: options, address: address)
            } label: {
                FlowButtonLabel(text: "Continue")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addressContinueButton")
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
            .background(Color("ModalBackground"))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .softNavigationScrollEdge()
    }
}

private struct FlowTextField: View {
    let caption: String?
    let placeholder: String
    @Binding var text: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let caption {
                Text(caption).font(.caption2).foregroundStyle(.secondary)
            }
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .accessibilityIdentifier(identifier)
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(Color.black.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MapPlaceholder: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.94, green: 0.95, blue: 0.94)
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? Color.white : Color.blue.opacity(0.08))
                        .frame(width: proxy.size.width * 1.3, height: index.isMultiple(of: 2) ? 15 : 8)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -32 : 54))
                        .offset(x: CGFloat(index - 3) * 34, y: CGFloat(index - 3) * 42)
                }
                VStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color("AccentColor"), .white)
                    Text("Delivery point")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .offset(x: 54, y: 22)

                VStack(spacing: 10) {
                    Image(systemName: "plus")
                    Divider().frame(width: 22)
                    Image(systemName: "minus")
                }
                .font(.system(size: 17, weight: .medium))
                .padding(12)
                .background(.ultraThinMaterial, in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(16)
            }
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map placeholder showing the delivery point")
    }
}

struct CheckoutView: View {
    let design: CardDesign
    let options: CardFaceOptions
    let address: String

    @Environment(\.dismiss) private var dismiss
    @State private var delivery = 0

    private var price: String? { design.plusOnly ? "Plata Plus" : design.priceLabel }
    private var total: String? {
        guard let amount = design.issuePrice else { return nil }
        if delivery == 0 { return price }
        return "$\(amount + 80)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    HStack(spacing: 12) {
                        CardArtwork(design: design, options: options)
                            .frame(width: 56, height: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(design.title).font(.system(size: 15, weight: .medium))
                            Text(design.plasticFinish != nil ? "Plastic card" : design.digitalSkin != nil ? "Digital card" : "Metal card")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let price {
                            Text(price).font(.system(size: 15, weight: .medium))
                                .accessibilityIdentifier("checkoutCardPrice")
                        }
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.035),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Address").font(.system(size: 17, weight: .semibold))
                            Spacer()
                            Button { dismiss() } label: { Image(systemName: "square.and.pencil") }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Change delivery address")
                                .accessibilityIdentifier("changeAddressButton")
                        }
                        Text(address).font(.system(size: 15))
                        Text("06000 Ciudad de México, CDMX")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Delivery").font(.system(size: 17, weight: .semibold))
                        DeliveryChoice(title: "Pickup point", detail: "You will get your card with self-service",
                                       price: "FREE", selected: delivery == 0) { delivery = 0 }
                        DeliveryChoice(title: "DHL Express", detail: "From 1 work day",
                                       price: "80 MX$", selected: delivery == 1) { delivery = 1 }
                    }

                    Spacer(minLength: 130)

                    if let total {
                        HStack {
                            Text("Total").font(.system(size: 17, weight: .semibold))
                            Spacer()
                            Text(total).font(.system(size: 17, weight: .semibold))
                                .accessibilityIdentifier("checkoutTotalPrice")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
        }
        .background(Color("ModalBackground").ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { } label: { FlowButtonLabel(text: "Continue") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("checkoutContinueButton")
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
                .background(Color("ModalBackground"))
        }
        .navigationTitle("Order details")
        .navigationBarTitleDisplayMode(.inline)
        .softNavigationScrollEdge()
    }
}

private struct DeliveryChoice: View {
    let title: String
    let detail: String
    let price: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .medium))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(price).font(.system(size: 15, weight: .medium))
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.blue : Color.secondary.opacity(0.35))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FlowButtonLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color("AccentColor"),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
