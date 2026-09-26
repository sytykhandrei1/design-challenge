import UIKit
import ImageIO

/// Design decisions for the Digital row; the palette is artwork, not a baked reflection.
enum PlataDigitalSkin: String, CaseIterable, Identifiable, Sendable {
    case amanecer, jacaranda, cenote, noche
    var id: String { rawValue }
    var title: String {
        switch self { case .amanecer: "Amanecer"; case .jacaranda: "Jacarandá"; case .cenote: "Cenote"; case .noche: "Noche" }
    }
    var subtitle: String {
        switch self {
        case .amanecer: "Amanecer—warm light, a new beginning"
        case .jacaranda: "Jacarandá—violet light in full bloom"
        case .cenote: "Cenote—clear light, quiet depth"
        case .noche: "Noche—a sliver of light after dark"
        }
    }
    var frontInkColor: UIColor {
        self == .amanecer ? .digitalHex(0x101C36) : .white
    }
    var backIllustrationFilename: String { "\(rawValue)_back_illustration.png" }

    /// Centered aspect-fill inside the generated PNG's transparent presentation margin.
    /// Original PNG pixels stay unchanged; the ID-1 mesh supplies the rounded silhouette.
    var backIllustrationUVScale: SIMD2<Float> {
        switch self {
        case .amanecer: .init(0.988376661, 0.988733720)
        case .jacaranda: .init(0.996733376, 0.996462382)
        case .cenote: .init(0.946733376, 0.946475976)
        case .noche: .init(0.890733376, 0.890491201)
        }
    }

    var edgeColor: UIColor {
        switch self {
        case .amanecer: .digitalHex(0x254665)
        case .jacaranda: .digitalHex(0x8472C5)
        case .cenote: .digitalHex(0x257E87)
        case .noche: .digitalHex(0x292B69)
        }
    }
}

extension UIColor {
    static func digitalHex(_ rgb: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255, alpha: alpha)
    }
}

enum PlataDigitalError: LocalizedError {
    case rendering(String)
    case resource(String)
    var errorDescription: String? {
        switch self {
        case .rendering(let layer): "Cannot render Digital layer: \(layer)"
        case .resource(let file): "Missing or unreadable resource: \(file)"
        }
    }
}

/// Native vector/gradient authoring. Text is drawn at its actual raster resolution, never upscaled.
/// Cropped graphics layers avoid allocating a full-card bitmap for every label.
// These are independent bitmap renderers, not views. Callers can rasterize on
// a worker task; no shared CGContext, UIKit hierarchy or mutable drawing state.
enum PlataDigitalArtwork {
    static let backgroundSize = CGSize(width: 3072, height: 1937)

    private static func image(_ size: CGSize, canvas: CGSize? = nil, opaque: Bool = false,
                              label: String, draw: (CGContext, CGSize) -> Void) throws -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        format.preferredRange = .standard
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let logical = canvas ?? size
            renderer.cgContext.scaleBy(x: size.width / logical.width, y: size.height / logical.height)
            draw(renderer.cgContext, logical)
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let result = rendered.cgImage?.copy(colorSpace: space) else {
            throw PlataDigitalError.rendering(label)
        }
        return result
    }

    private static func gradient(_ context: CGContext, colors: [UInt32], stops: [CGFloat],
                                 from: CGPoint, to: CGPoint) {
        let values = colors.map { UIColor.digitalHex($0).cgColor } as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: values, locations: stops)!
        context.drawLinearGradient(gradient, start: from, end: to,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private static func glow(_ context: CGContext, color: UInt32, alpha: CGFloat,
                             center: CGPoint, radius: CGFloat, squash: CGFloat = 1) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: 1, y: squash)
        let colors = [UIColor.digitalHex(color, alpha: alpha).cgColor,
                      UIColor.digitalHex(color, alpha: 0).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
        context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                                   endCenter: .zero, endRadius: radius, options: [])
        context.restoreGState()
    }

    /// Decode at native resolution off the main actor through the appearance cache.
    /// No generated mip/detail upscale, raster edits, or image-set processing.
    private static func backIllustration(_ skin: PlataDigitalSkin) throws -> CGImage {
        let filename = skin.backIllustrationFilename
        let resource = "plata_digital_v1/\(filename)"
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil,
                                        subdirectory: "plata_digital_v1"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0,
                  [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let image = decoded.copy(colorSpace: space) else {
            throw PlataDigitalError.resource(resource)
        }
        return image
    }

    static func background(_ skin: PlataDigitalSkin, isBack: Bool = false) throws -> CGImage {
        if isBack { return try backIllustration(skin) }
        return try image(backgroundSize, canvas: CGSize(width: 1000, height: 630.6), opaque: true,
                  label: "\(skin.rawValue)/background") { c, _ in
            switch skin {
            case .amanecer:
                // Chromatic intermediate stops avoid the old grey/beige blend between orange and blue.
                gradient(c, colors: [0x143364, 0x257CAD, 0x869BCD, 0xEEA3AB, 0xFC865C, 0xFA501C, 0xBD3421],
                         stops: [0, 0.29, 0.46, 0.59, 0.73, 0.89, 1],
                         from: .init(x: 680, y: -90), to: .init(x: 280, y: 730))
                glow(c, color: 0x68D7E5, alpha: 0.28, center: .init(x: 900, y: 80), radius: 550, squash: 0.65)
                glow(c, color: 0xFFC58A, alpha: 0.30, center: .init(x: 80, y: 420), radius: 390, squash: 0.72)
            case .jacaranda:
                gradient(c, colors: [0x271B59, 0x5B3B9F, 0xAD83D5, 0xE1B6E7],
                         stops: [0, 0.36, 0.74, 1], from: .init(x: 60, y: 600), to: .init(x: 950, y: -90))
                glow(c, color: 0xEAACEE, alpha: 0.56, center: .init(x: 770, y: 410), radius: 560, squash: 0.40)
                glow(c, color: 0x655BDB, alpha: 0.72, center: .init(x: 230, y: 260), radius: 420, squash: 0.62)
            case .cenote:
                gradient(c, colors: [0x07353E, 0x08716D, 0x53C5C0, 0xC4EFE3],
                         stops: [0, 0.43, 0.79, 1], from: .init(x: 730, y: 660), to: .init(x: 280, y: -150))
                glow(c, color: 0xB6FFF1, alpha: 0.60, center: .init(x: 305, y: 110), radius: 490, squash: 0.78)
                glow(c, color: 0x097B85, alpha: 0.7, center: .init(x: 960, y: 500), radius: 500, squash: 0.90)
            case .noche:
                gradient(c, colors: [0x0D1435, 0x252653, 0x39366D],
                         stops: [0, 0.64, 1], from: .init(x: 70, y: 610), to: .init(x: 980, y: 0))
                // An intentional narrow colour band in the design, separate from the moving PBR highlight.
                gradient(c, colors: [0x111735, 0x25274E, 0x7374B6, 0xBCBBDE, 0x5C659C, 0x202746, 0x111735],
                         stops: [0, 0.40, 0.486, 0.5, 0.522, 0.61, 1],
                         from: .init(x: 340, y: 560), to: .init(x: 680, y: 95))
            }
        }
    }

    static let cloudRect = CGRect(x: 0.06, y: 0.665, width: 0.085,
        height: 0.085 * CGFloat(PlataMetalV1Geometry.width / PlataMetalV1Geometry.height) * 3 / 4)

    static func cloud(_ skin: PlataDigitalSkin) throws -> CGImage {
        // SF Symbols keeps the outline consistent with the native UI; it is not a brand logo.
        let configuration = UIImage.SymbolConfiguration(pointSize: 260, weight: .regular)
        guard let symbol = UIImage(systemName: "cloud", withConfiguration: configuration) else {
            throw PlataDigitalError.rendering("Digital SF Symbol: cloud")
        }
        return try image(CGSize(width: 384, height: 288), label: "Digital cloud") { _, size in
            let scale = min((size.width - 32) / symbol.size.width, (size.height - 32) / symbol.size.height)
            let fitted = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
            let rect = CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2,
                              width: fitted.width, height: fitted.height)
            symbol.withTintColor(skin.frontInkColor, renderingMode: .alwaysOriginal).draw(in: rect)
        }
    }

    // Official white SVG: Docs/plata-digital-v1-sources/01_Plata_logo_white.svg
    // SHA-256: db25252e6ed3f6cb48d9d47fae38a5bce7dc209c7ba63e5ba3c58171f00a9e89
    static let logoAspectRatio: CGFloat = 320.0 / 48.0
    // Common collection placement from the Metal handoff: x=5, y=0, width=2038 on a 2048 px card.
    static let logoWidthFraction: CGFloat = 2038.0 / 2048.0
    static let logoInsetFraction: CGFloat = 5.0 / 2048.0
    // Transparent guard pixels prevent opposite texture edges bleeding into one another at grazing angles.
    private static let logoPadding: CGFloat = 3.2
    static var logoRect: CGRect {
        let xScale = logoWidthFraction / 320
        let yScale = xScale * CGFloat(PlataMetalV1Geometry.width / PlataMetalV1Geometry.height)
        return CGRect(x: logoInsetFraction - logoPadding * xScale, y: -logoPadding * yScale,
                      width: (320 + 2 * logoPadding) * xScale, height: (48 + 2 * logoPadding) * yScale)
    }

    static func logo() throws -> CGImage {
        try image(CGSize(width: 3264, height: 544), canvas: CGSize(width: 326.4, height: 54.4), label: "Official PLATA vector mask") { c, _ in
            c.translateBy(x: logoPadding, y: logoPadding)
            // SVG commands are translated directly; coordinates and per-path fill rules are unchanged.
            c.setFillColor(UIColor.white.cgColor)
            c.clip(to: CGRect(x: 0, y: 0, width: 320, height: 48))
            // Clip only at the physical rounded card boundary, as in the supplied brand card artwork.
            let cardWidth = 320 / logoWidthFraction
            let cardHeight = cardWidth * CGFloat(PlataMetalV1Geometry.height / PlataMetalV1Geometry.width)
            let cornerRadius = cardWidth * CGFloat(PlataMetalV1Geometry.radius / PlataMetalV1Geometry.width)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: -cardWidth * logoInsetFraction, y: 0,
                                                       width: cardWidth, height: cardHeight),
                                    cornerRadius: cornerRadius).cgPath)
            c.clip()
            do {
                let p = CGMutablePath()
                p.move(to: .init(x: 283.488, y: 0))
                p.addLine(to: .init(x: 295.2, y: 0))
                p.addLine(to: .init(x: 319.273, y: 48))
                p.addLine(to: .init(x: 306.687, y: 48))
                p.addLine(to: .init(x: 289.336, y: 10.5))
                p.addLine(to: .init(x: 272.087, y: 48))
                p.addLine(to: .init(x: 259.504, y: 48))
                p.addLine(to: .init(x: 283.488, y: 0))
                p.closeSubpath()
                c.addPath(p); c.drawPath(using: .fill)
            }
            do {
                let p = CGMutablePath()
                p.move(to: .init(x: 68.4148, y: 0))
                p.addLine(to: .init(x: 80.2105, y: 0))
                p.addLine(to: .init(x: 80.2105, y: 39.75))
                p.addLine(to: .init(x: 115.061, y: 39.75))
                p.addLine(to: .init(x: 110.879, y: 48))
                p.addLine(to: .init(x: 68.4148, y: 48))
                p.addLine(to: .init(x: 68.4148, y: 0))
                p.closeSubpath()
                c.addPath(p); c.drawPath(using: .fill)
            }
            do {
                let p = CGMutablePath()
                p.move(to: .init(x: 198.167, y: 0))
                p.addLine(to: .init(x: 250.854, y: 0))
                p.addLine(to: .init(x: 250.854, y: 8.25))
                p.addLine(to: .init(x: 230.409, y: 8.25))
                p.addLine(to: .init(x: 230.409, y: 48))
                p.addLine(to: .init(x: 218.613, y: 48))
                p.addLine(to: .init(x: 218.613, y: 8.25))
                p.addLine(to: .init(x: 198.167, y: 8.25))
                p.addLine(to: .init(x: 198.167, y: 0))
                p.closeSubpath()
                c.addPath(p); c.drawPath(using: .fill)
            }
            do {
                let p = CGMutablePath()
                p.move(to: .init(x: 153.735, y: 0))
                p.addLine(to: .init(x: 165.448, y: 0))
                p.addLine(to: .init(x: 189.52, y: 48))
                p.addLine(to: .init(x: 176.935, y: 48))
                p.addLine(to: .init(x: 159.584, y: 10.5))
                p.addLine(to: .init(x: 142.334, y: 48))
                p.addLine(to: .init(x: 129.752, y: 48))
                p.addLine(to: .init(x: 153.735, y: 0))
                p.closeSubpath()
                c.addPath(p); c.drawPath(using: .fill)
            }
            do {
                let p = CGMutablePath()
                p.move(to: .init(x: 9.60251, y: 0.18956))
                p.addCurve(to: .init(x: 1.68313, y: 0.962631), control1: .init(x: 6.78559, y: 0.317532), control2: .init(x: 4.14485, y: 0.574154))
                p.addLine(to: .init(x: 0, y: 1.22824))
                p.addLine(to: .init(x: 0, y: 48))
                p.addLine(to: .init(x: 11.7957, y: 48))
                p.addLine(to: .init(x: 11.7957, y: 31.61))
                p.addLine(to: .init(x: 13.5772, y: 31.7086))
                p.addLine(to: .init(x: 22.7433, y: 31.7086))
                p.addCurve(to: .init(x: 32.55, y: 30.9317), control1: .init(x: 26.1014, y: 31.7086), control2: .init(x: 29.3709, y: 31.4504))
                p.addCurve(to: .init(x: 41.2598, y: 28.3234), control1: .init(x: 35.7725, y: 30.4058), control2: .init(x: 38.683, y: 29.5433))
                p.addLine(to: .init(x: 41.2728, y: 28.3172))
                p.addLine(to: .init(x: 41.2861, y: 28.3107))
                p.addCurve(to: .init(x: 47.695, y: 23.2565), control1: .init(x: 43.9007, y: 27.0271), control2: .init(x: 46.0543, y: 25.3477))
                p.addCurve(to: .init(x: 50.2541, y: 15.3546), control1: .init(x: 49.4351, y: 21.0385), control2: .init(x: 50.2541, y: 18.3659))
                p.addCurve(to: .init(x: 47.4411, y: 7.43498), control1: .init(x: 50.2541, y: 12.2815), control2: .init(x: 49.3592, y: 9.58984))
                p.addCurve(to: .init(x: 40.7852, y: 2.77905), control1: .init(x: 45.7145, y: 5.42684), control2: .init(x: 43.4759, y: 3.88232))
                p.addCurve(to: .init(x: 32.1001, y: 0.578716), control1: .init(x: 38.1569, y: 1.70136), control2: .init(x: 35.2568, y: 0.973299))
                p.addCurve(to: .init(x: 23.1183, y: 0), control1: .init(x: 29.0781, y: 0.193262), control2: .init(x: 26.0839, y: 0))
                p.addCurve(to: .init(x: 9.60251, y: 0.18956), control1: .init(x: 20.4373, y: 0), control2: .init(x: 12.4077, y: 0.0621248))
                p.closeSubpath()
                p.move(to: .init(x: 29.0035, y: 8.76202))
                p.addCurve(to: .init(x: 33.79, y: 10.0982), control1: .init(x: 30.8425, y: 9.03005), control2: .init(x: 32.431, y: 9.48245))
                p.addLine(to: .init(x: 33.824, y: 10.1136))
                p.addLine(to: .init(x: 33.8585, y: 10.1277))
                p.addCurve(to: .init(x: 36.9009, y: 12.2811), control1: .init(x: 35.2155, y: 10.6841), control2: .init(x: 36.2026, y: 11.4126))
                p.addLine(to: .init(x: 36.9311, y: 12.3187))
                p.addLine(to: .init(x: 36.9633, y: 12.3549))
                p.addCurve(to: .init(x: 37.9838, y: 15.3553), control1: .init(x: 37.6064, y: 13.078), control2: .init(x: 37.9838, y: 14.0298))
                p.addCurve(to: .init(x: 36.8212, y: 19.0994), control1: .init(x: 37.9838, y: 17.0183), control2: .init(x: 37.5481, y: 18.2162))
                p.addLine(to: .init(x: 36.803, y: 19.1215))
                p.addLine(to: .init(x: 36.7854, y: 19.1442))
                p.addCurve(to: .init(x: 33.5619, y: 21.5263), control1: .init(x: 36.0138, y: 20.1402), control2: .init(x: 34.9607, y: 20.9395))
                p.addCurve(to: .init(x: 28.3809, y: 22.8809), control1: .init(x: 32.0696, y: 22.1524), control2: .init(x: 30.3482, y: 22.6098))
                p.addCurve(to: .init(x: 22.3684, y: 23.2385), control1: .init(x: 26.4092, y: 23.1191), control2: .init(x: 24.4052, y: 23.2385))
                p.addLine(to: .init(x: 13.5056, y: 23.2385))
                p.addCurve(to: .init(x: 11.7957, y: 23.1796), control1: .init(x: 12.9224, y: 23.2069), control2: .init(x: 12.3482, y: 23.1871))
                p.addLine(to: .init(x: 11.8018, y: 8.48766))
                p.addCurve(to: .init(x: 13.4126, y: 8.40833), control1: .init(x: 12.2749, y: 8.45194), control2: .init(x: 12.8109, y: 8.42504))
                p.addCurve(to: .init(x: 23.3059, y: 8.34668), control1: .init(x: 14.8763, y: 8.3677), control2: .init(x: 21.6673, y: 8.34668))
                p.addCurve(to: .init(x: 29.0035, y: 8.76202), control1: .init(x: 25.2035, y: 8.34668), control2: .init(x: 27.1024, y: 8.48494))
                p.closeSubpath()
                c.addPath(p); c.drawPath(using: .eoFill)
            }
        }
    }

    static func payment() throws -> CGImage {
        try image(CGSize(width: 512, height: 320), canvas: CGSize(width: 160, height: 100), label: "Mastercard mark") { c, _ in
            c.setFillColor(UIColor.digitalHex(0xEB001B).cgColor)
            c.fillEllipse(in: CGRect(x: 0, y: 0, width: 100, height: 100))
            c.setFillColor(UIColor.digitalHex(0xF79E1B).cgColor)
            c.fillEllipse(in: CGRect(x: 60, y: 0, width: 100, height: 100))
            c.saveGState()
            c.addEllipse(in: CGRect(x: 0, y: 0, width: 100, height: 100)); c.clip()
            c.setFillColor(UIColor.digitalHex(0xFF5F00).cgColor)
            c.fillEllipse(in: CGRect(x: 60, y: 0, width: 100, height: 100)); c.restoreGState()
        }
    }

    /// Extract linear coverage from the exact same drawing used for Base Color.
    static func opacityMask(_ image: CGImage) throws -> CGImage {
        let w = image.width, h = image.height
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let success = rgba.withUnsafeMutableBytes { storage -> Bool in
            guard let c = CGContext(data: storage.baseAddress, width: w, height: h,
                                    bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        let alpha = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
        guard success, let provider = CGDataProvider(data: Data(alpha) as CFData),
              let result = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8,
                                   bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            throw PlataDigitalError.rendering("linear opacity mask")
        }
        return result
    }

}
