import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConverterView: View {
    @ObservedObject var model: AppModel
    @State private var dropTargeted = false
    @State private var optionsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if model.ffmpeg == nil { missingFFmpeg }
            fileList
            destinationControls
            DisclosureGroup("Options", isExpanded: $optionsExpanded) {
                ScrollView {
                    ConversionOptionsView(format: model.format, options: $model.options)
                        .padding(.top, 12)
                        .padding(.trailing, 6)
                }.frame(height: 210)
            }.disabled(model.busy)
            if let error = model.optionsError {
                Text(error).foregroundStyle(.red)
            }
            footer
        }
        .font(.system(size: 13))
        .controlSize(.regular)
        .padding(20)
        .frame(width: 570)
    }

    private var header: some View {
        HStack {
            Text("Image Converter").fontWeight(.semibold)
            Spacer()
            Button("Add Images…") { model.pickFiles() }.disabled(model.busy)
        }
    }

    private var missingFFmpeg: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Install FFmpeg with Homebrew to convert images.")
            HStack {
                Text("brew install ffmpeg").textSelection(.enabled)
                Spacer()
                Button("Check Again") { model.refreshFFmpeg() }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var fileList: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(dropTargeted ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
            if model.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Drop images here, or add them above")
                }.foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.items) { item in
                            QueueItemView(
                                item: item,
                                busy: model.busy,
                                requeue: { model.requeue(item.id) },
                                remove: { model.remove(item.id) }
                            )
                        }
                    }.padding(12)
                }
            }
        }
        .frame(height: 200)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dropTargeted) { providers in
            guard !model.busy else { return false }
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in model.add([url]) }
                }
            }
            return true
        }
    }

    private var destinationControls: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Format", selection: $model.format) {
                    ForEach(ImageFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }.frame(width: 190)
                Spacer()
                Text("\(model.pendingCount) pending").foregroundStyle(.secondary)
                Button("Clear All") { model.clear() }.disabled(model.items.isEmpty)
            }
            HStack {
                Text("Save to")
                Text(model.directory?.lastPathComponent ?? "Original folders")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(model.directory?.path ?? "Save alongside each original")
                Spacer()
                Button("Choose…") { model.pickFolder() }
                if model.directory != nil {
                    Button("Reset") { model.directory = nil }
                }
            }
        }.disabled(model.busy)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            if model.busy {
                ProgressView(value: Double(model.completed), total: Double(max(model.batchCount, 1)))
            }
            HStack {
                Text(model.busy ? "\(model.completed) of \(model.batchCount) complete" : model.message)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.busy {
                    Button("Cancel") { model.cancel() }
                } else {
                    Button("Convert \(model.pendingCount) Image\(model.pendingCount == 1 ? "" : "s")") {
                        Task { await model.convertPending() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.pendingCount == 0 || model.ffmpeg == nil || model.optionsError != nil)
                }
            }
            Text(model.shortcutMessage).foregroundStyle(.secondary)
        }
    }
}

private struct QueueItemView: View {
    let item: QueueItem
    let busy: Bool
    let requeue: () -> Void
    let remove: () -> Void
    @State private var showingError = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.state.output == nil ? "photo" : "checkmark.circle")
                .foregroundStyle(item.state.output == nil ? Color.secondary : .green)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.url.lastPathComponent).lineLimit(1).help(item.url.path)
                Text(item.state.label).foregroundStyle(.secondary).lineLimit(1).help(item.state.label)
                if case .failed(let details) = item.state {
                    Button("Error Details") { showingError = true }
                        .popover(isPresented: $showingError) {
                            ScrollView { Text(details).textSelection(.enabled).padding() }
                                .frame(width: 400, height: 200)
                        }
                }
            }
            Spacer(minLength: 0)
            if let output = item.state.output {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([output])
                } label: {
                    Image(systemName: "magnifyingglass")
                }.help("Show in Finder").accessibilityLabel("Show in Finder")
            }
            if item.state != .ready && item.state != .converting {
                Button(action: requeue) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Convert Again")
                .accessibilityLabel("Convert Again")
                .disabled(busy)
            }
            Button(action: remove) {
                Image(systemName: "xmark")
            }
            .help("Remove from list")
            .accessibilityLabel("Remove from list")
            .disabled(busy)
        }.buttonStyle(.borderless)
    }
}
