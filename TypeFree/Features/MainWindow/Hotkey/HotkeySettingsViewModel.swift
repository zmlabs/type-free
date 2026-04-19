import AppKit
import Foundation
import Observation
import SwiftUI

struct HotkeyOption: Identifiable, Equatable {
    let configuration: HotkeyConfiguration

    var id: String {
        configuration.identifier
    }
}

enum HotkeySettingsError: Error, Equatable {
    case unsupportedHotkeyIdentifier(String)
}

@MainActor @Observable
final class HotkeySettingsViewModel {
    let presetHotkeys = HotkeyConfiguration.supported.map(HotkeyOption.init(configuration:))

    private(set) var selectedHotkeyIdentifier = HotkeyConfiguration.default.identifier
    private(set) var validationMessage: LocalizedStringKey?
    private(set) var lastPersistenceError: String?
    var isRecording = false
    var customHotkeyOption: HotkeyOption?

    var availableHotkeys: [HotkeyOption] {
        if let custom = customHotkeyOption {
            return presetHotkeys + [custom]
        }
        return presetHotkeys
    }

    var isCustomHotkeySelected: Bool {
        customHotkeyOption != nil && selectedHotkeyIdentifier == customHotkeyOption?.id
    }

    var onHotkeyBroadcast: (HotkeyConfiguration) -> Void = { _ in }

    private let repository: AppSettingsRepository
    private let broadcaster: HotkeyChangeBroadcaster
    private var recordingMonitor: Any?

    init(
        repository: AppSettingsRepository,
        broadcaster: HotkeyChangeBroadcaster
    ) {
        self.repository = repository
        self.broadcaster = broadcaster
    }

    func refresh() {
        stopRecording()
        guard let settings = try? repository.load() else {
            selectedHotkeyIdentifier = HotkeyConfiguration.default.identifier
            customHotkeyOption = nil
            validationMessage = nil
            return
        }

        selectedHotkeyIdentifier = settings.hotkeyIdentifier

        if presetHotkeys.contains(where: { $0.id == settings.hotkeyIdentifier }) {
            customHotkeyOption = nil
        } else {
            customHotkeyOption = HotkeyOption(
                configuration: HotkeyConfiguration(
                    identifier: settings.hotkeyIdentifier,
                    displayName: settings.hotkeyDisplayName
                )
            )
        }

        validationMessage = nil
    }

    func commitSelection(_ identifier: String) {
        selectedHotkeyIdentifier = identifier
        guard let option = availableHotkeys.first(where: { $0.configuration.identifier == identifier }) else {
            validationMessage = "Unsupported key."
            lastPersistenceError = HotkeySettingsError.unsupportedHotkeyIdentifier(identifier).localizedDescription
            return
        }
        do {
            let settings = try repository.load()
            settings.hotkeyIdentifier = option.configuration.identifier
            settings.hotkeyDisplayName = option.configuration.displayName
            try repository.save(settings)
            validationMessage = nil
            lastPersistenceError = nil
            broadcaster.broadcast(option.configuration)
            onHotkeyBroadcast(option.configuration)
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func startRecording() {
        isRecording = true
        recordingMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.processRecordingEvent(event)
            }
            return nil
        }
    }

    func cancelRecording() {
        stopRecording()
    }

    func removeCustomHotkey() {
        customHotkeyOption = nil
        if !presetHotkeys.contains(where: { $0.id == selectedHotkeyIdentifier }) {
            selectedHotkeyIdentifier = HotkeyConfiguration.default.identifier
        }
    }
}

extension HotkeySettingsViewModel: HotkeyChangeObserver {
    func hotkeyDidChange(_: HotkeyConfiguration) {
        refresh()
    }
}

private extension HotkeySettingsViewModel {
    func processRecordingEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 {
            cancelRecording()
            return
        }

        if event.type == .flagsChanged {
            guard isModifierKeyPress(
                keyCode: CGKeyCode(event.keyCode),
                modifierFlags: event.modifierFlags
            ) else {
                return
            }
        }

        let keyCode = CGKeyCode(event.keyCode)
        let identifier = physicalKeyIdentifier(for: keyCode)

        if presetHotkeys.contains(where: { $0.id == identifier }) {
            customHotkeyOption = nil
        } else {
            let config = HotkeyConfiguration.custom(
                keyCode: keyCode,
                characters: event.characters
            )
            customHotkeyOption = HotkeyOption(configuration: config)
        }

        stopRecording()
        commitSelection(identifier)
    }

    func stopRecording() {
        if let recordingMonitor {
            NSEvent.removeMonitor(recordingMonitor)
        }
        recordingMonitor = nil
        isRecording = false
    }
}
