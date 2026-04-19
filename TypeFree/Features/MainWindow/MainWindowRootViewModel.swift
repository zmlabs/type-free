import Foundation
import Observation

@MainActor @Observable
final class MainWindowRootViewModel {
    let sections = MainWindowSection.allCases
    let overviewViewModel: OverviewViewModel
    let hotkeySettingsViewModel: HotkeySettingsViewModel
    let providerSettingsViewModel: ProviderSettingsViewModel
    let permissionsViewModel: PermissionsViewModel
    let aboutViewModel: AboutViewModel

    private(set) var selectedSection: MainWindowSection = .overview

    private let appSettingsRepository: AppSettingsRepository

    init(
        appSettingsRepository: AppSettingsRepository,
        overviewViewModel: OverviewViewModel,
        hotkeySettingsViewModel: HotkeySettingsViewModel,
        providerSettingsViewModel: ProviderSettingsViewModel,
        permissionsViewModel: PermissionsViewModel,
        aboutViewModel: AboutViewModel
    ) {
        self.appSettingsRepository = appSettingsRepository
        self.overviewViewModel = overviewViewModel
        self.hotkeySettingsViewModel = hotkeySettingsViewModel
        self.providerSettingsViewModel = providerSettingsViewModel
        self.permissionsViewModel = permissionsViewModel
        self.aboutViewModel = aboutViewModel
    }

    var navigationTitle: String {
        selectedSection.title
    }

    func refresh() {
        let selectedSidebarSection = (try? appSettingsRepository.load())?.selectedSidebarSection
        let restoredSection = selectedSidebarSection.flatMap(MainWindowSection.init(rawValue:))

        if let restoredSection {
            selectedSection = restoredSection
        } else {
            selectedSection = .overview
        }

        hotkeySettingsViewModel.refresh()
        providerSettingsViewModel.refresh()
        permissionsViewModel.refresh()
        overviewViewModel.refresh()
    }

    func select(_ section: MainWindowSection) {
        guard selectedSection != section else {
            refreshSelectedSection()
            return
        }

        selectedSection = section
        persistSelectedSection()
        refreshSelectedSection()
    }

    private func refreshSelectedSection() {
        switch selectedSection {
        case .overview:
            overviewViewModel.refresh()
        case .hotkey:
            hotkeySettingsViewModel.refresh()
        case .provider:
            providerSettingsViewModel.refresh()
        case .permissions:
            permissionsViewModel.refresh()
        case .about:
            break
        }
    }

    private func persistSelectedSection() {
        guard let settings = try? appSettingsRepository.load() else {
            return
        }

        settings.selectedSidebarSection = selectedSection.rawValue
        try? appSettingsRepository.save(settings)
    }
}
