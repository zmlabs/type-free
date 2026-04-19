import Foundation
import SwiftData

@MainActor
final class ProviderConfigurationRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load(kind: ProviderKind) throws -> ProviderConfiguration {
        let all = try fetchAll()
        let matches = all
            .filter { $0.providerKind == kind.rawValue }
            .sorted(by: configurationSortOrder)

        if let primary = matches.first {
            return primary
        }

        let created = ProviderConfiguration.defaultValue(kind: kind)
        modelContext.insert(created)
        try modelContext.save()
        return created
    }

    func loadAll() throws -> [ProviderConfiguration] {
        let fetched = try fetchAll()
        let sorted = fetched.sorted(by: configurationSortOrder)
        var primaryByKind: [ProviderKind: ProviderConfiguration] = [:]
        var duplicates: [ProviderConfiguration] = []

        for configuration in sorted {
            guard let kind = ProviderKind(rawValue: configuration.providerKind) else {
                continue
            }

            if primaryByKind[kind] == nil {
                primaryByKind[kind] = configuration
            } else {
                duplicates.append(configuration)
            }
        }

        var requiresSave = false

        for duplicate in duplicates {
            modelContext.delete(duplicate)
            requiresSave = true
        }

        for kind in ProviderKind.allCases where primaryByKind[kind] == nil {
            let created = ProviderConfiguration.defaultValue(kind: kind)
            modelContext.insert(created)
            primaryByKind[kind] = created
            requiresSave = true
        }

        for kind in ProviderKind.allCases {
            guard let configuration = primaryByKind[kind] else { continue }
            if normalize(configuration, for: kind) {
                requiresSave = true
            }
        }

        if requiresSave {
            try modelContext.save()
        }

        return ProviderKind.allCases.compactMap { primaryByKind[$0] }
    }

    func save(_ configuration: ProviderConfiguration) throws {
        configuration.updatedAt = .now
        try modelContext.save()
    }

    private func fetchAll() throws -> [ProviderConfiguration] {
        try modelContext.fetch(FetchDescriptor<ProviderConfiguration>())
    }

    private func configurationSortOrder(
        _ lhs: ProviderConfiguration,
        _ rhs: ProviderConfiguration
    ) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id.uuidString > rhs.id.uuidString
    }

    private func normalize(
        _ configuration: ProviderConfiguration,
        for kind: ProviderKind
    ) -> Bool {
        var didChange = false

        if configuration.enableITN == nil {
            configuration.enableITN = kind.defaultEnableITN
            didChange = true
        }

        return didChange
    }
}
