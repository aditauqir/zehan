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

    NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1).setFill()
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let title = "Drag Zirn to the Applications folder"
    let fontSize = CGFloat(width) * 0.048
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
        .foregroundColor: NSColor(white: 0.88, alpha: 1),
    ]
    let titleSize = (title as NSString).size(withAttributes: attrs)
    (title as NSString).draw(
        at: CGPoint(x: (CGFloat(width) - titleSize.width) / 2, y: CGFloat(height) * 0.14),
        withAttributes: attrs
    )

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
writePNG(drawBackground(width: 480, height: 480), to: packaging.appendingPathComponent("dmg-background.png"))
writePNG(drawBackground(width: 960, height: 960), to: packaging.appendingPathComponent("dmg-background@2x.png"))
print("Wrote DMG background text assets.")
