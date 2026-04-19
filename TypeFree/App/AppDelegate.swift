import AppKit
import OSLog
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "dev.zhangyu.TypeFree",
        category: "AppDelegate"
    )

    private var runtime: AppBootstrap.Runtime?
    private let bootstrap = AppBootstrap()
    private let launchConfiguration = LaunchConfiguration.currentProcess

    func applicationDidFinishLaunching(_: Notification) {
        guard !launchConfiguration.skipsRuntimeBootstrap else {
            return
        }

        ApplicationMainMenuInstaller.installIfNeeded()

        do {
            runtime = try bootstrap.bootstrap(launchConfiguration: launchConfiguration)
            if launchConfiguration.opensMainWindowOnLaunch {
                runtime?.mainWindowCoordinator.showWindow()
            }
        } catch {
            Self.logger.error("Bootstrap failed: \(error)")
            let alert = NSAlert()
            alert.messageText = "TypeFree could not start"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
}
