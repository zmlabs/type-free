import Foundation
import SwiftData
import Testing
@testable import TypeFree

struct AppSettingsRepositoryTests {
    @Test @MainActor
    func loadCreatesDefaultSettingsWhenMissing() throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let repository = AppSettingsRepository(modelContext: modelContainer.mainContext)

        let settings = try repository.load()
        let storedSettings = try modelContainer.mainContext.fetch(FetchDescriptor<AppSettings>())

        #expect(settings.hotkeyIdentifier == HotkeyConfiguration.default.identifier)
        #expect(settings.hotkeyDisplayName == HotkeyConfiguration.default.displayName)
        #expect(settings.selectedSidebarSection == "overview")
        #expect(settings.activeProviderKind == ProviderKind.openAICompatible.rawValue)
        #expect(storedSettings.count == 1)
    }

    @Test @MainActor
    func savePersistsUpdatedSettingsWithoutCreatingDuplicates() throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let repository = AppSettingsRepository(modelContext: modelContainer.mainContext)
        let settings = try repository.load()
        let originalUpdatedAt = settings.updatedAt

        settings.hotkeyIdentifier = "rightCommand"
        settings.hotkeyDisplayName = "Right Command"
        settings.selectedSidebarSection = "permissions"
        settings.activeProviderKind = ProviderKind.qwen3ASR.rawValue
        try repository.save(settings)

        let reloaded = try repository.load()
        let storedSettings = try modelContainer.mainContext.fetch(FetchDescriptor<AppSettings>())

        #expect(reloaded.hotkeyIdentifier == "rightCommand")
        #expect(reloaded.hotkeyDisplayName == "Right Command")
        #expect(reloaded.selectedSidebarSection == "permissions")
        #expect(reloaded.activeProviderKind == ProviderKind.qwen3ASR.rawValue)
        #expect(reloaded.updatedAt > originalUpdatedAt)
        #expect(storedSettings.count == 1)
    }

    @Test(arguments: ["invalid-provider", nil] as [String?])
    @MainActor
    func loadNormalizesMissingOrInvalidActiveProviderKind(activeProviderKind: String?) throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let repository = AppSettingsRepository(modelContext: modelContainer.mainContext)
        let settings = AppSettings(
            hotkeyIdentifier: HotkeyConfiguration.default.identifier,
            hotkeyDisplayName: HotkeyConfiguration.default.displayName,
            activeProviderKind: activeProviderKind,
            selectedSidebarSection: "overview",
            createdAt: .now,
            updatedAt: .now
        )
        modelContainer.mainContext.insert(settings)
        try modelContainer.mainContext.save()

        let reloaded = try repository.load()

        #expect(reloaded.activeProvider == .openAICompatible)
    }
}
