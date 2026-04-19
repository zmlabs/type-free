import Foundation
import Testing
@testable import TypeFree

@MainActor
struct DictationStateMachineTests {
    @Test
    func hotkeyDownCreatesTentativeCaptureAndSchedulesTheHUDDelay() throws {
        var machine = DictationStateMachine()

        let commands = machine.handle(.hotkeyDown(timestamp: 1.0, activationScreenID: "screen-a"))
        let sessionID = try #require(machine.activeSessionID)

        #expect(machine.phase == .tentativeCapture)
        #expect(
            commands == [
                .startTentativeCapture(sessionID: sessionID, activationScreenID: "screen-a"),
                .scheduleHUDDelay(sessionID: sessionID, delay: .milliseconds(150)),
            ]
        )
    }

    @Test
    func hudDelayPromotesTentativeCaptureToVisibleRecording() throws {
        var machine = DictationStateMachine()

        _ = machine.handle(.hotkeyDown(timestamp: 1.0, activationScreenID: "screen-a"))
        let sessionID = try #require(machine.activeSessionID)

        let commands = machine.handle(.hudDelayElapsed(sessionID: sessionID))

        #expect(machine.phase == .recordingVisible)
        #expect(
            commands == [
                .showHUD(state: .recording, sessionID: sessionID, activationScreenID: "screen-a"),
            ]
        )
    }

    @Test
    func hotkeyUpTransitionsToTranscribingAndShowsTheTranscribingHUD() throws {
        var machine = DictationStateMachine()

        _ = machine.handle(.hotkeyDown(timestamp: 1.0, activationScreenID: "screen-a"))
        let sessionID = try #require(machine.activeSessionID)

        let commands = machine.handle(.hotkeyUp(timestamp: 1.1))

        #expect(machine.phase == .transcribing)
        #expect(
            commands == [
                .finishTentativeCapture(sessionID: sessionID),
                .showHUD(state: .transcribing, sessionID: sessionID, activationScreenID: "screen-a"),
                .beginTranscribing(sessionID: sessionID),
            ]
        )
    }

    @Test
    func otherKeyWhileHeldCancelsImmediatelyAndNeverShowsTheHUD() throws {
        var machine = DictationStateMachine()

        _ = machine.handle(.hotkeyDown(timestamp: 1.0, activationScreenID: "screen-a"))
        let sessionID = try #require(machine.activeSessionID)

        let commands = machine.handle(.otherKeyWhileHeld(timestamp: 1.1))

        #expect(machine.phase == .idle)
        #expect(machine.activeSessionID == nil)
        #expect(
            commands == [
                .cancelTentativeCapture(sessionID: sessionID, presentation: .hidden),
                .hideHUD,
            ]
        )
    }

    @Test
    func doublePressCancelsRecordingAndShowsCanceledHUD() throws {
        var machine = DictationStateMachine()

        _ = machine.handle(.hotkeyDown(timestamp: 1.0, activationScreenID: "screen-a"))
        let sessionID = try #require(machine.activeSessionID)
        _ = machine.handle(.hudDelayElapsed(sessionID: sessionID))

        let commands = machine.handle(.doublePress(timestamp: 1.2))

        #expect(machine.phase == .canceled)
        #expect(
            commands == [
                .cancelTentativeCapture(sessionID: sessionID, presentation: .canceled),
                .showHUD(state: .canceled, sessionID: sessionID, activationScreenID: "screen-a"),
            ]
        )
    }

    @Test
    func startRejectedShowsVisibleBlockedFeedback() throws {
        var machine = DictationStateMachine()

        let commands = machine.handle(
            .startRejected(
                activationScreenID: "screen-a",
                outcome: .permissionBlocked
            )
        )
        let sessionID = try #require(machine.activeSessionID)

        #expect(machine.phase == .permissionBlocked)
        #expect(
            commands == [
                .showHUD(
                    state: .permissionBlocked,
                    sessionID: sessionID,
                    activationScreenID: "screen-a"
                ),
            ]
        )
    }

    @Test
    func terminalNoSpeechOutcomeShowsVisibleFeedback() throws {
        var machine = DictationStateMachine()

        _ = machine.handle(.hotkeyDown(timestamp: 1.0, activationScreenID: "screen-a"))
        let sessionID = try #require(machine.activeSessionID)
        _ = machine.handle(.hotkeyUp(timestamp: 1.1))

        let commands = machine.handle(
            .terminalOutcome(sessionID: sessionID, outcome: .noSpeech)
        )

        #expect(machine.phase == .noSpeech)
        #expect(
            commands == [
                .showHUD(state: .noSpeech, sessionID: sessionID, activationScreenID: "screen-a"),
            ]
        )
    }

    @Test
    func autoDismissDelayReflectsStateSeverity() {
        #expect(HUDState.recording.autoDismissDelay == nil)
        #expect(HUDState.transcribing.autoDismissDelay == nil)
        #expect(HUDState.canceled.autoDismissDelay == .milliseconds(600))
        #expect(HUDState.noSpeech.autoDismissDelay == .milliseconds(1500))
        #expect(HUDState.permissionBlocked.autoDismissDelay == .seconds(3))
        #expect(HUDState.insertionFailed(.writeFailed).autoDismissDelay == .seconds(3))
    }

    @Test
    func completedOutcomeHidesTheHUDAndReturnsToIdle() throws {
        var machine = DictationStateMachine()

        _ = machine.handle(.hotkeyDown(timestamp: 1.0, activationScreenID: "screen-a"))
        let sessionID = try #require(machine.activeSessionID)
        _ = machine.handle(.hotkeyUp(timestamp: 1.1))

        let commands = machine.handle(
            .terminalOutcome(sessionID: sessionID, outcome: .completed(text: "hello"))
        )

        #expect(machine.phase == .idle)
        #expect(machine.activeSessionID == nil)
        #expect(commands == [.hideHUD])
    }
}
