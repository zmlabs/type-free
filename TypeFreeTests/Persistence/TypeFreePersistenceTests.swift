import Foundation
import SwiftData
import Testing
@testable import TypeFree

struct TypeFreePersistenceTests {
    @Test @MainActor
    func bootstrapDefaultsCreatesSingletonSettingsAndAllProviderRows() throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let modelContext = modelContainer.mainContext

        try TypeFreePersistence.bootstrapDefaults(in: modelContext)

        let settings = try modelContext.fetch(FetchDescriptor<AppSettings>())
        let providers = try modelContext.fetch(FetchDescriptor<ProviderConfiguration>())

        #expect(settings.count == 1)
        #expect(providers.count == ProviderKind.allCases.count)
        #expect(Set(providers.map(\.providerKind)) == Set(ProviderKind.allCases.map(\.rawValue)))
    }

    @Test @MainActor
    func bootstrapDefaultsPreservesOpenAIConfigurationAndBackfillsQwenConfiguration() throws {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
        let modelContext = modelContainer.mainContext
        let existingOpenAI = ProviderConfiguration.defaultValue(kind: .openAICompatible)
        existingOpenAI.modelIdentifier = "custom-openai-model"
        modelContext.insert(existingOpenAI)
        modelContext.insert(
            AppSettings.defaultValue(now: .now)
        )
        try modelContext.save()

        try TypeFreePersistence.bootstrapDefaults(in: modelContext)

        let providers = try modelContext.fetch(FetchDescriptor<ProviderConfiguration>())
        let allSettings = try modelContext.fetch(FetchDescriptor<AppSettings>())

        #expect(allSettings.count == 1)
        #expect(providers.count == ProviderKind.allCases.count)
        #expect(Set(providers.map(\.providerKind)) == Set(ProviderKind.allCases.map(\.rawValue)))
        #expect(providers
            .contains {
                $0.providerKind == ProviderKind.openAICompatible.rawValue && $0.modelIdentifier == "custom-openai-model"
            })
        for kind in ProviderKind.allCases where kind != .openAICompatible {
            #expect(providers.contains { $0.providerKind == kind.rawValue })
        }
        #expect(allSettings.first?.activeProviderKind == ProviderKind.openAICompatible.rawValue)
    }
}
