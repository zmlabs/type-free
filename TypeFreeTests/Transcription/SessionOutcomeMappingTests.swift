import Testing
@testable import TypeFree

struct SessionOutcomeMappingTests {
    @Test(arguments: [
        (SessionOutcome.canceled, HUDState.canceled, DictationPhase.canceled),
        (SessionOutcome.noSpeech, HUDState.noSpeech, DictationPhase.noSpeech),
        (SessionOutcome.permissionBlocked, HUDState.permissionBlocked, DictationPhase.permissionBlocked),
        (
            SessionOutcome.providerFailed(.timeout()),
            HUDState.providerFailed(.timeout()),
            DictationPhase.providerFailed
        ),
        (
            SessionOutcome.insertionFailed(.targetNotEditable),
            HUDState.insertionFailed(.targetNotEditable),
            DictationPhase.insertionFailed
        ),
    ])
    func outcomeMappingProducesVisibleStates(
        outcome: SessionOutcome,
        expectedHUDState: HUDState,
        expectedPhase: DictationPhase
    ) {
        #expect(outcome.workflowHUDState == expectedHUDState)
        #expect(outcome.workflowPhase == expectedPhase)
    }

    @Test
    func completedOutcomeDoesNotRequestFailurePresentation() {
        let outcome = SessionOutcome.completed(text: "hello")

        #expect(outcome.workflowHUDState == nil)
        #expect(outcome.workflowPhase == .idle)
    }
}
