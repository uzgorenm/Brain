# Capture redesign verification

Verified September 21, 2026. Visual and interaction checks used Xcode 26.2 and iOS 26.2 simulators. The integrated release checks used Xcode 27.0 and Swift 6.4. The changes remain in the working tree. Existing unrelated edits, including the AI runtime migration, were preserved.

## Prioritized diagnosis

These observations come from repository documentation and actual simulator use, not user research or analytics.

| Priority | Screen and observed difficulty | Change | Expected benefit |
| --- | --- | --- | --- |
| 1 | Home opened on “No Cards Due,” with no capture action in the empty state. | Capture opens first with recording and writing actions; recent notes are below. | A first-time user can save a thought immediately. |
| 1 | Creation required a question and answer; the AI generator occupied the top of the editor. | Add freeform notes with optional titles. Move card generation into a disclosure below manual entry. | Capture an unfinished idea without organizing it first. |
| 1 | Save cleared the editor regardless of database failure; reset could delete a saved audio attachment. | Only finish after successful persistence; retain drafts and saved attachments. Make card creation and review writes transactional. | A failure leaves recoverable input instead of false confirmation. |
| 2 | Six tabs pushed destinations into More. | Four destinations: Capture, Notes, Cards, and Settings. Activity lives under Cards, and Ask AI lives under Notes. | Notes and flashcards have separate homes without crowding the tab bar. |
| 2 | Review's custom heading overlapped the status area, and its permanent guide crowded the card. | Native navigation, scrollable content, answer-first progression, optional explanation, explicit completion. | The current review action stays clear with long content. |
| 2 | Map controls included a nonfunctional AI button and an unlabeled connection action that could open without a selection. | Remove the no-op control; label Connect and require a selection. Preserve selected-card context. | Actions match what the screen can actually do. |

## Checks completed

- Built and ran the original interface on an iPhone 17 Pro simulator. Created a sample card and opened its review state; captured before screenshots.
- Built the initial redesign successfully against the existing LiteRT-LM 0.17.1 dependency.
- Built the final capture/UI/storage changes in an isolated copy using the earlier LiteRT-LM runtime and compatible adapter. Build succeeded, including App Intents metadata extraction. Final app build log: `/tmp/brain-isolated-build.log`.
- Ran all 11 BrainCore tests in that isolated copy. All passed. The archived log remains at `/tmp/brain-isolated-tests.log`.
- Ran the current 12-test suite in the live repository with the final MLX dependencies. All passed. The suite covers note validation, title derivation, draft serialization, persistent recovery, audio cleanup, note and flashcard review separation, local rewrite prompt handling, legacy-card behavior, and transactional rollback after injected write failures.
- Created the signed iOS Release archive for SoloMind 3.0 (2) with the final MLX integration. Archive and strict code-signature verification passed. Confirmed iOS 26.2 minimum, recording/transcription permission descriptions, bundled privacy manifest, and generated App Intents metadata. Log: `/tmp/brain-testflight-archive.log`.
- `git diff --check` passed. This repository has no configured SwiftLint check, and SwiftLint is not installed.
- Used the simulator to enter and save a typed note without a title; confirmed its generated title and saved-note link. Relaunched with a draft and confirmed restoration.
- Denied microphone access and verified the writing fallback and error. Reset the test permission, allowed access, recorded audio, and stopped it. The timer and recording state appeared correctly.
- A silent simulator recording failed transcription. Verified its 233,744-byte audio file remained and that Save stayed disabled until a transcript was provided. Entered a manual transcript, explicitly accepted it, saved the note, and checked the database and filesystem: the note had voice-source metadata and no audio files remained in the draft directory.
- Edited a saved note's title and body and saved it successfully. Verified a long note title wrapped in the editor and shortened in library rows.
- Verified in the current core tests that captured notes stay out of the review queue, even when an older note still carries the retired `reviewEnabled=true` metadata. Existing flashcards remain reviewable.
- Inspected empty capture at 375-point phone width and on a 13-inch iPad. Inspected the largest accessibility text size on the small phone; adjusted the introductory content so Record a thought stays near the top.
- Checked native accessibility names for capture, editor fields, recording states, recovery actions, review ratings, and completion. This is not a full VoiceOver audit.

## Integration verification

The separate “Find brain project model” task changed the package manifest, AI adapter, downloader, and settings during the initial visual checks. The initial combined build was blocked by MLX's Swift 6.3 requirement. Updating to Xcode 27.0 and installing its Metal compiler resolved that toolchain blocker. The final combined app now archives successfully, and its core tests pass.

The release compiler reports warnings in upstream MLX Metal code, an existing unassigned icon source asset, and closure-capture warnings in CaptureSession and ModelDownloadManager under the current Swift 5 language mode. These did not prevent the archive. The simulator screenshots still represent the earlier isolated verification copy at `/tmp/brain-capture-qa`; no physical-device AI inference check has been performed.

## Still to verify on a device

- Speech transcription accuracy and availability for the device's language, extended recordings, interruptions, and background transitions. Only the simulator recording/failure/manual-recovery path was exercised here.
- Launching Write a note or Record a thought through Siri, Shortcuts, Home Screen, or the Action button. Both intents compile and appear in generated metadata; system launch was not exercised.
- Keyboard shortcuts and full VoiceOver navigation. Simulator tooling could not consistently access native toolbar/search/tab controls, so interactive search, the redesigned card-creation sheet, Settings, and Ask AI were not fully exercised after the redesign. The database search regression and app compilation passed.
- Model download and AI generation on a physical device with the new MLX runtime. No physical-device rewrite inference was performed during this task.

Notes and flashcards are deliberately separate in the interface and in review behavior. They continue to share the existing card table so current libraries do not need a database migration. The separate WidgetKit extension is deferred because this iteration supplies the requested shortcut. There is no sync or authentication change.

## Screenshots

| Before | After |
| --- | --- |
| [Original home](screenshots/before-home.png) | [Capture home](screenshots/after-capture.png) |
| [Original card creation](screenshots/before-create.png) | [Saved note and recent notes](screenshots/after-saved-note.png) |
| | [Library with a long title](screenshots/after-library.png) |
| | [Review and recall ratings](screenshots/after-review.png) |
| | [Transcription recovery](screenshots/after-transcription-recovery.png) |
| | [Small phone, empty](screenshots/after-small-empty.png) |
| | [Largest text size](screenshots/after-large-text.png) |
| | [iPad, empty](screenshots/after-ipad-empty.png) |
