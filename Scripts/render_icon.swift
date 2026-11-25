import AppKit
import CoreGraphics
import Foundation

private let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

private func color(_ rgb: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((rgb >> 16) & 255) / 255,
            green: CGFloat((rgb >> 8) & 255) / 255,
            blue: CGFloat(rgb & 255) / 255,
            alpha: alpha)
}

private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: x, y: y)
}

private func gradient(_ context: CGContext, _ colors: [CGColor], from start: CGPoint, to end: CGPoint) {
    guard let paint = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil) else { return }
    context.drawLinearGradient(paint, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

private func png(size: Int) -> Data? {
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    let scale = CGFloat(size) / 1024
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: scale, y: -scale)
    context.setAllowsAntialiasing(true)
    let frame = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tile = CGPath(roundedRect: frame, cornerWidth: 192, cornerHeight: 192, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: color(0x06204A, alpha: 0.32))
    context.addPath(tile)
    context.setFillColor(color(0x1353A9))
    context.fillPath()
    context.restoreGState()

    context.addPath(tile)
    context.clip()
    gradient(context, [color(0x056EA9), color(0x10478F), color(0x10295C)],
             from: point(135, 125), to: point(886, 958))
    context.addPath(CGPath(roundedRect: frame.insetBy(dx: 2, dy: 2),
                           cornerWidth: 190, cornerHeight: 190, transform: nil))
    context.setLineWidth(4)
    context.setStrokeColor(color(0xB4EDFF, alpha: 0.23))
    context.strokePath()

    let ticket = CGRect(x: 239, y: 339, width: 546, height: 346)
    let cutouts = CGMutablePath()
    cutouts.addRoundedRect(in: ticket, cornerWidth: 65, cornerHeight: 65)
    cutouts.addEllipse(in: CGRect(x: 198, y: 471, width: 82, height: 82))
    cutouts.addEllipse(in: CGRect(x: 744, y: 471, width: 82, height: 82))
    context.saveGState()
    context.addPath(CGPath(roundedRect: ticket, cornerWidth: 65, cornerHeight: 65, transform: nil))
    context.clip()
    context.addPath(cutouts)
    context.clip(using: .evenOdd)
    gradient(context, [color(0xF0FDFF), color(0xBFEAF9)], from: point(512, 350), to: point(512, 696))

    let line = CGMutablePath()
    line.move(to: point(349, 449))
    line.addLine(to: point(439, 490))
    line.addLine(to: point(505, 478))
    line.addLine(to: point(576, 540))
    line.addLine(to: point(666, 570))
    context.addPath(line)
    context.setStrokeColor(color(0x08578D))
    context.setLineWidth(43)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
    context.restoreGState()

    return context.makeImage().flatMap { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) }
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        guard let data = png(size: size * scale) else { fatalError("Could not render icon at \(size * scale) px") }
        let suffix = scale == 1 ? "" : "@2x"
        try data.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
