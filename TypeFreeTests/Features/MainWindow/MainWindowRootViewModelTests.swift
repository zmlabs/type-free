import Testing
@testable import TypeFree

struct MainWindowRootViewModelTests {
    @Test @MainActor
    func refreshLoadsSavedSelectionAndExpectedSections() throws {
        let repositories = try makeInMemoryRepositories()
        let settings = try repositories.appSettingsRepository.load()
        settings.selectedSidebarSection = MainWindowSection.provider.rawValue
        try repositories.appSettingsRepository.save(settings)

        let viewModel = MainWindowRootViewModel(
            appSettingsRepository: repositories.appSettingsRepository,
            overviewViewModel: OverviewViewModel(
                appSettingsRepository: repositories.appSettingsRepository,
                providerConfigurationRepository: repositories.providerConfigurationRepository,
                permissionStore: makePermissionStore(),
                audioInputDeviceProbe: TestAudioInputDeviceProbe(isAvailable: true),
                broadcaster: HotkeyChangeBroadcaster()
            ),
            hotkeySettingsViewModel: HotkeySettingsViewModel(
                repository: repositories.appSettingsRepository,
                broadcaster: HotkeyChangeBroadcaster()
            ),
            providerSettingsViewModel: ProviderSettingsViewModel(
                repository: repositories.providerConfigurationRepository,
                secretVault: InMemorySecretVault()
            ),
            permissionsViewModel: PermissionsViewModel(permissionStore: makePermissionStore()),
            aboutViewModel: makeTestAboutViewModel()
        )

        viewModel.refresh()

        #expect(viewModel.sections == [.overview, .hotkey, .provider, .permissions, .about])
        #expect(viewModel.selectedSection == .provider)
        #expect(viewModel.navigationTitle == MainWindowSection.provider.title)
    }

    @Test @MainActor
    func selectPersistsSidebarSection() throws {
        let repositories = try makeInMemoryRepositories()
        let viewModel = MainWindowRootViewModel(
            appSettingsRepository: repositories.appSettingsRepository,
            overviewViewModel: OverviewViewModel(
                appSettingsRepository: repositories.appSettingsRepository,
                providerConfigurationRepository: repositories.providerConfigurationRepository,
                permissionStore: makePermissionStore(),
                audioInputDeviceProbe: TestAudioInputDeviceProbe(isAvailable: true),
                broadcaster: HotkeyChangeBroadcaster()
            ),
            hotkeySettingsViewModel: HotkeySettingsViewModel(
                repository: repositories.appSettingsRepository,
                broadcaster: HotkeyChangeBroadcaster()
            ),
            providerSettingsViewModel: ProviderSettingsViewModel(
                repository: repositories.providerConfigurationRepository,
                secretVault: InMemorySecretVault()
            ),
            permissionsViewModel: PermissionsViewModel(permissionStore: makePermissionStore()),
            aboutViewModel: makeTestAboutViewModel()
        )

        viewModel.select(.permissions)

        let reloaded = try repositories.appSettingsRepository.load()

        #expect(viewModel.selectedSection == .permissions)
        #expect(reloaded.selectedSidebarSection == MainWindowSection.permissions.rawValue)
    }
}
