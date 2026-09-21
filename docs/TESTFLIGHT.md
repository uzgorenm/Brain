# TestFlight releases

Brain appears as **SoloMind** in App Store Connect and on the device. Its bundle identifier is `com.izbirakin.Brain`, and its App Store Connect app ID is `6771943744`.

The current MLX dependencies require Swift 6.3 or newer. Use Xcode 26.4 or newer with Apple's bundled compiler for release builds. A standalone Swift toolchain is not suitable for App Store submissions. Release 3.0 (4) was built with Xcode 27.0 and Swift 6.4.

Install the Metal compiler component with `xcodebuild -downloadComponent MetalToolchain`. On a new Mac, open the project in Xcode and review its package build-tool prompts: MLX uses `CudaBuild` (inactive on Apple platforms), and the model loader uses `MLXHuggingFaceMacros`. Enable the reviewed dependencies through Xcode; the release commands keep plugin validation enabled.

Before archiving, check the latest uploaded build in App Store Connect and increment `CURRENT_PROJECT_VERSION` in both app configurations. Version 3.0 (4) uploaded successfully on September 21, 2026. Use a higher build number for the next upload.

Run from the repository root with the developer account signed in to Xcode:

```sh
swift test --package-path Packages/BrainCore

xcodebuild -project Apps/Brain/Brain.xcodeproj -scheme Brain \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/SoloMind.xcarchive \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive -archivePath /tmp/SoloMind.xcarchive \
  -exportOptionsPlist scripts/TestFlightExportOptions.plist \
  -exportPath /tmp/SoloMind-TestFlight \
  -allowProvisioningUpdates
```

The export command uploads directly to App Store Connect for internal TestFlight testing. Confirm processing completes and the build is available to the existing internal Testers group before reporting it ready. That group is configured for automatic distribution of Xcode builds.

Release artifacts for 3.0 (4): `/tmp/SoloMind-3.0-4.xcarchive`, archive log `/tmp/brain-testflight-4-archive.log`, and successful upload log `/tmp/brain-testflight-4-upload.log`. All 12 BrainCore tests passed in the live project; their log is `/tmp/brain-testflight-4-tests.log`.

The app privacy manifest declares file metadata access inside the app container (`C617.1`): the statically linked Hugging Face downloader checks the sizes of temporary downloads and cached model files. Notes and recordings remain on the device. This declaration follows [Apple's required-reason API documentation](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

## What to test for 3.0 (4)

Record a thought, review its transcript, and save it as a note. Check that a draft survives closing the app and that saved recordings are removed. Try transcription recovery, then search and edit the saved note. Confirm that Notes and Cards stay separate and that notes never appear in scheduled review. Test both Brain shortcuts: Write a note should open the editor with the keyboard ready, and Record a thought should open Capture and request recording without overwriting an unfinished draft.

Install the optional MLX model and test Rewrite for clarity from both a draft and a saved note. Confirm that the preview contains only the finished rewrite, with no reasoning, prompt text, or wrapper tags. Cancel should keep the original text. **Use this version** should update only the editor until the normal save action is used. If the model stops before finishing its response, the app should show a retry error instead of exposing partial output. Test flashcard generation separately from the Cards tab.
