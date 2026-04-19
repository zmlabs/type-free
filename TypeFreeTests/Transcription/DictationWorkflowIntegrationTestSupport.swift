import Foundation
@testable import TypeFree

@MainActor
final class IntegrationTestHUDPresenter: HUDPresenting {
    let activationScreenIDValue: String
    private(set) var presentedStates: [HUDState] = []
    private(set) var hideCallCount = 0

    init(activationScreenID: String) {
        activationScreenIDValue = activationScreenID
    }

    func activationScreenID() -> String {
        activationScreenIDValue
    }

    func present(state: HUDState, sessionID _: UUID, activationScreenID _: String) {
        presentedStates.append(state)
    }

    func hide() {
        hideCallCount += 1
    }
}

@MainActor
final class TestHUDPresenter: HUDPresenting {
    let activationScreenIDValue: String
    private(set) var presentedStates: [HUDState] = []
    private(set) var hideCallCount = 0

    init(activationScreenID: String) {
        activationScreenIDValue = activationScreenID
    }

    func activationScreenID() -> String {
        activationScreenIDValue
    }

    func present(state: HUDState, sessionID _: UUID, activationScreenID _: String) {
        presentedStates.append(state)
    }

    func hide() {
        hideCallCount += 1
    }
}

actor TestAudioCaptureService: AudioCapturing {
    private let preparedCaptureValue: PreparedCapture
    private var startedSessionIDs: [UUID] = []
    private var finishedSessionIDs: [UUID] = []
    private var canceledSessionIDs: [UUID] = []

    init(preparedCapture: PreparedCapture) {
        preparedCaptureValue = preparedCapture
    }

    func startTentativeCapture(sessionID: UUID, activationScreenID _: String) async throws {
        startedSessionIDs.append(sessionID)
    }

    func finishTentativeCapture(sessionID: UUID) async throws -> PreparedCapture {
        finishedSessionIDs.append(sessionID)
        return preparedCaptureValue
    }

    func cancelTentativeCapture(sessionID: UUID) async {
        canceledSessionIDs.append(sessionID)
    }

    func startedSessionCount() -> Int {
        startedSessionIDs.count
    }

    func finishedSessionCount() -> Int {
        finishedSessionIDs.count
    }

    func canceledSessionCount() -> Int {
        canceledSessionIDs.count
    }
}

actor RecordingTextInserter: AccessibilityTextInserting {
    private let shouldFail: Bool
    private var inserted: [String] = []

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func insert(text: String) async throws {
        if shouldFail {
            throw AccessibilityInsertionError.writeFailed
        }

        inserted.append(text)
    }

    func insertedTexts() -> [String] {
        inserted
    }
}

actor ImmediateTestProvider: TranscriptionProvider {
    let kind: ProviderKind = .openAICompatible

    private let outputValue: TranscriptionProviderOutput
    private var callCount = 0

    init(output: TranscriptionProviderOutput) {
        outputValue = output
    }

    func transcribe(capture _: PreparedCapture) async throws -> TranscriptionProviderOutput {
        callCount += 1
        return outputValue
    }

    func transcribeCallCount() -> Int {
        callCount
    }
}

actor BlockingTestProvider: TranscriptionProvider {
    let kind: ProviderKind = .openAICompatible

    private var callCount = 0
    private var cancelCount = 0
    private var continuation: CheckedContinuation<TranscriptionProviderOutput, Error>?

    func transcribe(capture _: PreparedCapture) async throws -> TranscriptionProviderOutput {
        callCount += 1
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            Task {
                await self.cancelPendingRequest()
            }
        }
    }

    func transcribeCallCount() -> Int {
        callCount
    }

    func cancellationCount() -> Int {
        cancelCount
    }

    private func cancelPendingRequest() {
        guard let continuation else {
            return
        }

        cancelCount += 1
        self.continuation = nil
        continuation.resume(throwing: CancellationError())
    }
}

actor IntegrationTestWorkflowClock: WorkflowClock {
    private struct PendingSleep {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private var pendingSleeps: [PendingSleep] = []

    func sleep(for _: Duration) async throws {
        let sleepID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pendingSleeps.append(
                    PendingSleep(id: sleepID, continuation: continuation)
                )
            }
        } onCancel: {
            Task {
                await self.cancelSleep(id: sleepID)
            }
        }
    }

    func resumeNext() async {
        while pendingSleeps.isEmpty {
            await Task.yield()
        }

        let pendingSleep = pendingSleeps.removeFirst()
        pendingSleep.continuation.resume()

        for _ in 0 ..< 10 {
            await Task.yield()
        }
    }

    private func cancelSleep(id: UUID) {
        guard let index = pendingSleeps.firstIndex(where: { $0.id == id }) else {
            return
        }

        let continuation = pendingSleeps.remove(at: index).continuation
        continuation.resume(throwing: CancellationError())
    }
}

@MainActor
extension PreparedCapture {
    static func fixture(
        activationScreenID: String = "screen-a",
        fileURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("integration-capture.wav")
    ) -> PreparedCapture {
        PreparedCapture(
            fileURL: fileURL,
            duration: 0.5,
            sampleRate: 16000,
            channelCount: 1,
            activationScreenID: activationScreenID
        )
    }
}

func eventually(
    _ condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    for _ in 0 ..< 200 {
        if await condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return false
}
