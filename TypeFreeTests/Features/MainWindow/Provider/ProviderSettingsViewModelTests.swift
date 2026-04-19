import SwiftUI
import Testing
@testable import TypeFree

struct ProviderSettingsViewModelTests {
    @Test @MainActor
    func saveWritesSecretAndPersistsOnlyTheEditedConfiguration() async throws {
        let repositories = try makeInMemoryRepositories()
        let secretVault = InMemorySecretVault()
        let viewModel = ProviderSettingsViewModel(
            repository: repositories.providerConfigurationRepository,
            secretVault: secretVault
        )

        viewModel.refresh()
        viewModel.baseURL = "https://speech.example.com/v1/audio/transcriptions"
        viewModel.modelIdentifier = "speech-1"
        viewModel.languageHint = "zh-CN"
        viewModel.requestTimeoutSeconds = 45
        viewModel.apiKey = "secret-token"

        try await viewModel.save()

        let reloaded = try repositories.providerConfigurationRepository.load(kind: .openAICompatible)
        let storedSecrets = await secretVault.snapshot()

        #expect(reloaded.baseURL == "https://speech.example.com/v1/audio/transcriptions")
        #expect(reloaded.modelIdentifier == "speech-1")
        #expect(reloaded.languageHint == "zh-CN")
        #expect(reloaded.requestTimeoutSeconds == 45)
        #expect(reloaded.hasActiveCredentialReference)
        #expect(storedSecrets[reloaded.apiKeyReference ?? ""] == "secret-token")
    }

    @Test @MainActor
    func switchingProviderKindLoadsIndependentConfigurationAndCredential() async throws {
        let repositories = try makeInMemoryRepositories()
        let openAI = try repositories.providerConfigurationRepository.load(kind: .openAICompatible)
        openAI.apiKeyReference = "openai-reference"
        try repositories.providerConfigurationRepository.save(openAI)

        let qwen = try repositories.providerConfigurationRepository.load(kind: .qwen3ASR)
        qwen.baseURL = "https://dashscope-intl.aliyuncs.com/api/v1"
        qwen.modelIdentifier = "qwen3-asr-flash"
        qwen.enableITN = true
        qwen.apiKeyReference = "qwen-reference"
        try repositories.providerConfigurationRepository.save(qwen)

        let viewModel = ProviderSettingsViewModel(
            repository: repositories.providerConfigurationRepository,
            secretVault: InMemorySecretVault(
                secrets: [
                    "openai-reference": "openai-secret",
                    "qwen-reference": "qwen-secret",
                ]
            )
        )

        viewModel.refresh()
        #expect(await eventually { @MainActor in
            viewModel.apiKey == "openai-secret"
        })
        viewModel.selectProviderKind(.qwen3ASR)
        #expect(await eventually { @MainActor in
            viewModel.apiKey == "qwen-secret"
        })

        #expect(viewModel.providerKind == .qwen3ASR)
        #expect(viewModel.baseURL == "https://dashscope-intl.aliyuncs.com/api/v1")
        #expect(viewModel.enableITN == true)
        #expect(viewModel.apiKey == "qwen-secret")
    }

    @Test @MainActor
    func saveRejectsConfigurationWithoutAnyResolvableCredential() async throws {
        let repositories = try makeInMemoryRepositories()
        let viewModel = ProviderSettingsViewModel(
            repository: repositories.providerConfigurationRepository,
            secretVault: InMemorySecretVault()
        )

        viewModel.refresh()

        await #expect(throws: ProviderSettingsError.missingCredential) {
            try await viewModel.save()
        }

        #expect(viewModel.saveMessage == "Provide a valid API key.")
        #expect(viewModel.saveMessageLevel == .error)
    }

    @Test @MainActor
    func saveAcceptsLocalhostHTTPEndpoint() async throws {
        let repositories = try makeInMemoryRepositories()
        let secretVault = InMemorySecretVault()
        let viewModel = ProviderSettingsViewModel(
            repository: repositories.providerConfigurationRepository,
            secretVault: secretVault
        )

        viewModel.refresh()
        viewModel.baseURL = "http://localhost:9000/v1/v1/audio/transcriptions"
        viewModel.apiKey = "local-token"

        try await viewModel.save()

        let reloaded = try repositories.providerConfigurationRepository.load(kind: .openAICompatible)

        #expect(reloaded.baseURL == "http://localhost:9000/v1/v1/audio/transcriptions")
    }

    @Test @MainActor
    func saveQwenConfigurationDoesNotOverwriteOpenAIConfiguration() async throws {
        let repositories = try makeInMemoryRepositories()
        let viewModel = ProviderSettingsViewModel(
            repository: repositories.providerConfigurationRepository,
            secretVault: InMemorySecretVault()
        )

        viewModel.refresh()
        viewModel.apiKey = "openai-secret"
        try await viewModel.save()

        viewModel.selectProviderKind(.qwen3ASR)
        viewModel.baseURL = "https://dashscope-us.aliyuncs.com/api/v1"
        viewModel.modelIdentifier = ProviderKind.qwen3ASR.defaultModelIdentifier
        viewModel.enableITN = true
        viewModel.apiKey = "qwen-secret"
        try await viewModel.save()

        let qwen = try repositories.providerConfigurationRepository.load(kind: .qwen3ASR)

        #expect(qwen.baseURL == "https://dashscope-us.aliyuncs.com/api/v1")
        #expect(qwen.enableITN == true)
    }

    @Test @MainActor
    func saveRejectsQwenEndpointURLInsteadOfBaseURL() async throws {
        let repositories = try makeInMemoryRepositories()
        let viewModel = ProviderSettingsViewModel(
            repository: repositories.providerConfigurationRepository,
            secretVault: InMemorySecretVault()
        )

        viewModel.refresh()
        viewModel.selectProviderKind(.qwen3ASR)
        viewModel.baseURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
        viewModel.apiKey = "qwen-secret"

        await #expect(throws: ProviderSettingsError.invalidBaseURL) {
            try await viewModel.save()
        }
    }
}
