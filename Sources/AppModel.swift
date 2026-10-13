import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var items: [QueueItem] = []
    @Published var format: ImageFormat = .png
    @Published var options = ConversionOptions()
    @Published var directory: URL?
    @Published private(set) var busy = false
    @Published private(set) var completed = 0
    @Published private(set) var batchCount = 0
    @Published private(set) var message = ""
    @Published var shortcutMessage = "Open anytime: ⌃⌥⌘I"
    @Published private(set) var ffmpeg = Converter.findFFmpeg()

    private var converter: Converter?

    var pendingCount: Int { items.filter { $0.state == .ready }.count }

    var optionsError: String? {
        do {
            try options.validate(for: format)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func refreshFFmpeg() {
        ffmpeg = Converter.findFFmpeg()
    }

    func add(_ urls: [URL]) {
        guard !busy else {
            message = "Finish or cancel this batch before adding more images."
            return
        }
        var rejected = 0
        for url in urls {
            let suffix = url.pathExtension.lowercased()
            let knownImage = ["png", "jpg", "jpeg", "webp", "tif", "tiff", "bmp", "gif", "tga"].contains(suffix)
            let isImage = knownImage || UTType(filenameExtension: suffix)?.conforms(to: .image) == true
            guard url.isFileURL, isImage,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                rejected += 1
                continue
            }
            if let index = items.firstIndex(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
                items[index].state = .ready
            } else {
                items.append(QueueItem(url: url))
            }
        }
        message = rejected > 0 ? "Skipped \(rejected) item(s) that are not image files." : ""
    }

    func requeue(_ id: UUID) {
        guard !busy else { return }
        update(id, state: .ready)
        message = ""
    }

    func remove(_ id: UUID) {
        guard !busy else { return }
        items.removeAll { $0.id == id }
    }

    func clear() {
        guard !busy else { return }
        items.removeAll()
        message = ""
    }

    func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { add(panel.urls) }
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK { directory = panel.url }
    }

    func convertPending() async {
        guard !busy else { return }
        refreshFFmpeg()
        guard let executable = ffmpeg, optionsError == nil else { return }
        let batch = items.filter { $0.state == .ready }
        guard !batch.isEmpty else { return }

        let worker = Converter()
        let target = format
        let settings = options
        let folder = directory
        converter = worker
        busy = true
        completed = 0
        batchCount = batch.count
        message = ""
        defer {
            busy = false
            converter = nil
        }

        var successes = 0
        var failures = 0
        for item in batch {
            guard !worker.isCancelled else {
                update(item.id, state: .cancelled)
                continue
            }
            update(item.id, state: .converting)
            do {
                let output = try await Task.detached(priority: .userInitiated) {
                    try worker.convert(item.url, format: target, directory: folder, executable: executable, options: settings)
                }.value
                update(item.id, state: .succeeded(output))
                successes += 1
            } catch {
                if worker.isCancelled {
                    update(item.id, state: .cancelled)
                } else {
                    update(item.id, state: .failed(error.localizedDescription))
                    failures += 1
                }
            }
            completed += 1
        }
        message = "\(successes) saved" + (failures > 0 ? " · \(failures) failed" : "") +
            (worker.isCancelled ? " · Cancelled" : "")
    }

    func cancel() {
        converter?.cancel()
    }

    private func update(_ id: UUID, state: ConversionState) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = state
    }
}
