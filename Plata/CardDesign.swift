import SwiftUI
import UIKit

enum CardOrderKind: Hashable {
    case physical, digital
    var categories: [CardCategory] { self == .physical ? [.plastic, .metal] : [.digital] }
}

/// Product type and finish are independent selections. Each collection uses
/// its reviewed renderer and a single shared source for finish descriptions.
enum CardCategory: String, CaseIterable, Identifiable {
    case digital, plastic, metal
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var subtitle: String {
        switch self {
        case .digital: "Works the moment you tap order"
        case .plastic: PlataPlasticFinish.plata.subtitle
        case .metal: PlataMetalFinish.plata.subtitle
        }
    }
    var action: String { "Choose this design" }
    // Presentation order in Figma 5274:41141; the standalone renderer's enum
    // order is deliberately unchanged.
    static let plasticFinishes: [PlataPlasticFinish] = [.plata, .rose, .barro, .hueso, .cobalto]
    var colors: [CardFinish] {
        switch self {
        // Representative palette stops from the real Digital artwork.
        case .digital: [.init(PlataDigitalSkin.amanecer.title, 0xFC865C),
                        .init(PlataDigitalSkin.jacaranda.title, 0xAD83D5),
                        .init(PlataDigitalSkin.cenote.title, 0x53C5C0),
                        .init(PlataDigitalSkin.noche.title, 0x252653)]
        case .plastic: Self.plasticFinishes.map { .init($0.title, color: $0.color) }
        // Median sRGB of the unengraved body in the actual front render,
        // not material tint multipliers (which are not visible surface colors).
        case .metal: [.init("Plata", 0x656668), .init("Obsidiana", 0x3E3F41)]
        }
    }
    func subtitle(finish: Int) -> String {
        switch self {
        case .digital: PlataDigitalSkin.allCases[min(max(finish, 0), PlataDigitalSkin.allCases.count - 1)].subtitle
        case .metal: (finish == 0 ? PlataMetalFinish.plata : .obsidiana).subtitle
        case .plastic: Self.plasticFinishes[min(max(finish, 0), Self.plasticFinishes.count - 1)].subtitle
        }
    }
    func design(finish: Int) -> CardDesign {
        let color = colors[min(max(finish, 0), colors.count - 1)]
        return CardDesign(id: "gallery-\(rawValue)-\(finish)", title: title,
                          assetName: "gallery-\(rawValue)", selectorColor: Color(uiColor: color.uiColor),
                          plusOnly: false)
    }
}

struct CardFinish {
    let name: String
    let uiColor: UIColor
    init(_ name: String, _ hex: UInt32) {
        self.name = name
        uiColor = UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                          green: CGFloat((hex >> 8) & 255) / 255,
                          blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    init(_ name: String, color: UIColor) { self.name = name; uiColor = color }
}

struct CardDesign: Identifiable, Hashable {
    let id: String
    let title: String
    let assetName: String
    let selectorColor: Color
    let plusOnly: Bool

    var usesBrushedPBR: Bool { id == "brushed-metal" }
    var metalFinish: PlataMetalFinish? {
        guard id.hasPrefix("gallery-metal-") else { return nil }
        return id == "gallery-metal-0" ? .plata : .obsidiana
    }
    var digitalSkin: PlataDigitalSkin? {
        guard id.hasPrefix("gallery-digital-"),
              let index = Int(id.dropFirst("gallery-digital-".count)),
              PlataDigitalSkin.allCases.indices.contains(index) else { return nil }
        return PlataDigitalSkin.allCases[index]
    }
    var plasticFinish: PlataPlasticFinish? {
        guard id.hasPrefix("gallery-plastic-"),
              let index = Int(id.dropFirst("gallery-plastic-".count)),
              CardCategory.plasticFinishes.indices.contains(index) else { return nil }
        return CardCategory.plasticFinishes[index]
    }
    var usesRealityKit: Bool { metalFinish != nil || digitalSkin != nil || plasticFinish != nil }

    /// nil means price is not displayed for Digital, not a paid physical card.
    var issuePrice: Int? {
        if digitalSkin != nil { return nil }
        if plasticFinish == .plata { return 0 }
        return 40
    }
    var priceLabel: String? { issuePrice.map { $0 == 0 ? "Free" : "$\($0)" } }
    var galleryTitle: String { priceLabel.map { "\(title) • \($0)" } ?? title }

    var setupTitle: String {
        id.hasPrefix("gallery-") || title.contains("·") ? title : "\(title) · Metal"
    }

    var callToAction: String {
        if id.hasPrefix("gallery-") { return "Choose this design" }
        return plusOnly ? "✨ Available with Plata Plus" : "Order for 40 MX$"
    }
}

enum CardCatalog {
    static let all: [CardDesign] = [
        CardDesign(id: "sand-dunes", title: "Sand dunes", assetName: "hola-platacard",
                   selectorColor: Color(red: 0.90, green: 0.25, blue: 0.13), plusOnly: false),
        CardDesign(id: "pinklovers", title: "Pinklovers · Metal", assetName: "pinklovers-card",
                   selectorColor: Color(red: 0.94, green: 0.53, blue: 0.63), plusOnly: false),
        CardDesign(id: "colors-of-life", title: "Colors of life · Metal", assetName: "colors-of-life-card",
                   selectorColor: Color(red: 0.48, green: 0.04, blue: 0.25), plusOnly: true),
        CardDesign(id: "brushed-metal", title: "Plata · Brushed metal", assetName: "pbr-brushed-metal",
                   selectorColor: Color(red: 0.68, green: 0.69, blue: 0.71), plusOnly: true)
    ]
}

struct CardFaceOptions: Equatable {
    var rendersDynamicDetails = false
    var showsCardholderName = true
    var cardholderName = "SANTIAGO D FERNANDEZ"
    var showsCardNumber = true
}

struct CardArtwork: View {
    let design: CardDesign
    var options = CardFaceOptions()

    var body: some View {
        if design.usesRealityKit {
            MetalCard(design: design, options: options, interactive: false, prepareForInteraction: true)
                .aspectRatio(1.72, contentMode: .fit)
                .accessibilityHidden(true)
        } else {
            Image(uiImage: CardTextureRenderer.front(named: design.assetName, options: options))
                .resizable()
                .interpolation(.high)
                .aspectRatio(1.72, contentMode: .fit)
                .accessibilityHidden(true)
        }
    }
}

/// The bitmap is the immutable art layer. User-controlled fields are composed above a cleaned
/// dynamic region, so the name and future back-side details can change without replacing the art.
enum CardTextureRenderer {
    private static let cache = NSCache<NSString, UIImage>()

    static func front(named name: String, options: CardFaceOptions) -> UIImage {
        var options = options
        if name == "gallery-plastic", !options.rendersDynamicDetails {
            // The temporary Figma Rosé bitmap still contains a baked holder.
            // Apply the same cached personalization layer used by setup.
            options.rendersDynamicDetails = true
        }
        if name == "pbr-brushed-metal" {
            return brushedFront(options: options)
        }
        guard let base = UIImage(named: name) else { return UIImage() }
        guard options.rendersDynamicDetails else { return base }
        let key = "front|\(name)|\(options.showsCardholderName)|\(options.cardholderName)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: base.size, format: format).image { _ in
            let full = CGRect(origin: .zero, size: base.size)
            base.draw(in: full)

            // All supplied faces reserve the lower-left strip for the name. Copying the adjacent
            // material texture keeps the brushed/painted surface intact while removing baked text.
            let clean = CGRect(x: base.size.width * 0.035, y: base.size.height * 0.805,
                               width: base.size.width * 0.43, height: base.size.height * 0.13)
            let source = CGRect(x: clean.minX, y: base.size.height * 0.665,
                                width: clean.width, height: clean.height)
            if let cg = base.cgImage?.cropping(to: source.integral) {
                UIImage(cgImage: cg, scale: 1, orientation: .up).draw(in: clean)
            }

            guard options.showsCardholderName else { return }
            let text = options.cardholderName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: base.size.height * 0.043, weight: .medium),
                .foregroundColor: nameColor(for: name),
                .paragraphStyle: paragraph,
                .kern: base.size.width * 0.0012
            ]
            NSString(string: text.uppercased()).draw(
                in: CGRect(x: clean.minX + base.size.width * 0.012,
                           y: clean.midY - base.size.height * 0.027,
                           width: clean.width, height: base.size.height * 0.07),
                withAttributes: attributes
            )
        }
        cache.setObject(image, forKey: key)
        return image
    }

    static func backPlaceholder(for design: CardDesign, options: CardFaceOptions) -> UIImage {
        if design.usesBrushedPBR {
            return UIImage(named: options.showsCardNumber
                           ? "pbr-brushed-metal-back-demo" : "pbr-brushed-metal-back-clean") ?? UIImage()
        }
        let key = "back|\(design.id)|\(options.showsCardNumber)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let size = CGSize(width: 1288, height: 748)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let context = renderer.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let colors = backColors(for: design.assetName).map(\.cgColor) as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                      locations: [0, 1])!
            context.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: 68).addClip()
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            UIColor.black.withAlphaComponent(0.72).setFill()
            context.fill(CGRect(x: 0, y: 120, width: size.width, height: 135))

            let brand: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 54, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                .kern: 8
            ]
            NSString(string: "PLATA").draw(at: CGPoint(x: 70, y: 42), withAttributes: brand)
            if options.showsCardNumber {
                let details: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 39, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                    .kern: 5
                ]
                NSString(string: "••••  ••••  ••••  2040").draw(
                    at: CGPoint(x: 72, y: size.height * 0.58), withAttributes: details)
            }
            let note: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 25, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.62)
            ]
            NSString(string: "BACK-SIDE PLACEHOLDER").draw(
                at: CGPoint(x: 72, y: size.height - 92), withAttributes: note)
            context.restoreGState()
        }
        cache.setObject(image, forKey: key)
        return image
    }

    private static func nameColor(for name: String) -> UIColor {
        switch name {
        case "hola-platacard": return UIColor.white.withAlphaComponent(0.92)
        case "pinklovers-card", "gallery-plastic": return UIColor(red: 0.37, green: 0.08, blue: 0.17, alpha: 0.88)
        default: return UIColor(red: 0.91, green: 0.85, blue: 0.72, alpha: 0.92)
        }
    }

    private static func brushedFront(options: CardFaceOptions) -> UIImage {
        if !options.rendersDynamicDetails ||
            (options.showsCardholderName && options.cardholderName == "CARD HOLDER") {
            return UIImage(named: "pbr-brushed-metal-front-demo") ?? UIImage()
        }
        let clean = UIImage(named: "pbr-brushed-metal-front-clean") ?? UIImage()
        guard options.showsCardholderName else { return clean }
        let text = options.cardholderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return clean }
        let key = "brushed|\(text)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: clean.size, format: format).image { _ in
            clean.draw(at: .zero)
            NSString(string: text.uppercased()).draw(
                in: CGRect(x: clean.size.width * 0.037, y: clean.size.height * 0.892,
                           width: clean.size.width * 0.39, height: clean.size.height * 0.06),
                withAttributes: [.font: UIFont(name: "Arial-BoldMT", size: clean.size.height * 0.045)
                                 ?? UIFont.systemFont(ofSize: clean.size.height * 0.045, weight: .bold),
                                 .foregroundColor: UIColor(white: 0.24, alpha: 1)])
        }
        cache.setObject(image, forKey: key)
        return image
    }

    private static func backColors(for name: String) -> [UIColor] {
        switch name {
        case "hola-platacard":
            return [UIColor(red: 0.91, green: 0.28, blue: 0.12, alpha: 1),
                    UIColor(red: 0.18, green: 0.38, blue: 0.66, alpha: 1)]
        case "pinklovers-card":
            return [UIColor(red: 0.93, green: 0.52, blue: 0.63, alpha: 1),
                    UIColor(red: 0.48, green: 0.08, blue: 0.25, alpha: 1)]
        default:
            return [UIColor(red: 0.60, green: 0.04, blue: 0.29, alpha: 1),
                    UIColor(red: 0.04, green: 0.21, blue: 0.48, alpha: 1)]
        }
    }
}
