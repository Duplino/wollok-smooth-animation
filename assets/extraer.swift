import Foundation
import ImageIO
import UniformTypeIdentifiers

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let nombre = url.deletingPathExtension().lastPathComponent
let carpeta = url.deletingLastPathComponent()

guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
    print("No se pudo abrir \(url.path)"); exit(1)
}

let n = CGImageSourceGetCount(src)
var total = 0.0

for i in 0..<n {
    guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
    let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
    let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
    let d = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
         ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0
    total += d

    let out = carpeta.appendingPathComponent("\(nombre)_\(i).png")
    guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    print("\(out.lastPathComponent)  \(Int(d * 1000)) ms")
}

print("Total: \(Int(total * 1000)) ms en \(n) frames")