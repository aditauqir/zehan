#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let packaging = root.appendingPathComponent("packaging", isDirectory: true)

func drawBackground(width: Int, height: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("No context") }

    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)

    let top = NSColor(red: 0.10, green: 0.16, blue: 0.28, alpha: 1)
    let bottom = NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1)
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [top.cgColor, bottom.cgColor] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: width / 2, y: 0), end: CGPoint(x: width / 2, y: height), options: [])

    let title = "Drag Zirn to Applications"
    let fontSize = CGFloat(width) * 0.042
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
        .foregroundColor: NSColor(white: 0.94, alpha: 0.95),
    ]
    let titleSize = (title as NSString).size(withAttributes: attrs)
    (title as NSString).draw(
        at: CGPoint(x: (CGFloat(width) - titleSize.width) / 2, y: CGFloat(height) * 0.12),
        withAttributes: attrs
    )

    let arrowY = CGFloat(height) * 0.34
    let startX = CGFloat(width) * 0.68
    let endX = CGFloat(width) * 0.32
    ctx.setStrokeColor(NSColor(white: 0.92, alpha: 0.85).cgColor)
    ctx.setLineWidth(max(2, CGFloat(width) * 0.006))
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: startX, y: arrowY))
    ctx.addCurve(
        to: CGPoint(x: endX, y: arrowY),
        control1: CGPoint(x: startX - CGFloat(width) * 0.12, y: arrowY - CGFloat(height) * 0.08),
        control2: CGPoint(x: endX + CGFloat(width) * 0.12, y: arrowY + CGFloat(height) * 0.08)
    )
    ctx.strokePath()

    let head = CGFloat(width) * 0.025
    ctx.move(to: CGPoint(x: endX, y: arrowY))
    ctx.addLine(to: CGPoint(x: endX + head, y: arrowY - head * 0.9))
    ctx.move(to: CGPoint(x: endX, y: arrowY))
    ctx.addLine(to: CGPoint(x: endX + head, y: arrowY + head * 0.9))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    try! data.write(to: url)
}

try FileManager.default.createDirectory(at: packaging, withIntermediateDirectories: true)
writePNG(drawBackground(width: 660, height: 400), to: packaging.appendingPathComponent("dmg-background.png"))
writePNG(drawBackground(width: 1320, height: 800), to: packaging.appendingPathComponent("dmg-background@2x.png"))
print("Wrote \(packaging.path)/dmg-background.png")
print("Wrote \(packaging.path)/dmg-background@2x.png")
