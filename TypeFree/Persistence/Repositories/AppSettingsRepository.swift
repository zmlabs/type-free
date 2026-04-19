import Foundation
import SwiftData

@MainActor
final class AppSettingsRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load() throws -> AppSettings {
        let all = try fetchAll()

        if all.isEmpty {
            let created = AppSettings.defaultValue()
            modelContext.insert(created)
            try modelContext.save()
            return created
        }

        let sorted = all.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString > $1.id.uuidString
        }

        let primary = sorted[0]

        if sorted.count > 1 {
            for duplicate in sorted.dropFirst() {
                modelContext.delete(duplicate)
            }
            try modelContext.save()
        }

        return primary
    }

    func save(_ settings: AppSettings) throws {
        settings.updatedAt = .now
        try modelContext.save()
    }

    private func fetchAll() throws -> [AppSettings] {
        try modelContext.fetch(FetchDescriptor<AppSettings>())
    }
}
