# Brain interaction conventions

Brain is a local knowledge app with two distinct paths. Capture and Notes hold freeform ideas. Cards handles question-and-answer study and spaced review.

## Evidence and scope

The repository defines local SQLite storage, knowledge cards, graph connections, and scheduled review. The persistence layer still supports graph connections, but the app does not expose a map screen. This iteration follows the user's request for spoken brain dumps, transcripts, recent notes, local summaries and rewrites, and a recording shortcut. There is no user research or analytics behind these decisions.

Notes use the existing card table with `kind=note`, plus `source` and `captureID` metadata, so no schema migration is needed. That shared storage is an implementation detail: Notes and Cards have separate screens, editing flows, searches, and actions. Only flashcards enter scheduled review or review analytics. Notes remain searchable, editable, connectable, and available to local AI. Sync, authentication, and the review algorithm are unchanged.

Rewrite uses the optional on-device model. Only the final rewritten text reaches the editable preview; model reasoning, prompt echoes, and response wrappers are discarded. An incomplete response shows an error instead of exposing intermediate output. Cancel leaves the draft untouched. **Use this version** returns the rewrite to the note editor, where the user still decides whether to save it.

## Screen conventions

- Capture uses "What's on your mind?" as its heading instead of repeating the tab name in a navigation bar. Capture and Latest notes occupy separate full-height pages. A deliberate vertical swipe moves between them, while a short drag returns to the current page.
- Notes contains the note library, search, editing, local summaries and rewrites, and Ask AI. Its search and AI context use notes only.
- Cards contains the flashcard library, card creation, due review, and activity.
- Settings separates optional local AI from capture. Recording does not require the AI model download.

## Visual system

Use a warm, light palette with stone backgrounds, ivory surfaces, and a deep forest accent. Use semantic system text styles, 20-point page margins, 8/12/16/24-point spacing, 16-point surface corners, and 44-point minimum control targets. Limit readable text width to 720 points. Surfaces group editable content and status, while dividers separate library rows. Screens with toolbar actions use compact centered navigation titles. Capture does not need one because its prompt already anchors the page.

Use the deep green accent for the next primary action, bordered buttons for alternatives, and destructive styling only for destructive actions. Text labels accompany specialized actions. Status always includes text, not just color. Support Dynamic Type, VoiceOver, keyboard shortcuts, and Reduce Motion; long text wraps rather than shrinking to fit.

## Recording and recovery

Request microphone access only when recording starts. Record in the app's local support directory and persist the draft before recording. Stop on backgrounding or interruption, with a five-minute limit per recording. Transcribe the saved file using Apple's on-device recognizer. Never fall back silently to server transcription. Speech authorization or language/device availability failures leave the file available for retry, playback, or manual transcription.

The user can review and edit the transcript and its optional title before saving. Saving persists the card before deleting its recording and draft. A capture ID makes retry after interrupted cleanup idempotent. Only explicit discard or successful note persistence allows recording removal. Draft text survives leaving Capture and relaunching the app. Draft write and cleanup failures are shown as actionable errors.

The **Write a note** App Shortcut opens the editor and focuses the note text. **Record a thought** opens Capture and requests recording. Either shortcut can be assigned to the Action button. If an existing draft needs attention, Brain shows it instead of overwriting it. Command-Shift-R opens recording, and Command-N opens a typed note. A separate WidgetKit extension is outside this iteration.

## API references

- [Apple on-device speech availability](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
- [Apple App Intents](https://developer.apple.com/documentation/appintents/appintent)
