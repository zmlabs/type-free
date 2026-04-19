import Foundation

protocol WorkflowClock: Sendable {
    func sleep(for duration: Duration) async throws
}

struct SystemWorkflowClock: WorkflowClock {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
