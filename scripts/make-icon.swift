import AppKit

// Renders the canonical app icon from assets/icon.png.
let size: CGFloat = 1024
let sourcePath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "assets/icon.png"

guard let source = NSImage(contentsOfFile: sourcePath) else {
    FileHandle.standardError.write(Data("failed to load icon source: \(sourcePath)\n".utf8))
    exit(1)
}

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
source.draw(
    in: NSRect(x: 0, y: 0, width: size, height: size),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to render icon\n".utf8))
    exit(1)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/agentbuddy-icon-1024.png"
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
