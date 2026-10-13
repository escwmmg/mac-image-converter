import Foundation

enum ResizeMode: String, CaseIterable, Identifiable {
    case original = "Original size"
    case longestEdge = "Limit longest edge"
    case fit = "Fit within dimensions"

    var id: Self { self }
}

enum TIFFCompression: String, CaseIterable, Identifiable {
    case packbits = "PackBits"
    case lzw = "LZW"
    case deflate = "Deflate"
    case raw = "None"

    var id: Self { self }
    var encoderValue: String {
        switch self {
        case .packbits: return "packbits"
        case .lzw: return "lzw"
        case .deflate: return "deflate"
        case .raw: return "raw"
        }
    }
}

struct ConversionOptions: Equatable {
    var resize: ResizeMode = .original
    var longestEdge = 1920
    var width = 1920
    var height = 1080
    var allowUpscaling = false
    var jpegQuality = 90
    var webpLossless = true
    var webpQuality = 85
    var pngCompression = 6
    var tiffCompression: TIFFCompression = .packbits
    var tiffDPI = 72
    var gifColors = 256
    var gifDither = true
    var tgaCompression = true

    func validate(for format: ImageFormat) throws {
        switch resize {
        case .original:
            break
        case .longestEdge:
            try check(longestEdge, in: 1...16384, name: "Longest edge")
        case .fit:
            try check(width, in: 1...16384, name: "Width")
            try check(height, in: 1...16384, name: "Height")
        }
        switch format {
        case .jpeg: try check(jpegQuality, in: 1...100, name: "JPEG quality")
        case .webp: try check(webpQuality, in: 1...100, name: "WebP quality")
        case .png: try check(pngCompression, in: 0...9, name: "PNG compression")
        case .tiff: try check(tiffDPI, in: 1...65536, name: "TIFF resolution")
        case .gif: try check(gifColors, in: 4...256, name: "GIF colors")
        case .bmp, .tga: break
        }
    }

    func arguments(for format: ImageFormat) throws -> [String] {
        try validate(for: format)
        var arguments: [String]
        switch format {
        case .png:
            arguments = ["-c:v", "png", "-compression_level", String(pngCompression)]
        case .jpeg:
            let quantizer = 2 + Int((Double(100 - jpegQuality) * 29 / 99).rounded())
            arguments = ["-c:v", "mjpeg", "-q:v", String(quantizer), "-pix_fmt", "yuvj444p"]
        case .webp:
            arguments = ["-c:v", "libwebp", "-lossless", webpLossless ? "1" : "0", "-quality", String(webpQuality)]
        case .tiff:
            arguments = ["-c:v", "tiff", "-compression_algo", tiffCompression.encoderValue, "-dpi", String(tiffDPI)]
        case .bmp:
            arguments = ["-c:v", "bmp", "-pix_fmt", "bgr24"]
        case .gif:
            arguments = ["-c:v", "gif"]
        case .tga:
            arguments = ["-c:v", "targa", "-rle", tgaCompression ? "1" : "0"]
        }
        var filters = resizeFilter.map { [$0] } ?? []
        if format == .gif {
            let dither = gifDither ? "sierra2_4a" : "none"
            filters.append("split[paletteInput][pixels];[paletteInput]palettegen=max_colors=\(gifColors)[palette];[pixels][palette]paletteuse=dither=\(dither)")
        }
        if !filters.isEmpty {
            arguments += ["-vf", filters.joined(separator: ",")]
        }
        return arguments
    }

    private var resizeFilter: String? {
        guard resize != .original else { return nil }
        let maxWidth = resize == .longestEdge ? longestEdge : width
        let maxHeight = resize == .longestEdge ? longestEdge : height
        let factor = "min(\(maxWidth)/iw,\(maxHeight)/ih)"
        let boundedFactor = allowUpscaling ? factor : "min(1,\(factor))"
        return "scale=w='max(1,floor(iw*\(boundedFactor)))':h='max(1,floor(ih*\(boundedFactor)))':flags=lanczos,setsar=1"
    }

    private func check(_ value: Int, in range: ClosedRange<Int>, name: String) throws {
        guard range.contains(value) else {
            throw ConversionFailure(message: "\(name) must be between \(range.lowerBound) and \(range.upperBound).")
        }
    }
}
