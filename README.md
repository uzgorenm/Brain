# Brain

Brain is a local-first knowledge app MVP for Apple platforms. Notes give ideas a place to live, while flashcards handle deliberate study and scheduled review. The app stores relationships as graph edges and tracks card review using `new`, `due`, and 20%-100% mastery states.

## Current MVP

- Xcode workspace at `Brain.xcworkspace`.
- Xcode app shell in `Apps/Brain`.
- Local Swift package in `Packages/BrainCore` with shared domain models.
- SQLite-backed local persistence.
- Separate edge records for graph relationships.
- Review scheduling with simplified mastery percentages.
- Demo executable that creates cards, connects them, reviews one, and queries neighbors.
- C++ sync server skeleton with placeholder health and sync endpoints.

## Run Swift Tests

```sh
swift test --package-path Packages/BrainCore
```

## Run the Demo

```sh
swift run --package-path Packages/BrainCore brain-demo /tmp/brain-mvp.sqlite
```

## Build the C++ Sync Server

```sh
cmake -S Server/BrainSyncServer -B Server/BrainSyncServer/build
cmake --build Server/BrainSyncServer/build
./Server/BrainSyncServer/build/brain-sync-server 8080
```

Then check:

```sh
curl http://localhost:8080/health
```

## Open the App in Xcode

Open:

```text
Brain.xcworkspace
```

The workspace contains the app project and the local `BrainCore` package. The app target links `BrainCore` from `Packages/BrainCore`.

## Capture notes and ideas

Brain opens on Capture. Record a thought or write a note, review the text, then save it to the local library. Recordings use on-device speech recognition and are removed after the note is saved. Failed transcriptions keep their audio for retry or manual transcription. Unfinished drafts survive restarting the app.

Scroll down for recent notes, or open Notes to search and edit the full library. Notes stay separate from flashcards and never enter the review queue. The Cards tab contains card creation, scheduled review, and activity.

When the optional local model is installed, choose **Rewrite for clarity** while editing a note. Brain shows only the finished rewrite in a preview. You can edit it, compare it with the original, or cancel without changing the note. **Use this version** copies the rewrite into the editor; the note is not saved until you use the normal save action.

Brain provides two App Shortcuts. **Write a note** opens the editor with the keyboard ready, while **Record a thought** opens Capture and requests recording. Either shortcut can be placed on the Home Screen or assigned to the Action button. An unfinished draft is shown instead of being overwritten.

See [design conventions](docs/DESIGN.md) and the [usability and verification report](docs/CAPTURE_VERIFICATION.md) for the workflow, screenshots, and device-testing limits.
