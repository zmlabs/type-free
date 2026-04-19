import Testing
@testable import TypeFree

struct OverviewViewModelTests {
    @Test @MainActor
    func refreshUsesThePersistedActiveProviderToDeriveNameAndReadiness() throws {
        let repositories = try makeInMemoryRepositories()
        let settings = try repositories.appSettingsRepository.load()
        settings.activeProvider = .qwen3ASR
        try repositories.appSettingsRepository.save(settings)

        let qwen = try repositories.providerConfigurationRepository.load(kind: .qwen3ASR)
        qwen.apiKeyReference = "qwen-reference"
        try repositories.providerConfigurationRepository.save(qwen)

        let viewModel = OverviewViewModel(
            appSettingsRepository: repositories.appSettingsRepository,
            providerConfigurationRepository: repositories.providerConfigurationRepository,
            permissionStore: makePermissionStore(),
            broadcaster: HotkeyChangeBroadcaster()
        )

        viewModel.refresh()

        #expect(viewModel.activeProvider == .qwen3ASR)
        #expect(viewModel.readiness == .ready)
    }

    @Test @MainActor
    func saveActiveProviderPersistsSelectionAndRecomputesReadiness() throws {
        let repositories = try makeInMemoryRepositories()
        let openAI = try repositories.providerConfigurationRepository.load(kind: .openAICompatible)
        openAI.apiKeyReference = "openai-reference"
        try repositories.providerConfigurationRepository.save(openAI)
        let qwen = try repositories.providerConfigurationRepository.load(kind: .qwen3ASR)
        qwen.apiKeyReference = nil
        try repositories.providerConfigurationRepository.save(qwen)

        let viewModel = OverviewViewModel(
            appSettingsRepository: repositories.appSettingsRepository,
            providerConfigurationRepository: repositories.providerConfigurationRepository,
            permissionStore: makePermissionStore(),
            broadcaster: HotkeyChangeBroadcaster()
        )

        viewModel.refresh()
        viewModel.commitActiveProvider(.qwen3ASR)

        let settings = try repositories.appSettingsRepository.load()

        #expect(settings.activeProvider == .qwen3ASR)
        #expect(viewModel.readiness == .providerNotConfigured)
    }
}
