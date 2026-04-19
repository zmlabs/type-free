import Foundation
import Testing
@testable import TypeFree

@MainActor
struct AccessibilityTextInserterTests {
    @Test
    func insertionErrorsExposeStableFailureCategoriesAndGuidance() {
        #expect(AccessibilityInsertionError.focusUnavailable.failureCategory == .targetUnavailable)
        #expect(AccessibilityInsertionError.notEditable.failureCategory == .targetNotEditable)
        #expect(AccessibilityInsertionError.writeFailed.failureCategory == .writeFailed)
    }
}
