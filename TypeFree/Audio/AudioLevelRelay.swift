import Synchronization

nonisolated final class AudioLevelRelay: Sendable {
    private let level = Mutex<Float>(0)

    var currentLevel: Float {
        level.withLock { $0 }
    }

    func update(_ newLevel: Float) {
        level.withLock { $0 = newLevel }
    }

    func reset() {
        level.withLock { $0 = 0 }
    }
}
