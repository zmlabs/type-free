import Foundation
import SwiftUI

enum MainWindowSection: String, CaseIterable, Identifiable {
    case overview
    case hotkey
    case provider
    case permissions
    case about

    var id: String {
        rawValue
    }

    var title: LocalizedStringKey {
        switch self {
        case .overview:
            "Overview"
        case .hotkey:
            "Hotkey"
        case .provider:
            "Provider"
        case .permissions:
            "Permissions"
        case .about:
            "About"
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
        case .about:
            "info.circle"
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
        case .about:
            "main-window.sidebar.about"
        }
    }
}
