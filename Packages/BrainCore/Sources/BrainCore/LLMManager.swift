import Foundation
@preconcurrency import LiteRTLM

public final class LLMManager: @unchecked Sendable {
    public static let shared = LLMManager()

    private var engine: Engine?

    public init() {}

    public func initialize(modelPath: String) async throws {
#if targetEnvironment(simulator)
        let backend: Backend = .cpu(threadCount: 4)
#else
        let backend: Backend = .gpu
#endif
        let config = try EngineConfig(
            modelPath: modelPath,
            backend: backend,
            cacheDir: NSTemporaryDirectory()
        )
        let newEngine = Engine(engineConfig: config)
        try await newEngine.initialize()
        self.engine = newEngine
    }

    public var isInitialized: Bool {
        engine != nil
    }

    public func generateFlashcard(from detailedInformation: String) async throws -> (title: String, body: String) {
        guard let engine = engine else { throw LLMError.notInitialized }
        let conversation = try await engine.createConversation()
        
        let prompt = """
        You are a highly capable AI that extracts information to create a single flashcard.
        From the following information, extract the most important concept and create a question and answer flashcard.
        Format your response EXACTLY as follows, with no extra text:
        Q: [Question here]
        A: [Answer here]

        Information:
        \(detailedInformation)
        """
        
        let response = try await conversation.sendMessage(Message(prompt))
        let responseText = response.toString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse Q: and A:
        var title = ""
        var body = ""
        
        let lines = responseText.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("Q:") {
                title = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("A:") {
                body = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
            } else if !title.isEmpty && !body.isEmpty {
                body += "\n" + line.trimmingCharacters(in: .whitespaces)
            }
        }
        
        if title.isEmpty { title = "Generated Question" }
        if body.isEmpty { body = responseText }
        
        return (title, body)
    }

    public func answerQuestion(question: String, context: [String]) async throws -> String {
        guard let engine = engine else { throw LLMError.notInitialized }
        let conversation = try await engine.createConversation()
        
        let contextText = context.joined(separator: "\n---\n")
        let prompt = """
        You are a helpful AI study assistant. Use the following flashcard context to answer the user's question.
        
        Context:
        \(contextText)

        Question:
        \(question)
        """
        
        let response = try await conversation.sendMessage(Message(prompt))
        return response.toString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum LLMError: Error {
    case notInitialized
}
