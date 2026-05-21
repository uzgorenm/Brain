# Brain

Brain is a local-first knowledge app MVP for Apple platforms. It models flexible knowledge cards, stores relationships as graph edges, and tracks review using `new`, `due`, and 20%-100% mastery states.

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
