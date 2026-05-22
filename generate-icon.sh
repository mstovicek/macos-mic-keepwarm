#!/usr/bin/env swift
// generate-icon.sh
// Generates Sources/MicWarmApp/Resources/AppIcon.icns from SF Symbols.
// Run: swift generate-icon.sh
// Requirements: macOS 13+, Xcode Command Line Tools
//
// The icon uses SF Symbols (mic.fill on a blue rounded-rect background).
// SF Symbols are available for use in app icons per Apple's SF Symbols license:
// https://developer.apple.com/sf-symbols/

import AppKit
import Foundation

let sizes: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

// Resolve paths relative to this script's location so it works from any working directory.
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()
    .standardized
let fm = FileManager.default
let iconsetURL = scriptDir.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconsetURL)
try fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func renderIcon(px: Int) -> NSImage {
    let size = NSSize(width: px, height: px)
    let image = NSImage(size: size)
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(origin: .zero, size: CGSize(width: px, height: px))

    // Blue rounded-rect background
    let corner = CGFloat(px) * 0.22
    let bgPath = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    ctx.setFillColor(NSColor(red: 0.20, green: 0.47, blue: 0.96, alpha: 1.0).cgColor)
    ctx.addPath(bgPath)
    ctx.fillPath()

    // White mic.fill SF Symbol centered
    let symPx = CGFloat(px) * 0.55
    let symConfig = NSImage.SymbolConfiguration(pointSize: symPx * 0.72, weight: .medium)
    if let sym = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symConfig) {
        sym.isTemplate = false
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        NSColor.white.set()
        let symRect = NSRect(origin: .zero, size: sym.size)
        sym.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        tinted.unlockFocus()

        let x = (CGFloat(px) - tinted.size.width) / 2
        let y = (CGFloat(px) - tinted.size.height) / 2
        tinted.draw(at: NSPoint(x: x, y: y), from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

for (logicalSize, scale) in sizes {
    let px = logicalSize * scale
    let img = renderIcon(px: px)
    let filename = scale == 1
        ? "icon_\(logicalSize)x\(logicalSize).png"
        : "icon_\(logicalSize)x\(logicalSize)@2x.png"
    let dest = iconsetURL.appendingPathComponent(filename)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to render \(filename)")
        exit(1)
    }
    try png.write(to: dest)
    print("  \(filename)")
}

let outputPath = scriptDir
    .appendingPathComponent("Sources/MicWarmApp/Resources/AppIcon.icns")
    .path
let result = Process()
result.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
result.arguments = ["-c", "icns", "-o", outputPath, iconsetURL.path]
try result.run()
result.waitUntilExit()

try fm.removeItem(at: iconsetURL)

if result.terminationStatus == 0 {
    print("Generated \(outputPath)")
} else {
    print("iconutil failed")
    exit(1)
}
