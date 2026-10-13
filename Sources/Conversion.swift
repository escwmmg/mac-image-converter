import Foundation

struct ConversionFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class Converter {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    static func findFFmpeg() -> URL? {
        let paths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"] +
            (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/ffmpeg" }
        return paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        if let process, process.isRunning { process.terminate() }
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func convert(
        _ input: URL,
        format: ImageFormat,
        directory: URL?,
        executable: URL,
        options: ConversionOptions = ConversionOptions()
    ) throws -> URL {
        if isCancelled { throw ConversionFailure(message: "Cancelled") }
        let encodingArguments = try options.arguments(for: format)
        let folder = directory ?? input.deletingLastPathComponent()
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("ImageConverter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let safeInput = scratch.appendingPathComponent("input").appendingPathExtension(input.pathExtension)
        try FileManager.default.createSymbolicLink(at: safeInput, withDestinationURL: input)
        let temporary = folder.appendingPathComponent(".image-converter-\(UUID().uuidString).\(format.suffix)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let task = Process()
        task.executableURL = executable
        task.arguments = ["-hide_banner", "-loglevel", "error", "-nostdin", "-n", "-i", safeInput.path,
                          "-map", "0:v:0", "-frames:v", "1", "-threads", "1"] + encodingArguments +
                          ["-f", "image2", "-update", "1", temporary.path]
        let errors = Pipe()
        task.standardError = errors
        task.standardOutput = FileHandle.nullDevice
        task.standardInput = FileHandle.nullDevice
        lock.lock()
        if cancelled {
            lock.unlock()
            throw ConversionFailure(message: "Cancelled")
        }
        do {
            try task.run()
            process = task
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        lock.lock()
        process = nil
        lock.unlock()
        if isCancelled { throw ConversionFailure(message: "Cancelled") }
        guard task.terminationStatus == 0 else {
            let detail = String(data: errorData, encoding: .utf8) ?? "FFmpeg failed."
            throw ConversionFailure(message: String(detail.suffix(3000)))
        }
        let stem = input.deletingPathExtension().lastPathComponent
        for number in 1...10000 {
            let tail = number == 1 ? "" : "-\(number)"
            let output = folder.appendingPathComponent("\(stem)-converted\(tail).\(format.suffix)")
            do {
                try FileManager.default.linkItem(at: temporary, to: output)
                return output
            } catch {
                if FileManager.default.fileExists(atPath: output.path) { continue }
                throw error
            }
        }
        throw ConversionFailure(message: "Too many files with the same name. Choose another output folder.")
    }
}
