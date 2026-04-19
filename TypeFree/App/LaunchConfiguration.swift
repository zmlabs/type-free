import Foundation

struct LaunchConfiguration {
    let arguments: Set<String>
    let environment: [String: String]

    init(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.arguments = Set(arguments)
        self.environment = environment
    }

    static var currentProcess: Self {
        Self(arguments: ProcessInfo.processInfo.arguments)
    }

    var usesInMemoryPersistence: Bool {
        arguments.contains("--ui-testing")
    }

    var opensMainWindowOnLaunch: Bool {
        arguments.contains("--ui-testing-open-main-window")
    }

    var disablesHotkeyMonitoring: Bool {
        arguments.contains("--ui-testing-disable-hotkey-monitor")
    }

    var skipsRuntimeBootstrap: Bool {
        !usesInMemoryPersistence && environment["XCTestConfigurationFilePath"] != nil
    }
}
