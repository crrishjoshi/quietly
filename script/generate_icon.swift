import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_icon.swift <output.png>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 1024,
        pixelsHigh: 1024,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ),
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    fputs("Could not create drawing context\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
defer { NSGraphicsContext.restoreGraphicsState() }

let context = graphicsContext.cgContext
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.clear(CGRect(x: 0, y: 0, width: 1024, height: 1024))

let outerRect = NSRect(x: 72, y: 72, width: 880, height: 880)
let outerPath = NSBezierPath(
    roundedRect: outerRect,
    xRadius: 224,
    yRadius: 224
)

NSGradient(
    colors: [
        NSColor(red: 0.34, green: 0.29, blue: 0.88, alpha: 1),
        NSColor(red: 0.25, green: 0.52, blue: 0.91, alpha: 1),
        NSColor(red: 0.16, green: 0.69, blue: 0.66, alpha: 1)
    ]
)?.draw(in: outerPath, angle: -42)

NSColor.white.withAlphaComponent(0.14).setStroke()
outerPath.lineWidth = 4
outerPath.stroke()

for (diameter, alpha) in [(650.0, 0.055), (500.0, 0.075), (350.0, 0.10)] {
    let circle = NSBezierPath(
        ovalIn: NSRect(
            x: (1024 - diameter) / 2,
            y: (1024 - diameter) / 2,
            width: diameter,
            height: diameter
        )
    )
    NSColor.white.withAlphaComponent(alpha).setStroke()
    circle.lineWidth = 10
    circle.stroke()
}

let symbolConfiguration = NSImage.SymbolConfiguration(
    pointSize: 368,
    weight: .semibold
).applying(
    NSImage.SymbolConfiguration(paletteColors: [.white])
)

guard
    let baseSymbol = NSImage(
        systemSymbolName: "speaker.wave.2.fill",
        accessibilityDescription: "Quietly"
    ),
    let symbol = baseSymbol.withSymbolConfiguration(symbolConfiguration)
else {
    fputs("Could not load SF Symbol\n", stderr)
    exit(1)
}

let symbolSize = symbol.size
let symbolRect = NSRect(
    x: (1024 - symbolSize.width) / 2,
    y: (1024 - symbolSize.height) / 2 - 4,
    width: symbolSize.width,
    height: symbolSize.height
)
symbol.draw(in: symbolRect)

graphicsContext.flushGraphics()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode icon\n", stderr)
    exit(1)
}

try png.write(to: outputURL, options: .atomic)
