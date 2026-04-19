import SwiftData
import Testing
@testable import TypeFree

struct ProviderConfigurationRepositoryTests {
    @Test @MainActor
    func loadAllCreatesDefaultProviderConfigurationsWhenMissing() throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let repository = ProviderConfigurationRepository(modelContext: modelContainer.mainContext)

        let configurations = try repository.loadAll()
        let storedConfigurations = try modelContainer.mainContext.fetch(FetchDescriptor<ProviderConfiguration>())
        let qwen = try #require(configurations.first { $0.providerKind == ProviderKind.qwen3ASR.rawValue })

        #expect(configurations.count == ProviderKind.allCases.count)
        #expect(storedConfigurations.count == ProviderKind.allCases.count)
        #expect(
            Set(configurations.map(\.providerKind)) == Set(ProviderKind.allCases.map(\.rawValue))
        )
        #expect(qwen.baseURL == "https://dashscope.aliyuncs.com/api/v1")
        #expect(qwen.enableITN == false)
    }

    @Test @MainActor
    func savePersistsUpdatedConfigurationWithoutCreatingDuplicatesPerKind() throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let repository = ProviderConfigurationRepository(modelContext: modelContainer.mainContext)
        _ = try repository.loadAll()
        let configuration = try repository.load(kind: .openAICompatible)
        let originalUpdatedAt = configuration.updatedAt

        configuration.baseURL = "https://transcribe.example.com/v1/audio/transcriptions"
        configuration.modelIdentifier = "speech-prod"
        configuration.languageHint = "zh-CN"
        configuration.requestTimeoutSeconds = 45
        try repository.save(configuration)

        let reloaded = try repository.load(kind: .openAICompatible)
        let storedConfigurations = try modelContainer.mainContext.fetch(FetchDescriptor<ProviderConfiguration>())

        #expect(reloaded.baseURL == "https://transcribe.example.com/v1/audio/transcriptions")
        #expect(reloaded.modelIdentifier == "speech-prod")
        #expect(reloaded.languageHint == "zh-CN")
        #expect(reloaded.requestTimeoutSeconds == 45)
        #expect(reloaded.updatedAt >= originalUpdatedAt)
        #expect(storedConfigurations.count == ProviderKind.allCases.count)
    }

    @Test @MainActor
    func savePersistsIndependentCredentialReferencesPerProviderKind() throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let repository = ProviderConfigurationRepository(modelContext: modelContainer.mainContext)
        let openAI = try repository.load(kind: .openAICompatible)
        let qwen = try repository.load(kind: .qwen3ASR)

        openAI.apiKeyReference = "openai-secret-ref"
        qwen.apiKeyReference = "qwen-secret-ref"
        try repository.save(openAI)
        try repository.save(qwen)

        let reloadedOpenAI = try repository.load(kind: .openAICompatible)
        let reloadedQwen = try repository.load(kind: .qwen3ASR)

        #expect(reloadedOpenAI.apiKeyReference == "openai-secret-ref")
        #expect(reloadedQwen.apiKeyReference == "qwen-secret-ref")
        #expect(reloadedOpenAI.hasActiveCredentialReference)
        #expect(reloadedQwen.hasActiveCredentialReference)
    }

    @Test @MainActor
    func savePersistsQwenSpecificOptions() throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let repository = ProviderConfigurationRepository(modelContext: modelContainer.mainContext)
        let configuration = try repository.load(kind: .qwen3ASR)

        configuration.baseURL = "https://dashscope-us.aliyuncs.com/api/v1"
        configuration.enableITN = true
        try repository.save(configuration)

        let reloaded = try repository.load(kind: .qwen3ASR)

        #expect(reloaded.baseURL == "https://dashscope-us.aliyuncs.com/api/v1")
        #expect(reloaded.enableITN == true)
    }

    @Test @MainActor
    func loadAllDeduplicatesKnownKindsAndBackfillsMissingKinds() throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let first = ProviderConfiguration.defaultValue(kind: .openAICompatible)
        let duplicate = ProviderConfiguration.defaultValue(kind: .openAICompatible)
        modelContainer.mainContext.insert(first)
        modelContainer.mainContext.insert(duplicate)
        try modelContainer.mainContext.save()

        let repository = ProviderConfigurationRepository(modelContext: modelContainer.mainContext)

        let configurations = try repository.loadAll()
        let storedConfigurations = try modelContainer.mainContext.fetch(FetchDescriptor<ProviderConfiguration>())

        #expect(configurations.count == ProviderKind.allCases.count)
        #expect(storedConfigurations.count == ProviderKind.allCases.count)
        #expect(configurations.filter { $0.providerKind == ProviderKind.openAICompatible.rawValue }.count == 1)
        #expect(configurations.contains { $0.providerKind == ProviderKind.qwen3ASR.rawValue })
    }

    @Test @MainActor
    func loadAllDoesNotRewriteStoredQwenBaseURL() throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let legacyQwen = ProviderConfiguration.defaultValue(kind: .qwen3ASR)
        legacyQwen.baseURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
        modelContainer.mainContext.insert(legacyQwen)
        try modelContainer.mainContext.save()

        let repository = ProviderConfigurationRepository(modelContext: modelContainer.mainContext)

        let configurations = try repository.loadAll()
        let reloadedQwen = try #require(configurations.first { $0.providerKind == ProviderKind.qwen3ASR.rawValue })

        #expect(
            reloadedQwen.baseURL
                == "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
        )
    }
}
