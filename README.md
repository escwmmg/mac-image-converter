# Image Converter

A native macOS menu bar utility for batch image conversion with FFmpeg. Supports PNG, JPEG, WebP, TIFF, BMP, GIF, and TGA, with per-format settings and a Finder Quick Action. All processing stays on the Mac.

Requires an Apple Silicon Mac with macOS 13 or later and FFmpeg. Building from source also requires Apple's Command Line Tools.

## Install

1. Install [Homebrew](https://brew.sh), then run `brew install ffmpeg`. The app displays instructions if FFmpeg is missing.
2. Run `./install.command` from the project folder, or double-click it in Finder. It builds the app if needed, installs it in `~/Applications`, installs the Finder Quick Action in `~/Library/Services`, and opens the app. No administrator password is required. Run `xcode-select --install` first if the Command Line Tools are missing.
3. Click the image icon at the top right of the menu bar, or press **Control–Option–Command–I** while the app is running.

This is a locally built, ad-hoc signed app, not an Apple-notarized download. If macOS blocks a transferred copy, use System Settings → Privacy & Security → Open Anyway for this app, or build it locally with **build.command**. Do not disable Gatekeeper.

## Convert images

- Click **Add Images…**, or drag one or more images into the window.
- Choose PNG, JPEG, WebP, TIFF, BMP, GIF, or TGA and click **Convert**.
- Only pending images are converted. Completed images remain visible for reference and are excluded from subsequent batches. Click the circular arrow on a row, or explicitly add the same file again, to convert it again. Failed and cancelled images also require an explicit retry.
- Expand **Options** for resizing and format-specific settings. Changes apply to the next batch; they do not requeue completed images.
- Outputs are saved alongside each original, or in a folder you choose. Names use `photo-converted.png`, then `photo-converted-2.png` and so on. Existing files are never overwritten.
- Progress counts completed files. Each row shows its result or error. Use the magnifying glass to reveal an output in Finder. Cancel stops the current conversion and remaining queue; files already completed remain saved.
- Closing the window keeps the menu bar app running. Right-click the menu bar icon to quit.

For Finder integration, select images and right-click → **Quick Actions → Convert Images**. The selected images appear in the converter; choose the output format and press Convert. A **Services → Convert Images** entry is also provided by the app. If macOS has not enabled the Quick Action, use Finder's Quick Actions → Customize, or search System Settings for Services/Extensions and enable Convert Images. Logging out and back in may refresh a stale Services menu.

To start automatically after signing in, add `~/Applications/Image Converter.app` under System Settings → General → Login Items → Open at Login.

## Conversion options

Every format supports original size, a maximum longest edge, or fitting within width and height bounds. Resizing preserves proportions and does not crop. Upscaling is off unless explicitly enabled. Dimensions accept 1–16384 pixels.

| Format | Options |
| --- | --- |
| PNG | Lossless compression level, 0–9 |
| JPEG | Quality, 1–100 |
| WebP | Lossless mode or lossy quality, 1–100 |
| TIFF | PackBits, LZW, Deflate, or no compression; print resolution in DPI |
| GIF | Palette size, 4–256 colors; dithering |
| TGA | Run-length compression |
| BMP | Uncompressed 24-bit output; shared resize options |

JPEG quality is mapped to FFmpeg's quantizer range; it is not a target file size. TIFF DPI changes print resolution metadata, not pixel dimensions. Options reset to defaults when the app restarts.

## Details and limitations

- FFmpeg is detected at `/opt/homebrew/bin/ffmpeg`, `/usr/local/bin/ffmpeg`, then the app's inherited PATH. Apps launched from Finder may have a shorter PATH than Terminal.
- WebP requires FFmpeg's `libwebp` encoder, included in the tested Homebrew build. Missing encoders and unsupported inputs appear as per-file errors.
- Animated and multipage inputs convert their **first frame/page only**. Metadata, ICC profiles, and HDR appearance may not be preserved. JPEG/BMP do not retain transparency.
- Output folders must be writable and support hard links (the standard APFS Mac filesystem does). For a volume that does not support hard links, save to a local folder and then copy the result to that volume.
- The global shortcut requires the app to be running. If another app has reserved it, the converter reports that it is unavailable; the menu bar still works.
- No images are uploaded. No Accessibility permission is needed for the app's global shortcut.

## Source and tests

The project uses SwiftUI and AppKit, with no third-party Swift packages or Xcode project required.

| File | Responsibility |
| --- | --- |
| `Sources/App.swift` | App lifecycle, menu bar, shortcut, and Services integration |
| `Sources/AppModel.swift` | Main-actor queue management and batch execution |
| `Sources/QueueItem.swift` | Explicit conversion states and results |
| `Sources/ConverterView.swift` | Main window and queue rows |
| `Sources/ConversionOptionsView.swift` | Format-specific options controls |
| `Sources/ConversionOptions.swift` | Option validation and FFmpeg arguments |
| `Sources/ImageFormat.swift` | Supported output formats |
| `Sources/Conversion.swift` | FFmpeg process lifecycle and collision-safe output publishing |
| `Convert Images.workflow` | Finder Quick Action |

Run **build.command** to compile with Apple's Command Line Tools (`xcode-select --install` if needed). Run **test.command** to test all seven formats, decoding, collision naming, original preservation, custom output, invalid images, cancellation, cleanup, resizing, option validation, and queue regressions. The GitHub Actions workflow runs the build and tests on macOS. Build targets Apple Silicon and macOS 13+.

Implementation references: [FFmpeg image formats](https://www.ffmpeg.org/general.html), [FFmpeg image2 options](https://www.ffmpeg.org/ffmpeg-formats.html), and [Apple Services properties](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html).

## Uninstall

Quit from the menu bar icon, then remove `~/Applications/Image Converter.app` and `~/Library/Services/Convert Images.workflow`. If you added a login item, remove that entry too. Converted images remain in their output folders.
