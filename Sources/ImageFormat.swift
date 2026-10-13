import Foundation

enum ImageFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case webp = "WebP"
    case tiff = "TIFF"
    case bmp = "BMP"
    case gif = "GIF"
    case tga = "TGA"

    var id: Self { self }
    var suffix: String { self == .jpeg ? "jpg" : rawValue.lowercased() }
}
