import Testing
@testable import TypeFree

struct HotkeySettingsViewModelTests {
    @Test @MainActor
    func commitPersistsSinglePhysicalKeyAndUpdatesRuntime() throws {
        let repositories = try makeInMemoryRepositories()
        let broadcaster = HotkeyChangeBroadcaster()
        let recorder = HotkeyChangeRecorder()
        broadcaster.register(recorder)
        let viewModel = HotkeySettingsViewModel(
            repository: repositories.appSettingsRepository,
            broadcaster: broadcaster
        )

        viewModel.refresh()
        viewModel.commitSelection("rightOption")

        let reloaded = try repositories.appSettingsRepository.load()

        #expect(reloaded.hotkeyIdentifier == "rightOption")
        #expect(reloaded.hotkeyDisplayName == "Right Option")
        #expect(recorder.values == [.init(identifier: "rightOption", displayName: "Right Option")])
        #expect(viewModel.lastPersistenceError == nil)
    }

    @Test @MainActor
    func commitRejectsUnsupportedShortcutDefinition() throws {
        let repositories = try makeInMemoryRepositories()
        let viewModel = HotkeySettingsViewModel(
            repository: repositories.appSettingsRepository,
            broadcaster: HotkeyChangeBroadcaster()
        )

        viewModel.refresh()
        viewModel.commitSelection("command+space")

        #expect(viewModel.lastPersistenceError != nil)
    }

    @Test @MainActor
    func commitPersistsCustomKeyConfiguration() throws {
        let repositories = try makeInMemoryRepositories()
        let broadcaster = HotkeyChangeBroadcaster()
        let recorder = HotkeyChangeRecorder()
        broadcaster.register(recorder)
        let viewModel = HotkeySettingsViewModel(
            repository: repositories.appSettingsRepository,
            broadcaster: broadcaster
        )

        viewModel.refresh()
        let customConfig = HotkeyConfiguration.custom(keyCode: 96, characters: nil)
        viewModel.customHotkeyOption = HotkeyOption(configuration: customConfig)
        viewModel.commitSelection(customConfig.identifier)

        let reloaded = try repositories.appSettingsRepository.load()

        #expect(reloaded.hotkeyIdentifier == customConfig.identifier)
        #expect(reloaded.hotkeyDisplayName == "F5")
        #expect(recorder.values == [customConfig])
    }

    @Test @MainActor
    func removeCustomHotkeyRevertsToDefault() throws {
        let repositories = try makeInMemoryRepositories()
        let viewModel = HotkeySettingsViewModel(
            repository: repositories.appSettingsRepository,
            broadcaster: HotkeyChangeBroadcaster()
        )

        viewModel.refresh()
        let customConfig = HotkeyConfiguration.custom(keyCode: 96, characters: nil)
        viewModel.customHotkeyOption = HotkeyOption(configuration: customConfig)
        viewModel.commitSelection(customConfig.identifier)

        viewModel.removeCustomHotkey()

        #expect(viewModel.customHotkeyOption == nil)
        #expect(viewModel.selectedHotkeyIdentifier == HotkeyConfiguration.default.identifier)
        #expect(viewModel.availableHotkeys.count == HotkeyConfiguration.supported.count)
    }

    @Test @MainActor
    func refreshRestoresCustomKeyFromPersistedSettings() throws {
        let repositories = try makeInMemoryRepositories()
        let settings = try repositories.appSettingsRepository.load()
        settings.hotkeyIdentifier = "keyCode:96"
        settings.hotkeyDisplayName = "F5"
        try repositories.appSettingsRepository.save(settings)

        let viewModel = HotkeySettingsViewModel(
            repository: repositories.appSettingsRepository,
            broadcaster: HotkeyChangeBroadcaster()
        )
        viewModel.refresh()

        #expect(viewModel.selectedHotkeyIdentifier == "keyCode:96")
        #expect(viewModel.customHotkeyOption?.configuration.displayName == "F5")
        #expect(viewModel.availableHotkeys.count == HotkeyConfiguration.supported.count + 1)
    }
}

@MainActor
final class HotkeyChangeRecorder: HotkeyChangeObserver {
    private(set) var values: [HotkeyConfiguration] = []

    func hotkeyDidChange(_ hotkey: HotkeyConfiguration) {
        values.append(hotkey)
    }
}
