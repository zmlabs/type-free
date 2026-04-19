import Foundation

enum PermissionAuthorizationState: String, Equatable, Codable {
    case undetermined
    case granted
    case denied

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

struct PermissionSnapshot: Equatable {
    nonisolated let microphone: PermissionAuthorizationState
    nonisolated let accessibility: PermissionAuthorizationState

    nonisolated var isReadyForDictation: Bool {
        microphone == .granted && accessibility == .granted
    }
}
