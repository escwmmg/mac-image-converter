import Foundation
import AppKit

@main
enum ConversionTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw ConversionFailure(message: "TEST FAILED: \(message)") }
    }

    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        guard let executable = Converter.findFFmpeg() else { throw ConversionFailure(message: "Install FFmpeg before testing.") }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ImageConverterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 17, pixelsHigh: 13, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for row in 0..<13 {
            for column in 0..<17 {
                bitmap.setColor(NSColor(calibratedRed: CGFloat(column) / 17, green: CGFloat(row) / 13, blue: 0.5, alpha: 0.7), atX: column, y: row)
            }
        }
        let original = bitmap.representation(using: .png, properties: [:])!
        let input = folder.appendingPathComponent("a space ' 日本語 %03d.png")
        try original.write(to: input)
        for format in ImageFormat.allCases {
            let output = try Converter().convert(input, format: format, directory: nil, executable: executable)
            try require(output.pathExtension == format.suffix, "Correct extension")
            let decoder = Process()
            decoder.executableURL = executable
            let decodeInput = folder.appendingPathComponent("decode.\(format.suffix)")
            try FileManager.default.createSymbolicLink(at: decodeInput, withDestinationURL: output)
            decoder.arguments = ["-v", "error", "-i", decodeInput.path, "-f", "null", "-"]
            decoder.standardOutput = FileHandle.nullDevice
            try decoder.run()
            decoder.waitUntilExit()
            try require(decoder.terminationStatus == 0, "\(format.rawValue) output decodes")
            print("PASS: \(format.rawValue) conversion and decode")
        }
        let duplicate = try Converter().convert(input, format: .png, directory: nil, executable: executable)
        try require(duplicate.lastPathComponent.hasSuffix("-converted-2.png"), "Collision gets a new filename")
        let unchanged = try Data(contentsOf: input)
        try require(unchanged == original, "Original untouched")
        print("PASS: collision naming and original preservation")
        let custom = folder.appendingPathComponent("Custom")
        try FileManager.default.createDirectory(at: custom, withIntermediateDirectories: true)
        let customOutput = try Converter().convert(input, format: .png, directory: custom, executable: executable)
        try require(customOutput.deletingLastPathComponent().path == custom.path, "Custom output folder")
        let corrupt = folder.appendingPathComponent("corrupt.png")
        try Data("invalid image".utf8).write(to: corrupt)
        do {
            _ = try Converter().convert(corrupt, format: .png, directory: nil, executable: executable)
            throw ConversionFailure(message: "TEST FAILED: corrupt input accepted")
        } catch let error as ConversionFailure {
            try require(!error.message.contains("TEST FAILED"), "Corrupt image rejected")
        }
        let cancelled = Converter()
        cancelled.cancel()
        do {
            _ = try cancelled.convert(input, format: .png, directory: nil, executable: executable)
            throw ConversionFailure(message: "TEST FAILED: cancelled job ran")
        } catch let error as ConversionFailure {
            try require(error.message == "Cancelled", "Cancellation reported")
        }
        let sleeper = folder.appendingPathComponent("slow-encoder")
        try Data("#!/bin/sh\nexec /bin/sleep 30\n".utf8).write(to: sleeper)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sleeper.path)
        let running = Converter()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { running.cancel() }
        let start = Date()
        do {
            _ = try running.convert(input, format: .png, directory: nil, executable: sleeper)
            throw ConversionFailure(message: "TEST FAILED: cancelled process succeeded")
        } catch let error as ConversionFailure {
            try require(error.message == "Cancelled", "Active process cancellation reported")
        }
        try require(Date().timeIntervalSince(start) < 5, "Active process terminated promptly")
        let remaining = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        try require(!remaining.contains(where: { $0.hasPrefix(".image-converter-") }), "Temporary files cleaned up")
        print("PASS: custom output, invalid input, cancellation, cleanup")
        try testOptions(input: input, executable: executable)
        try await testQueue(input: input, corrupt: corrupt, folder: folder)
        print("All conversion tests passed.")
    }

    static func testOptions(input: URL, executable: URL) throws {
        var options = ConversionOptions()
        options.resize = .longestEdge
        options.longestEdge = 10
        let resized = try Converter().convert(input, format: .png, directory: nil, executable: executable, options: options)
        let bitmap = NSBitmapImageRep(data: try Data(contentsOf: resized))!
        try require(bitmap.pixelsWide == 10 && bitmap.pixelsHigh == 7, "Longest-edge resize preserves proportions")

        options.resize = .fit
        options.width = 8
        options.height = 5
        let fitted = try Converter().convert(input, format: .png, directory: nil, executable: executable, options: options)
        let fittedBitmap = NSBitmapImageRep(data: try Data(contentsOf: fitted))!
        try require(fittedBitmap.pixelsWide == 6 && fittedBitmap.pixelsHigh == 5, "Fit respects both bounds")

        options.width = 34
        options.height = 26
        let unchanged = try Converter().convert(input, format: .png, directory: nil, executable: executable, options: options)
        let unchangedBitmap = NSBitmapImageRep(data: try Data(contentsOf: unchanged))!
        try require(unchangedBitmap.pixelsWide == 17 && unchangedBitmap.pixelsHigh == 13, "Upscaling disabled by default")
        options.allowUpscaling = true
        let enlarged = try Converter().convert(input, format: .png, directory: nil, executable: executable, options: options)
        let enlargedBitmap = NSBitmapImageRep(data: try Data(contentsOf: enlarged))!
        try require(enlargedBitmap.pixelsWide == 34 && enlargedBitmap.pixelsHigh == 26, "Explicit upscaling")

        options.jpegQuality = 40
        options.webpLossless = false
        options.webpQuality = 60
        options.pngCompression = 9
        options.tiffCompression = .lzw
        options.tiffDPI = 300
        options.gifColors = 16
        options.gifDither = false
        options.tgaCompression = false
        for format in ImageFormat.allCases {
            let output = try Converter().convert(input, format: format, directory: nil, executable: executable, options: options)
            try checkDecoding(output, executable: executable)
        }
        for compression in TIFFCompression.allCases {
            options.tiffCompression = compression
            let output = try Converter().convert(input, format: .tiff, directory: nil, executable: executable, options: options)
            try checkDecoding(output, executable: executable)
        }
        options.width = 0
        do {
            _ = try Converter().convert(input, format: .png, directory: nil, executable: executable, options: options)
            throw ConversionFailure(message: "TEST FAILED: invalid width accepted")
        } catch let error as ConversionFailure {
            try require(error.message.contains("Width must be"), "Invalid dimensions rejected before encoding")
        }
        print("PASS: resizing, upscaling, format options, and validation")
    }

    @MainActor static func testQueue(input: URL, corrupt: URL, folder: URL) async throws {
        let model = AppModel()
        model.add([input])
        try require(model.items.count == 1, "Input accepted: \(model.message)")
        await model.convertPending()
        try require(model.pendingCount == 0, "Completed image leaves pending queue")
        let firstOutput = model.items[0].state.output
        try require(firstOutput != nil, "First batch succeeded")

        let second = folder.appendingPathComponent("second.png")
        try FileManager.default.copyItem(at: input, to: second)
        model.add([second])
        try require(model.pendingCount == 1 && model.items.count == 2, "Only the newly added image is pending")
        await model.convertPending()
        try require(model.batchCount == 1 && model.completed == 1, "Second batch processes exactly one image")
        try require(model.items[0].state.output == firstOutput, "Second batch never reconverts the first image")
        try require(model.items[1].state.output != nil, "Second image saved")

        model.format = .jpeg
        model.options.jpegQuality = 75
        await model.convertPending()
        try require(model.pendingCount == 0 && model.items[0].state.output == firstOutput, "Option changes do not requeue completed files")
        model.requeue(model.items[0].id)
        try require(model.pendingCount == 1, "Explicit Convert Again requeues one image")
        await model.convertPending()
        try require(model.items[0].state.output?.pathExtension == "jpg", "Convert Again uses new settings")

        model.add([corrupt])
        await model.convertPending()
        try require(model.pendingCount == 0, "Failure requires an explicit retry")
        guard case .failed = model.items.last?.state else {
            throw ConversionFailure(message: "TEST FAILED: failed queue state missing")
        }
        model.requeue(model.items.last!.id)
        try require(model.pendingCount == 1, "Failure can be retried")
        model.remove(model.items.last!.id)
        try require(model.pendingCount == 0, "Removing pending image updates count")
        model.add([input, input])
        try require(model.pendingCount == 1 && model.items.count == 2, "Re-adding an existing image is explicit and deduplicated")
        print("PASS: completed/new-file queue regression, requeue, retry, and removal")
    }

    static func checkDecoding(_ output: URL, executable: URL) throws {
        let alias = output.deletingLastPathComponent().appendingPathComponent(UUID().uuidString).appendingPathExtension(output.pathExtension)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: output)
        defer { try? FileManager.default.removeItem(at: alias) }
        let decoder = Process()
        decoder.executableURL = executable
        decoder.arguments = ["-v", "error", "-i", alias.path, "-f", "null", "-"]
        decoder.standardOutput = FileHandle.nullDevice
        try decoder.run()
        decoder.waitUntilExit()
        try require(decoder.terminationStatus == 0, "Configured \(output.pathExtension) output decodes")
    }
}
