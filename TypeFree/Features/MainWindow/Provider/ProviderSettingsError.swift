import Foundation
import SwiftUI

enum ProviderSettingsError: Error, Equatable {
    case invalidBaseURL
    case invalidTimeout
    case invalidModelIdentifier
    case missingCredential
    case invalidStoredCredential
    case invalidConfiguration
    case credentialStorageFailed
    case persistenceFailed
}

enum ProviderSettingsSaveMessageLevel: Equatable {
    case success
    case error
}

extension ProviderSettingsError {
    var message: LocalizedStringKey {
        switch self {
        case .invalidBaseURL:
            "Enter a valid HTTP or HTTPS transcription base URL."
        case .invalidTimeout:
            "Request timeout must be greater than 0 seconds."
        case .invalidModelIdentifier:
            "Enter a valid model identifier."
        case .missingCredential:
            "Provide a valid API key."
        case .invalidStoredCredential:
            "The stored API key is unreadable. Please re-enter and save."
        case .invalidConfiguration:
            "Invalid provider configuration. Check the URL, model, and credentials."
        case .credentialStorageFailed:
            "Unable to access the keychain. Check keychain status and try again."
        case .persistenceFailed:
            "Failed to save provider configuration. Please try again."
        }
    }
}
