import ApplicationServices
import Foundation

nonisolated enum AccessibilityInsertionError: Error, Equatable {
    case focusUnavailable
    case notEditable
    case writeFailed
}

nonisolated enum InsertionFailureCategory: String, Equatable {
    case targetUnavailable
    case targetNotEditable
    case writeFailed
}

protocol AccessibilityTextInserting: Sendable {
    func insert(text: String) async throws
}

extension AccessibilityInsertionError {
    var failureCategory: InsertionFailureCategory {
        switch self {
        case .focusUnavailable: .targetUnavailable
        case .notEditable: .targetNotEditable
        case .writeFailed: .writeFailed
        }
    }
}
