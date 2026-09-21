import UIKit
import CoreText

/// Physical plastic: colour plus surface finish, never metallic or emissive.
enum PlataPlasticFinish: String, CaseIterable, Identifiable {
    case plata, rose, barro, cobalto, hueso
    var id: String { rawValue }
    var title: String {
        switch self { case .plata: "Plata"; case .rose: "Rosé"; case .barro: "Barro"; case .cobalto: "Cobalto"; case .hueso: "Hueso" }
    }
    var subtitle: String {
        switch self {
        case .plata: "Plata—matte grey, quiet and clean"
        case .rose: "Rosé—brushed finish, catches the light"
        case .barro: "Barro—burnt terracotta, warm and matte"
        case .cobalto: "Cobalto—deep talavera blue"
        case .hueso: "Hueso—bone white, soft matte"
        }
    }
    var surface: String { self == .rose ? "satin" : (self == .cobalto ? "gloss" : "matte") }
    var color: UIColor {
        switch self {
        case .plata: .digitalHex(0xA9AAAB)
        case .rose: .digitalHex(0xDC8BA5)
        case .barro: .digitalHex(0xB85339)
        case .cobalto: .digitalHex(0x17369B)
        case .hueso: .digitalHex(0xE9E0CE)
        }
    }
    var inkColor: UIColor { self == .plata || self == .rose || self == .hueso ? .digitalHex(0x303238) : .digitalHex(0xF7F2E9) }
}

/// Independent, replaceable credentials. Nothing is baked into the substrate.
struct PlataPlasticDetails: Equatable {
    var name = "SANTIAGO D FERNANDEZ"
    var number = "0000 0000 0000 0000"
    var expiry = "00/00"
    var cvc = "000"
    var showsName = true
    var showsNumber = true
}

enum PlataPlasticError: LocalizedError {
    case resource(String)
    case rendering(String)
    var errorDescription: String? {
        switch self {
        case .resource(let name): "Missing or unreadable resource: \(name)"
        case .rendering(let name): "Cannot render Plastic layer: \(name)"
        }
    }
}

@MainActor enum PlataPlasticArtwork {
    /// Metal manifest coordinates. Rectangles are normalized top-left card space.
    static func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x / 2048, y: y / 1292, width: width / 2048, height: height / 1292)
    }
    static let nameRect = CGRect(x: 0.06, y: 0.805, width: 0.65,
        height: 0.65 * CGFloat(PlataMetalV1Geometry.width / PlataMetalV1Geometry.height) / 8)

    // Metal is the type-size reference. Its front uses SF Regular 70 / 2048.
    // Back fonts are baked, so match their measured glyph heights in that same
    // 2048 × 1292 card space, not the unrelated pixel size of this cropped layer.
    private static let numberFont = metalFont(sample: "0", height: 57, digits: true)
    private static let securityLabelFont = metalFont(sample: "CVC", height: 28)
    private static let securityValueFont = metalFont(sample: "0", height: 42, digits: true)
    private static let expiryLabelFont = metalFont(sample: "VALID THRU", height: 23)
    private static let expiryValueFont = metalFont(sample: "0", height: 46, digits: true)

    private static func metalFont(sample: String, height: CGFloat, digits: Bool = false) -> UIFont {
        let font = digits ? UIFont.monospacedDigitSystemFont(ofSize: 100, weight: .regular)
                          : UIFont.systemFont(ofSize: 100, weight: .regular)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: sample, attributes: [.font: font]))
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        return font.withSize(font.pointSize * height / bounds.height)
    }

    static let stripeRect = rect(0, 170, 2048, 177)
    static let signatureRect = rect(108, 478, 952, 150)
    static let credentialsRect = rect(104, 466, 1280, 640)
    static let contactlessRect = rect(1631, 814, 158, 212)

    private static func image(_ size: CGSize, canvas: CGSize, label: String,
                              draw: (CGContext) -> Void) throws -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.preferredRange = .standard
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.scaleBy(x: size.width / canvas.width, y: size.height / canvas.height)
            draw(context.cgContext)
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let result = rendered.cgImage?.copy(colorSpace: space) else { throw PlataPlasticError.rendering(label) }
        return result
    }

    static func name(_ name: String) throws -> CGImage {
        try image(CGSize(width: 1536, height: 192), canvas: CGSize(width: 600, height: 75), label: "cardholder") { _ in
            let value = String(name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().prefix(32))
            let scale = 600 / (2048 * nameRect.width)
            let font = UIFont.systemFont(ofSize: 70 * scale, weight: .regular)
            let tracking = 2 * scale
            let measured = (value as NSString).size(withAttributes: [.font: font]).width
            let available = 592 - CGFloat(max(0, value.count - 1)) * tracking
            let fitted = font.withSize(font.pointSize * min(1, available / max(1, measured)))
            (value as NSString).draw(at: CGPoint(x: 2, y: 5), withAttributes: [
                .font: fitted, .kern: tracking, .foregroundColor: UIColor.white])
        }
    }

    static func credentials(_ details: PlataPlasticDetails) throws -> CGImage {
        try image(CGSize(width: 2560, height: 1280), canvas: CGSize(width: 1280, height: 640), label: "credentials") { _ in
            guard details.showsNumber else { return }
            func text(_ value: String, x: CGFloat, y: CGFloat, font: UIFont, width: CGFloat) {
                let measured = (value as NSString).size(withAttributes: [.font: font]).width
                (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [
                    .font: font.withSize(font.pointSize * min(1, width / max(1, measured))), .foregroundColor: UIColor.white])
            }
            // Security code sits beside the signature panel, as on Metal.
            text("CVV", x: 1044, y: 0, font: securityLabelFont, width: 220)
            text(String(details.cvc.filter(\.isNumber).prefix(4)), x: 1044, y: 70, font: securityValueFont, width: 220)
            let digits = String(details.number.filter(\.isNumber).prefix(19))
            let grouped = stride(from: 0, to: digits.count, by: 4).map { offset -> String in
                let start = digits.index(digits.startIndex, offsetBy: offset)
                let end = digits.index(start, offsetBy: min(4, digits.count - offset))
                return String(digits[start..<end])
            }.joined(separator: " ")
            text(grouped, x: 8, y: 346, font: numberFont, width: 1256)
            text("Expire", x: 8, y: 488, font: expiryLabelFont, width: 200)
            text(String(details.expiry.prefix(7)), x: 8, y: 562, font: expiryValueFont, width: 300)
        }
    }

    static func contactless() throws -> CGImage {
        try image(CGSize(width: 400, height: 536), canvas: CGSize(width: 125, height: 167.25), label: "contactless") { context in
            // Literal polygon data from CardMaterials/v1/shared/vector/nfc.svg.
            // This is an existing source outline, not a font glyph or a rebuilt PLATA mark.
            let path = CGMutablePath()
            for outline in contactlessOutlines {
                guard let first = outline.first else { continue }
                path.move(to: CGPoint(x: first.x - 1467, y: first.y - 557))
                for point in outline.dropFirst() { path.addLine(to: CGPoint(x: point.x - 1467, y: point.y - 557)) }
                path.closeSubpath()
            }
            context.setFillColor(UIColor.white.cgColor)
            context.addPath(path); context.drawPath(using: .eoFill)
        }
    }
    private static let contactlessOutlines: [[CGPoint]] = [
        [.init(x: 1555.6250, y: 557.0000), .init(x: 1557.3750, y: 557.0000), .init(x: 1558.8750, y: 557.1250), .init(x: 1560.1250, y: 557.3750), .init(x: 1561.1250, y: 557.7500), .init(x: 1561.8750, y: 558.2500), .init(x: 1563.4375, y: 560.1875), .init(x: 1565.8125, y: 563.5625), .init(x: 1569.0000, y: 568.3750), .init(x: 1573.0000, y: 574.6250), .init(x: 1576.5625, y: 580.8125), .init(x: 1579.6875, y: 586.9375), .init(x: 1582.3750, y: 593.0000), .init(x: 1584.6250, y: 599.0000), .init(x: 1586.5625, y: 604.9375), .init(x: 1588.1875, y: 610.8125), .init(x: 1589.5000, y: 616.6250), .init(x: 1590.5000, y: 622.3750), .init(x: 1591.1875, y: 628.5000), .init(x: 1591.5625, y: 635.0000), .init(x: 1591.6250, y: 641.8750), .init(x: 1591.3750, y: 649.1250), .init(x: 1590.7500, y: 656.2500), .init(x: 1589.7500, y: 663.2500), .init(x: 1588.3750, y: 670.1250), .init(x: 1586.6250, y: 676.8750), .init(x: 1584.6875, y: 683.1875), .init(x: 1582.5625, y: 689.0625), .init(x: 1580.2500, y: 694.5000), .init(x: 1577.7500, y: 699.5000), .init(x: 1575.3750, y: 704.0000), .init(x: 1573.1250, y: 708.0000), .init(x: 1571.0000, y: 711.5000), .init(x: 1569.0000, y: 714.5000), .init(x: 1567.0625, y: 717.1250), .init(x: 1565.1875, y: 719.3750), .init(x: 1563.3750, y: 721.2500), .init(x: 1561.6250, y: 722.7500), .init(x: 1559.6875, y: 723.7500), .init(x: 1557.5625, y: 724.2500), .init(x: 1555.2500, y: 724.2500), .init(x: 1552.7500, y: 723.7500), .init(x: 1550.7500, y: 722.7500), .init(x: 1549.2500, y: 721.2500), .init(x: 1548.2500, y: 719.2500), .init(x: 1547.7500, y: 716.7500), .init(x: 1548.0625, y: 713.9375), .init(x: 1549.1875, y: 710.8125), .init(x: 1551.1250, y: 707.3750), .init(x: 1553.8750, y: 703.6250), .init(x: 1556.5000, y: 699.6250), .init(x: 1559.0000, y: 695.3750), .init(x: 1561.3750, y: 690.8750), .init(x: 1563.6250, y: 686.1250), .init(x: 1565.6250, y: 681.4375), .init(x: 1567.3750, y: 676.8125), .init(x: 1568.8750, y: 672.2500), .init(x: 1570.1250, y: 667.7500), .init(x: 1571.1875, y: 662.9375), .init(x: 1572.0625, y: 657.8125), .init(x: 1572.7500, y: 652.3750), .init(x: 1573.2500, y: 646.6250), .init(x: 1573.5000, y: 641.1875), .init(x: 1573.5000, y: 636.0625), .init(x: 1573.2500, y: 631.2500), .init(x: 1572.7500, y: 626.7500), .init(x: 1572.1250, y: 622.4375), .init(x: 1571.3750, y: 618.3125), .init(x: 1570.5000, y: 614.3750), .init(x: 1569.5000, y: 610.6250), .init(x: 1568.0625, y: 606.3750), .init(x: 1566.1875, y: 601.6250), .init(x: 1563.8750, y: 596.3750), .init(x: 1561.1250, y: 590.6250), .init(x: 1558.4375, y: 585.4375), .init(x: 1555.8125, y: 580.8125), .init(x: 1553.2500, y: 576.7500), .init(x: 1550.7500, y: 573.2500), .init(x: 1548.9375, y: 570.1875), .init(x: 1547.8125, y: 567.5625), .init(x: 1547.3750, y: 565.3750), .init(x: 1547.6250, y: 563.6250), .init(x: 1548.1250, y: 562.0625), .init(x: 1548.8750, y: 560.6875), .init(x: 1549.8750, y: 559.5000), .init(x: 1551.1250, y: 558.5000), .init(x: 1552.5000, y: 557.7500), .init(x: 1554.0000, y: 557.2500)],
        [.init(x: 1529.6250, y: 575.3750), .init(x: 1531.3750, y: 575.6250), .init(x: 1533.2500, y: 576.5000), .init(x: 1535.2500, y: 578.0000), .init(x: 1537.3750, y: 580.1250), .init(x: 1539.6250, y: 582.8750), .init(x: 1541.9375, y: 586.3125), .init(x: 1544.3125, y: 590.4375), .init(x: 1546.7500, y: 595.2500), .init(x: 1549.2500, y: 600.7500), .init(x: 1551.4375, y: 606.5625), .init(x: 1553.3125, y: 612.6875), .init(x: 1554.8750, y: 619.1250), .init(x: 1556.1250, y: 625.8750), .init(x: 1557.0000, y: 632.1875), .init(x: 1557.5000, y: 638.0625), .init(x: 1557.6250, y: 643.5000), .init(x: 1557.3750, y: 648.5000), .init(x: 1556.8750, y: 653.4375), .init(x: 1556.1250, y: 658.3125), .init(x: 1555.1250, y: 663.1250), .init(x: 1553.8750, y: 667.8750), .init(x: 1552.2500, y: 672.8125), .init(x: 1550.2500, y: 677.9375), .init(x: 1547.8750, y: 683.2500), .init(x: 1545.1250, y: 688.7500), .init(x: 1542.6875, y: 693.3750), .init(x: 1540.5625, y: 697.1250), .init(x: 1538.7500, y: 700.0000), .init(x: 1537.2500, y: 702.0000), .init(x: 1535.8750, y: 703.5625), .init(x: 1534.6250, y: 704.6875), .init(x: 1533.5000, y: 705.3750), .init(x: 1532.5000, y: 705.6250), .init(x: 1531.3125, y: 705.8125), .init(x: 1529.9375, y: 705.9375), .init(x: 1528.3750, y: 706.0000), .init(x: 1526.6250, y: 706.0000), .init(x: 1525.0625, y: 705.6875), .init(x: 1523.6875, y: 705.0625), .init(x: 1522.5000, y: 704.1250), .init(x: 1521.5000, y: 702.8750), .init(x: 1520.7500, y: 701.5000), .init(x: 1520.2500, y: 700.0000), .init(x: 1520.0000, y: 698.3750), .init(x: 1520.0000, y: 696.6250), .init(x: 1520.5000, y: 694.6875), .init(x: 1521.5000, y: 692.5625), .init(x: 1523.0000, y: 690.2500), .init(x: 1525.0000, y: 687.7500), .init(x: 1526.8125, y: 685.2500), .init(x: 1528.4375, y: 682.7500), .init(x: 1529.8750, y: 680.2500), .init(x: 1531.1250, y: 677.7500), .init(x: 1532.4375, y: 674.5625), .init(x: 1533.8125, y: 670.6875), .init(x: 1535.2500, y: 666.1250), .init(x: 1536.7500, y: 660.8750), .init(x: 1537.8750, y: 655.4375), .init(x: 1538.6250, y: 649.8125), .init(x: 1539.0000, y: 644.0000), .init(x: 1539.0000, y: 638.0000), .init(x: 1538.8750, y: 632.8750), .init(x: 1538.6250, y: 628.6250), .init(x: 1538.2500, y: 625.2500), .init(x: 1537.7500, y: 622.7500), .init(x: 1536.8750, y: 619.6250), .init(x: 1535.6250, y: 615.8750), .init(x: 1534.0000, y: 611.5000), .init(x: 1532.0000, y: 606.5000), .init(x: 1529.9375, y: 602.0000), .init(x: 1527.8125, y: 598.0000), .init(x: 1525.6250, y: 594.5000), .init(x: 1523.3750, y: 591.5000), .init(x: 1521.6875, y: 588.8750), .init(x: 1520.5625, y: 586.6250), .init(x: 1520.0000, y: 584.7500), .init(x: 1520.0000, y: 583.2500), .init(x: 1520.4375, y: 581.7500), .init(x: 1521.3125, y: 580.2500), .init(x: 1522.6250, y: 578.7500), .init(x: 1524.3750, y: 577.2500), .init(x: 1526.1250, y: 576.1875), .init(x: 1527.8750, y: 575.5625)],
        [.init(x: 1502.3750, y: 594.3750), .init(x: 1504.6250, y: 594.6250), .init(x: 1506.7500, y: 595.3750), .init(x: 1508.7500, y: 596.6250), .init(x: 1510.6250, y: 598.3750), .init(x: 1512.3750, y: 600.6250), .init(x: 1514.0625, y: 603.1875), .init(x: 1515.6875, y: 606.0625), .init(x: 1517.2500, y: 609.2500), .init(x: 1518.7500, y: 612.7500), .init(x: 1520.0625, y: 616.3125), .init(x: 1521.1875, y: 619.9375), .init(x: 1522.1250, y: 623.6250), .init(x: 1522.8750, y: 627.3750), .init(x: 1523.4375, y: 631.1250), .init(x: 1523.8125, y: 634.8750), .init(x: 1524.0000, y: 638.6250), .init(x: 1524.0000, y: 642.3750), .init(x: 1523.7500, y: 646.3125), .init(x: 1523.2500, y: 650.4375), .init(x: 1522.5000, y: 654.7500), .init(x: 1521.5000, y: 659.2500), .init(x: 1520.3750, y: 663.4375), .init(x: 1519.1250, y: 667.3125), .init(x: 1517.7500, y: 670.8750), .init(x: 1516.2500, y: 674.1250), .init(x: 1514.6875, y: 677.0625), .init(x: 1513.0625, y: 679.6875), .init(x: 1511.3750, y: 682.0000), .init(x: 1509.6250, y: 684.0000), .init(x: 1508.1875, y: 685.5000), .init(x: 1507.0625, y: 686.5000), .init(x: 1506.2500, y: 687.0000), .init(x: 1505.7500, y: 687.0000), .init(x: 1505.0000, y: 687.0625), .init(x: 1504.0000, y: 687.1875), .init(x: 1502.7500, y: 687.3750), .init(x: 1501.2500, y: 687.6250), .init(x: 1499.7500, y: 687.4375), .init(x: 1498.2500, y: 686.8125), .init(x: 1496.7500, y: 685.7500), .init(x: 1495.2500, y: 684.2500), .init(x: 1494.1875, y: 682.6250), .init(x: 1493.5625, y: 680.8750), .init(x: 1493.3750, y: 679.0000), .init(x: 1493.6250, y: 677.0000), .init(x: 1494.3125, y: 674.7500), .init(x: 1495.4375, y: 672.2500), .init(x: 1497.0000, y: 669.5000), .init(x: 1499.0000, y: 666.5000), .init(x: 1500.7500, y: 663.1875), .init(x: 1502.2500, y: 659.5625), .init(x: 1503.5000, y: 655.6250), .init(x: 1504.5000, y: 651.3750), .init(x: 1505.1875, y: 647.1250), .init(x: 1505.5625, y: 642.8750), .init(x: 1505.6250, y: 638.6250), .init(x: 1505.3750, y: 634.3750), .init(x: 1504.8750, y: 630.3125), .init(x: 1504.1250, y: 626.4375), .init(x: 1503.1250, y: 622.7500), .init(x: 1501.8750, y: 619.2500), .init(x: 1500.5625, y: 616.1875), .init(x: 1499.1875, y: 613.5625), .init(x: 1497.7500, y: 611.3750), .init(x: 1496.2500, y: 609.6250), .init(x: 1495.1250, y: 607.8125), .init(x: 1494.3750, y: 605.9375), .init(x: 1494.0000, y: 604.0000), .init(x: 1494.0000, y: 602.0000), .init(x: 1494.3125, y: 600.1875), .init(x: 1494.9375, y: 598.5625), .init(x: 1495.8750, y: 597.1250), .init(x: 1497.1250, y: 595.8750), .init(x: 1498.6250, y: 595.0000), .init(x: 1500.3750, y: 594.5000)],
        [.init(x: 1475.0000, y: 611.0000), .init(x: 1477.0000, y: 611.0000), .init(x: 1478.8125, y: 611.3125), .init(x: 1480.4375, y: 611.9375), .init(x: 1481.8750, y: 612.8750), .init(x: 1483.1250, y: 614.1250), .init(x: 1484.5000, y: 616.1875), .init(x: 1486.0000, y: 619.0625), .init(x: 1487.6250, y: 622.7500), .init(x: 1489.3750, y: 627.2500), .init(x: 1490.6875, y: 631.4375), .init(x: 1491.5625, y: 635.3125), .init(x: 1492.0000, y: 638.8750), .init(x: 1492.0000, y: 642.1250), .init(x: 1491.8125, y: 645.2500), .init(x: 1491.4375, y: 648.2500), .init(x: 1490.8750, y: 651.1250), .init(x: 1490.1250, y: 653.8750), .init(x: 1489.2500, y: 656.5000), .init(x: 1488.2500, y: 659.0000), .init(x: 1487.1250, y: 661.3750), .init(x: 1485.8750, y: 663.6250), .init(x: 1484.6250, y: 665.5000), .init(x: 1483.3750, y: 667.0000), .init(x: 1482.1250, y: 668.1250), .init(x: 1480.8750, y: 668.8750), .init(x: 1479.5000, y: 669.5000), .init(x: 1478.0000, y: 670.0000), .init(x: 1476.3750, y: 670.3750), .init(x: 1474.6250, y: 670.6250), .init(x: 1473.0000, y: 670.5000), .init(x: 1471.5000, y: 670.0000), .init(x: 1470.1250, y: 669.1250), .init(x: 1468.8750, y: 667.8750), .init(x: 1467.9375, y: 666.4375), .init(x: 1467.3125, y: 664.8125), .init(x: 1467.0000, y: 663.0000), .init(x: 1467.0000, y: 661.0000), .init(x: 1467.4375, y: 658.7500), .init(x: 1468.3125, y: 656.2500), .init(x: 1469.6250, y: 653.5000), .init(x: 1471.3750, y: 650.5000), .init(x: 1472.6875, y: 647.5625), .init(x: 1473.5625, y: 644.6875), .init(x: 1474.0000, y: 641.8750), .init(x: 1474.0000, y: 639.1250), .init(x: 1473.5625, y: 636.3125), .init(x: 1472.6875, y: 633.4375), .init(x: 1471.3750, y: 630.5000), .init(x: 1469.6250, y: 627.5000), .init(x: 1468.3125, y: 624.8750), .init(x: 1467.4375, y: 622.6250), .init(x: 1467.0000, y: 620.7500), .init(x: 1467.0000, y: 619.2500), .init(x: 1467.3125, y: 617.7500), .init(x: 1467.9375, y: 616.2500), .init(x: 1468.8750, y: 614.7500), .init(x: 1470.1250, y: 613.2500), .init(x: 1471.5625, y: 612.1250), .init(x: 1473.1875, y: 611.3750)]
    ]
}
