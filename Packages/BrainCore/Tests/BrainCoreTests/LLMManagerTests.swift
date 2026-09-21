import Foundation
import Testing
@testable import BrainCore

#if os(macOS)
@Test func localModelIsUnavailableWithoutAMacOSRuntime() async {
    let manager = LLMManager()

    #expect(manager.isInitialized == false)
    await #expect(throws: LLMError.self) {
        try await manager.initialize(modelPath: "/unused/model.litertlm")
    }
}
#endif
