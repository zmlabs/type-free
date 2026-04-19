import Foundation

enum MainWindowSection: String, CaseIterable, Identifiable {
    case overview
    case hotkey
    case provider
    case permissions

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .hotkey:
            "Hotkey"
        case .provider:
            "Provider"
        case .permissions:
            "Permissions"
        }
    }

    var symbolName: String {
        switch self {
        case .overview:
            "circle.grid.2x2"
        case .hotkey:
            "keyboard"
        case .provider:
            "network"
        case .permissions:
            "lock.shield"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .overview:
            "main-window.sidebar.overview"
        case .hotkey:
            "main-window.sidebar.hotkey"
        case .provider:
            "main-window.sidebar.provider"
        case .permissions:
            "main-window.sidebar.permissions"
        }
    }
}
