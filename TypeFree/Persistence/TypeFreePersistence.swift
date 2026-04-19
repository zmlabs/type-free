import SwiftData

enum TypeFreePersistence {
    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            AppSettings.self,
            ProviderConfiguration.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    static func bootstrapDefaults(in modelContext: ModelContext) throws {
        _ = try AppSettingsRepository(modelContext: modelContext).load()
        _ = try ProviderConfigurationRepository(modelContext: modelContext).loadAll()
    }
}
