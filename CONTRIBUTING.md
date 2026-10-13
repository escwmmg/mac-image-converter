# Development

Install Apple's Command Line Tools and FFmpeg, then run:

```sh
./test.command
./build.command
open "Image Converter.app"
```

Keep view state on the main actor. FFmpeg work runs outside the main actor, with immutable settings captured at the beginning of each batch. Queue membership is based on `ConversionState.ready`; success, failure, and cancellation are distinct states, not status strings.

Add encoder options through `ConversionOptions` and validate them before starting FFmpeg. Test the resulting image, not only the generated command arguments. Never pass filenames through a shell. The converter uses a safe input alias because FFmpeg interprets percent patterns in image filenames.

Output files are encoded under a temporary name in the destination directory, then published using an exclusive hard link. Preserve the no-overwrite guarantee when changing this path. Cancellation must terminate the child process and allow cleanup to finish before the app exits.

Before submitting changes, run both scripts and check the interface at the default window size. Exercise one conversion, add a second image, and verify that the next batch contains only the new image. Check expanded options with at least PNG, JPEG, and TIFF.

Do not commit generated apps, user images, local paths, credentials, or build logs. Test fixtures should be generated at runtime. Keep commits focused and describe the behavior being changed.
