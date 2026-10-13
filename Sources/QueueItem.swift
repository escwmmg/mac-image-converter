import Foundation

enum ConversionState: Equatable {
    case ready
    case converting
    case succeeded(URL)
    case failed(String)
    case cancelled

    var output: URL? {
        if case .succeeded(let url) = self { return url }
        return nil
    }

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .converting: return "Converting…"
        case .succeeded(let url): return "Saved: \(url.lastPathComponent)"
        case .failed: return "Conversion failed"
        case .cancelled: return "Cancelled"
        }
    }
}

struct QueueItem: Identifiable {
    let id = UUID()
    let url: URL
    var state: ConversionState = .ready
}
