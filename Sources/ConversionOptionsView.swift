import SwiftUI

struct ConversionOptionsView: View {
    let format: ImageFormat
    @Binding var options: ConversionOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Size", selection: $options.resize) {
                ForEach(ResizeMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            if options.resize == .longestEdge {
                numberField("Longest edge (px)", value: $options.longestEdge)
            } else if options.resize == .fit {
                numberField("Maximum width (px)", value: $options.width)
                numberField("Maximum height (px)", value: $options.height)
            }
            if options.resize != .original {
                Toggle("Allow upscaling", isOn: $options.allowUpscaling)
                Text("Keeps proportions; no cropping or stretching.").foregroundStyle(.secondary)
            }
            Divider()
            formatSettings
            Divider()
            HStack {
                Text("Applies to pending images only.").foregroundStyle(.secondary)
                Spacer()
                Button("Reset Options") { options = ConversionOptions() }
            }
            Text("Originals are kept. Animated images use the first frame. Metadata and color profiles may not be preserved.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var formatSettings: some View {
        switch format {
        case .png:
            integerSlider("Compression", value: $options.pngCompression, range: 0...9)
            Text("Lossless at every level. Higher compression takes longer.").foregroundStyle(.secondary)
        case .jpeg:
            integerSlider("Quality", value: $options.jpegQuality, range: 1...100)
            Text("Higher quality usually produces larger files. Transparency is removed.").foregroundStyle(.secondary)
        case .webp:
            Toggle("Lossless", isOn: $options.webpLossless)
            if !options.webpLossless {
                integerSlider("Quality", value: $options.webpQuality, range: 1...100)
            }
        case .tiff:
            Picker("Compression", selection: $options.tiffCompression) {
                ForEach(TIFFCompression.allCases) { compression in
                    Text(compression.rawValue).tag(compression)
                }
            }
            numberField("Resolution (DPI)", value: $options.tiffDPI)
            Text("DPI sets print resolution; it does not resize pixels.").foregroundStyle(.secondary)
        case .gif:
            numberField("Palette colors (4–256)", value: $options.gifColors)
            Toggle("Dither colors", isOn: $options.gifDither)
        case .tga:
            Toggle("Run-length compression", isOn: $options.tgaCompression)
        case .bmp:
            Text("Uncompressed 24-bit color. Transparency is removed.").foregroundStyle(.secondary)
        }
    }

    private func numberField(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.grouping(.never))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
        }
    }

    private func integerSlider(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title).frame(width: 90, alignment: .leading)
            Slider(
                value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0) }),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            ).accessibilityLabel(title)
            Text(String(value.wrappedValue)).monospacedDigit().frame(width: 28, alignment: .trailing)
        }
    }
}
