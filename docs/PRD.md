# Brain Product Requirements Document

## Overview

Brain is a native Apple-platform knowledge application for capturing, connecting, and reviewing information as flexible flashcard-like knowledge cards. The product combines three core ideas:

1. Rich, expandable information cards for storing abstract concepts, facts, notes, media, and recall prompts.
2. A graph map that shows how cards connect into a personal knowledge network.
3. Spaced repetition scheduling that turns the knowledge graph into durable memory.

The application will support iOS, iPadOS, and macOS with synced data across devices. The frontend will be written in Swift. Local persistence will use SQLite. Server-side sync and supporting services will be written in C++.

## Goals

- Let users create flexible knowledge cards that can represent facts, concepts, ideas, images, notes, or study prompts.
- Make relationships between cards visible and editable through a graph map.
- Use a modern spaced repetition algorithm to schedule card review.
- Sync cards, links, review history, and media metadata across iOS, iPadOS, and macOS.
- Preserve local-first behavior so users can create, edit, and review content offline.
- Provide a foundation for future LLM-assisted graph connection suggestions.
- Provide a foundation for future graph-aware review selection that strengthens recall across connected concepts.

## Non-Goals

- The first version will not be a full document editor.
- The first version will not generate card content automatically from external documents.
- The first version will not require an LLM to function.
- The first version will not include social sharing, public graphs, or collaborative editing.
- The first version will not attempt to replace full note-taking tools such as Obsidian, Notion, or Apple Notes.

## Target Platforms

- iOS
- iPadOS
- macOS

The user experience should feel native on each platform while sharing as much core Swift code as practical.

### Platform Expectations

- iOS: fast capture, focused review, compact graph exploration.
- iPadOS: richer card editing, graph navigation, split-view workflows.
- macOS: power-user editing, larger graph map, bulk organization, keyboard-first workflows.

## Core Concepts

### Knowledge Card

A knowledge card is the primary unit of information. It behaves like a flashcard at review time and like a flexible note when expanded.

Required fields:

- Title
- Description/body
- Creation timestamp
- Updated timestamp
- Review metadata

Optional fields:

- Images
- Tags
- User-defined metadata

Edges should be stored separately from the card record rather than as an array of cards embedded on the card. A card may expose computed incoming, outgoing, or neighboring cards in Swift for UI convenience, but the SQLite source of truth should use a separate `edges` table. This avoids duplicated relationship data, supports graph queries and indexing, allows edge metadata such as relationship type or weight, and makes sync conflict handling cleaner.

### Card Body

The card body should support flexible descriptive content. Early versions can use a constrained rich text model or Markdown-like storage. The data model should not assume that the body is plain text forever.

Supported content for initial release:

- Paragraph text
- Lists
- Basic emphasis
- Links
- Embedded images

Potential future content:

- Tables
- Code blocks
- Audio
- Drawings
- Math notation
- Attachments

### Graph Edge

An edge represents a meaningful connection between two cards.

Edge examples:

- "depends on"
- "is example of"
- "contrasts with"
- "causes"
- "related to"
- "supports"
- "derived from"

Initial release can support a generic relationship type, while the data model should allow typed edges later.

### Map View

The map view visualizes cards as nodes and relationships as edges. It should support exploration, editing, and creation of new cards from the graph.

Required map behavior:

- Display cards as graph nodes.
- Display relationships as graph edges.
- Open a card by selecting its node.
- Create a new connected card from an existing node.
- Create, edit, and delete relationships.
- Pan and zoom the graph.
- Search or filter visible nodes.

## Functional Requirements

### Card Creation

Users must be able to:

- Create a new card with a title.
- Add and edit descriptive content.
- Add images to a card.
- Save cards locally.
- Create cards from the list view, editor view, and map view.
- Create a card directly connected to the currently selected card.

### Card Editing

Users must be able to:

- Edit title and body.
- Add, remove, and reorder images.
- Add or remove tags.
- Update review-related fields when reviewing.
- See unsynced or recently edited state when relevant.

### Card Expansion

Cards should appear compact by default in list-style contexts. When expanded, users should see the full content.

Required behavior:

- Compact state shows title and lightweight metadata.
- Expanded state shows body, images, links, relationships, and review status.
- Expansion should work naturally on touch and pointer devices.

### Knowledge Graph

Users must be able to:

- View their card network in a map.
- Inspect a node and its neighboring cards.
- Create an edge between two cards.
- Remove an edge.
- Create a new card while preserving context from the current node.
- Navigate from a card detail view to the graph focused on that card.

### Search and Organization

Users must be able to:

- Search cards by title.
- Search cards by body text.
- Filter by tag.
- Filter by review state, such as due, new, or mastery percentage.
- Find cards with no connections.

### Spaced Repetition

The application must schedule reviews using a modern spaced repetition algorithm. The recommended initial algorithm is FSRS, because it is widely used in modern SRS systems and models memory stability and difficulty more directly than older algorithms.

Required behavior:

- Track each card's review state.
- Calculate next review date after each user rating.
- Support common review ratings such as Again, Hard, Good, and Easy.
- Support due, new, and percentage-mastered states from 20% through 100%.
- Treat 100% mastery as mastered.
- Store review history for each card.
- Allow daily review sessions based on due cards.
- Allow review sessions filtered by tag or graph neighborhood.

Scheduling requirements:

- The scheduling logic must be deterministic given the same card state and review input.
- Algorithm parameters should be stored in a configurable table or settings structure.
- The app should be able to migrate scheduling data if the algorithm version changes.

### Review Experience

Users must be able to:

- Start a review session.
- See a prompt/title first.
- Reveal the answer or expanded card content.
- Rate recall quality.
- Continue through due cards.
- End or pause a session.
- See lightweight progress during the session.

### Sync

The application must sync across iOS, iPadOS, and macOS.

Required sync behavior:

- Create, update, and delete cards across devices.
- Sync edges across devices.
- Sync review history and scheduling state.
- Sync metadata for images and attachments.
- Support offline local changes.
- Resolve conflicts predictably.

Initial conflict policy:

- Use per-record updated timestamps and stable IDs.
- Prefer field-level merge where practical.
- Use last-writer-wins only for fields that cannot be merged.
- Preserve review events as append-only records to avoid losing scheduling history.

### Authentication

Authentication requirements depend on whether sync is account-based, iCloud-based, or self-hosted.

Recommended initial direction:

- Use account-based sync with the C++ server if the project requires full control over sync.
- Consider Sign in with Apple for user identity.
- Keep local-only mode possible for users who do not enable sync.

## Technical Requirements

### Frontend

Language and platform:

- Swift
- SwiftUI for shared interface surfaces where practical
- AppKit/UIKit bridges where platform-specific behavior is required

Recommended architecture:

- Shared Swift package for domain models, scheduling logic, sync client, and SQLite access.
- Platform app targets for iOS, iPadOS, and macOS.
- MVVM or reducer-style state management, chosen consistently across the app.

Important frontend modules:

- Card editor
- Card list/search
- Graph map
- Review session
- Sync status
- Settings

### Database

Database:

- SQLite

Required database properties:

- Stable unique IDs for cards and edges.
- Local-first reads and writes.
- Migrations with explicit schema versions.
- Indexes for search, graph traversal, due cards, and sync state.
- Append-only review log.

Recommended tables:

- `cards`
- `card_content_blocks`
- `card_media`
- `edges`
- `tags`
- `card_tags`
- `review_state`
- `review_events`
- `sync_records`
- `settings`

### Server

Language:

- C++

Server responsibilities:

- Store canonical synced records.
- Accept client changes.
- Return remote changes since a sync cursor.
- Support conflict resolution policy.
- Authenticate requests.
- Store media objects or coordinate media upload/download.
- Expose health and version endpoints.

Recommended API style:

- HTTP/JSON for early development simplicity, or gRPC if stronger typed contracts and streaming sync are priorities.

Required API capabilities:

- Push local changes.
- Pull remote changes.
- Fetch sync cursor.
- Upload media metadata.
- Download media metadata.
- Authenticate user/session.

## Data Model Draft

### Card

- `id`
- `title`
- `body_format`
- `created_at`
- `updated_at`
- `deleted_at`
- `sync_version`

### Content Block

- `id`
- `card_id`
- `kind`
- `sort_order`
- `text`
- `metadata_json`
- `created_at`
- `updated_at`

### Media

- `id`
- `card_id`
- `local_path`
- `remote_url`
- `mime_type`
- `width`
- `height`
- `created_at`
- `updated_at`

### Edge

- `id`
- `source_card_id`
- `target_card_id`
- `relationship_type`
- `label`
- `weight`
- `created_at`
- `updated_at`
- `deleted_at`

### Review State

- `card_id`
- `algorithm`
- `algorithm_version`
- `state`
- `mastery_percent`
- `due_at`
- `stability`
- `difficulty`
- `elapsed_days`
- `scheduled_days`
- `reps`
- `lapses`
- `last_reviewed_at`

### Review Event

- `id`
- `card_id`
- `reviewed_at`
- `rating`
- `duration_ms`
- `previous_state_json`
- `next_state_json`
- `algorithm`
- `algorithm_version`

## SRS Algorithm Requirements

Initial implementation should use FSRS or a compatible modern SRS algorithm.

Implementation requirements:

- Keep algorithm logic in shared Swift code if review scheduling must work fully offline on all Apple platforms.
- Store algorithm version on each review state and event.
- Add test fixtures for known scheduling inputs and outputs.
- Make parameters configurable without requiring schema changes.
- Keep review event history independent of current card state.

User-facing review ratings:

- Again
- Hard
- Good
- Easy

User-facing review state:

- New
- Due
- 20% mastered
- 40% mastered
- 60% mastered
- 80% mastered
- 100% mastered

The app may store the detailed algorithmic values required by FSRS internally, but the primary user-facing state should be the simplified state above. A card is considered mastered when `mastery_percent` is 100.

Future algorithm improvements:

- User-personalized FSRS parameter optimization.
- Separate scheduling profiles per deck, tag, or knowledge domain.
- Graph-aware scheduling adjustments.

## Future Implementation: LLM-Assisted Connections

The app should eventually let users request AI-suggested connections between cards.

Possible workflow:

1. User selects one or more cards.
2. User requests suggested connections.
3. App sends relevant card titles, summaries, tags, and existing edge context to an LLM service.
4. LLM returns suggested edges with explanations and confidence scores.
5. User accepts, edits, or rejects each suggestion.

Requirements:

- LLM suggestions must never silently create edges without user confirmation.
- The app should show why each connection was suggested.
- The system should avoid sending private content unless the user has enabled the feature.
- Accepted and rejected suggestions should be stored to improve future recommendations.

Potential outputs:

- Suggested relationship type.
- Suggested edge label.
- Explanation.
- Confidence score.
- Related cards the user may want to review together.

## Future Implementation: Graph-Aware Recall

The app should eventually support recall sessions that include connected cards to strengthen conceptual memory.

Concept:

- When a card is due for review, the system can optionally include closely connected cards.
- Connected cards may be chosen by graph distance, edge weight, relationship type, review weakness, or semantic similarity.
- The goal is to reinforce not only isolated facts, but the user's mental map of how concepts relate.

Possible selection factors:

- Direct neighbors of the due card.
- Cards connected by high-weight edges.
- Cards with recent lapses.
- Cards in the same tag or topic cluster.
- Cards that bridge multiple clusters.
- Cards that have not been reviewed recently but are important to the local graph.

Safeguards:

- Graph-aware recall should not overload daily review counts.
- It should be opt-in or adjustable.
- It should distinguish between required due cards and supplemental connected cards.
- Supplemental reviews should affect scheduling carefully to avoid distorting the SRS model.

## Key User Flows

### Create a Card

1. User taps or clicks create.
2. User enters a title.
3. User adds body content and optional images.
4. User saves.
5. Card appears in the card list and can be found in search.

### Create a Connected Card

1. User opens a card or selects a graph node.
2. User chooses create connected card.
3. User enters the new card content.
4. App creates the card and edge.
5. Map view updates to show both connected nodes.

### Review Due Cards

1. User starts daily review.
2. App selects due cards.
3. User sees prompt/title.
4. User reveals answer/details.
5. User rates recall.
6. App updates review state and schedules next review.

### Explore the Map

1. User opens map view.
2. App displays cards and edges.
3. User pans, zooms, and selects a node.
4. User opens the card, edits relationships, or creates a connected card.

### Sync Across Devices

1. User edits a card on one device.
2. App stores the change locally.
3. Sync client pushes the change to the server.
4. Other devices pull the change.
5. Local databases converge to the same state.

## UX Requirements

- The first screen should make capture, review, and map exploration immediately accessible.
- Card creation should be fast enough for spontaneous capture.
- Review sessions should be distraction-free.
- The graph should be useful before it becomes visually dense.
- Users should always be able to recover from accidental edits or deletes where practical.
- Sync status should be visible but not noisy.

## Accessibility Requirements

- Support Dynamic Type where possible.
- Support VoiceOver labels for major controls.
- Support keyboard navigation on macOS and iPadOS.
- Preserve sufficient color contrast.
- Do not rely on color alone to communicate review state or graph relationship type.

## Privacy and Security Requirements

- Local data should remain available without sync.
- Synced data must be transmitted over TLS.
- Authentication tokens must be stored in the platform keychain.
- Private card content should not be sent to LLM services unless the user explicitly enables the feature.
- Deletion behavior should be clear, including whether deleted data remains recoverable for a limited period.

## Analytics and Success Metrics

Potential product metrics:

- Cards created per active user.
- Review sessions completed per week.
- Review completion rate.
- Percentage of cards with at least one edge.
- Number of graph-created cards.
- Sync reliability and conflict rate.
- Retention after first week and first month.

Quality metrics:

- Crash-free sessions.
- Sync success rate.
- Median card creation time.
- Review scheduling correctness.
- Time to render graph for common library sizes.

## Performance Requirements

- Card list should load quickly with thousands of cards.
- Search should feel immediate for local data.
- Review session startup should be near-instant for local due cards.
- Graph view should handle at least hundreds of visible nodes smoothly in early versions.
- Database writes should not block the main thread.
- Sync should batch changes efficiently.

## Open Questions

- Should sync be custom account-based sync, iCloud-backed sync, or both?
- Should the initial rich content format be Markdown, structured content blocks, AttributedString, or a hybrid?
- Should cards have separate prompt and answer fields, or should any card body be reviewable?
- Should the graph be directed, undirected, or support both?
- Should users organize cards into decks, tags, collections, or only graph clusters?
- Should media files be stored in SQLite, on disk with database references, or in a platform document container?
- Should the C++ server expose HTTP/JSON, gRPC, or another protocol?

## Milestones

### Milestone 1: Local Card Foundation

- Swift app shell for iOS, iPadOS, and macOS.
- SQLite schema and migrations.
- Create, edit, delete, and search cards.
- Basic expandable card UI.

### Milestone 2: Graph Foundation

- Edge data model.
- Create and delete relationships.
- Basic map view with pan, zoom, and node selection.
- Create connected card workflow.

### Milestone 3: Review Foundation

- FSRS scheduling implementation.
- Review state and review event storage.
- Daily review session.
- Review ratings and next due calculation.

### Milestone 4: Sync Foundation

- C++ server skeleton.
- Authentication decision and implementation.
- Push/pull sync API.
- Local sync queue.
- Conflict handling.

### Milestone 5: Cross-Platform Polish

- Platform-specific layout refinement.
- macOS keyboard workflows.
- iPadOS split-view graph and editor workflow.
- Offline and sync status UX.

### Milestone 6: Intelligent Graph Features

- LLM-assisted connection suggestions.
- User review and approval flow.
- Graph-aware supplemental recall experiments.

## MVP Definition

The MVP is complete when a user can:

- Create and edit rich text cards with optional images.
- Connect cards to each other.
- View cards and connections in a graph map.
- Review due cards using FSRS-based spaced repetition.
- Use the app offline with SQLite-backed persistence.
- Sync cards, edges, and review state across Apple devices through the C++ server.

## Buildable MVP Scope

The first coded MVP should prove the core product loop before investing in full platform polish.

Required coded capabilities:

- Swift domain models for cards, edges, tags, media references, and review state.
- SQLite-backed local persistence for cards, edges, tags, media references, review state, and review events.
- Card creation with title, description/body, optional images, tags, and user-defined metadata.
- Edge creation as separate relationship records between cards.
- Graph-neighborhood queries for a selected card.
- Review state using `new`, `due`, and mastery percentages from 20 through 100.
- A review update function that changes mastery percentage and next due date after Again, Hard, Good, or Easy.
- A minimal C++ sync server skeleton with health and placeholder sync endpoints.
- A simple executable or demo path that validates the core flow end to end.

Deferred from coded MVP:

- Full SwiftUI card editor.
- Production graph visualization.
- Real authentication.
- Production conflict resolution.
- Media upload/download.
- LLM-assisted connections.
- Graph-aware supplemental recall.
