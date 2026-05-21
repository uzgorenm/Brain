import BrainCore
import Foundation

let databasePath = CommandLine.arguments.dropFirst().first ?? "/tmp/brain-mvp.sqlite"
let store = try SQLiteStore(path: databasePath)

let swift = try store.createCard(
    title: "SwiftUI",
    body: "A declarative Swift framework for building Apple-platform interfaces.",
    tags: ["swift", "frontend"],
    imagePaths: [],
    metadata: ["platform": "iOS/macOS/iPadOS"]
)

let graph = try store.createCard(
    title: "Knowledge Graph",
    body: "A network of knowledge cards connected by explicit edges.",
    tags: ["graph"],
    metadata: ["mvp": "true"]
)

_ = try store.addEdge(from: swift.id, to: graph.id, label: "can visualize")
let reviewed = try store.applyReview(cardID: swift.id, rating: .good)
let neighbors = try store.neighbors(of: swift.id)
let due = try store.dueCards()

print("Brain MVP database: \(databasePath)")
print("Created card: \(swift.title)")
print("Review status: \(reviewed.status.storageValue), due: \(reviewed.dueAt?.description ?? "none")")
print("Neighbors: \(neighbors.map(\.title).joined(separator: ", "))")
print("Due/new cards: \(due.map(\.title).joined(separator: ", "))")
