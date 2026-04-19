import Testing
@testable import TypeFree

struct AudioLevelRelayTests {
    @Test
    func initialLevelIsZero() {
        let relay = AudioLevelRelay()
        #expect(relay.currentLevel == 0)
    }

    @Test
    func updateSetsCurrentLevel() {
        let relay = AudioLevelRelay()
        relay.update(0.75)
        #expect(relay.currentLevel == 0.75)
    }

    @Test
    func resetClearsLevelToZero() {
        let relay = AudioLevelRelay()
        relay.update(0.5)
        relay.reset()
        #expect(relay.currentLevel == 0)
    }
}
