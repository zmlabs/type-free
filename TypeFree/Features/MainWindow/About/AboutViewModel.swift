import AppKit
import Foundation
import Observation

@MainActor @Observable
final class AboutViewModel {
    struct AppInfo: Equatable {
        let name: String
        let version: String
        let iconImage: NSImage?

        @MainActor
        static func current(bundle: Bundle = .main) -> Self {
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? "TypeFree"
            let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
            return Self(
                name: name,
                version: version,
                iconImage: NSApplication.shared.applicationIconImage
            )
        }
    }

    let appInfo: AppInfo
    let repositoryURL: URL

    private let checkForUpdatesAction: @MainActor () -> Void
    private let openURLAction: @MainActor (URL) -> Void

    init(
        appInfo: AppInfo,
        repositoryURL: URL,
        checkForUpdates: @escaping @MainActor () -> Void,
        openURL: @escaping @MainActor (URL) -> Void = { url in
            NSWorkspace.shared.open(url)
        }
    ) {
        self.appInfo = appInfo
        self.repositoryURL = repositoryURL
        checkForUpdatesAction = checkForUpdates
        openURLAction = openURL
    }

    var versionLabel: String {
        "Version \(appInfo.version)"
    }

    func checkForUpdates() {
        checkForUpdatesAction()
    }

    func openRepository() {
        openURLAction(repositoryURL)
    }
}
