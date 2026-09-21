// Offline, native type-mask authoring. No supplied bitmap is modified by this step.
import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 2048, height = 1292
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let text = NSAttributedString(string: "SANTIAGO D FERNANDEZ", attributes: [
    .font: NSFont.systemFont(ofSize: 70, weight: .regular),
    .foregroundColor: NSColor.white, .kern: 2.0])
context.textPosition = CGPoint(x: 78, y: height - 1157)
CTLineDraw(CTLineCreateWithAttributedString(text), context)
let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination), "Cannot write native holder mask")
