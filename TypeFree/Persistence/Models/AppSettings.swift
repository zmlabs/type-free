import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var hotkeyIdentifier: String
    var hotkeyDisplayName: String
    var activeProviderKind: String?
    var selectedSidebarSection: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        hotkeyIdentifier: String,
        hotkeyDisplayName: String,
        activeProviderKind: String? = nil,
        selectedSidebarSection: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.hotkeyIdentifier = hotkeyIdentifier
        self.hotkeyDisplayName = hotkeyDisplayName
        self.activeProviderKind = activeProviderKind
        self.selectedSidebarSection = selectedSidebarSection
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var activeProvider: ProviderKind {
        get { ProviderKind(rawValue: activeProviderKind ?? "") ?? .openAICompatible }
        set { activeProviderKind = newValue.rawValue }
    }

    var selectedSection: MainWindowSection {
        get { MainWindowSection(rawValue: selectedSidebarSection) ?? .overview }
        set { selectedSidebarSection = newValue.rawValue }
    }

    static func defaultValue(now: Date = .now) -> AppSettings {
        AppSettings(
            hotkeyIdentifier: HotkeyConfiguration.default.identifier,
            hotkeyDisplayName: HotkeyConfiguration.default.displayName,
            activeProviderKind: ProviderKind.openAICompatible.rawValue,
            selectedSidebarSection: MainWindowSection.overview.rawValue,
            createdAt: now,
            updatedAt: now
        )
    }
}
