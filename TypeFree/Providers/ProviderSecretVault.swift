import Foundation
import Security

protocol ProviderSecretVaulting: Actor {
    func readSecret(reference: String) throws -> String?
    func writeSecret(_ secret: String, reference: String) throws
    func deleteSecret(reference: String) throws
}

enum ProviderSecretVaultError: Error, Equatable {
    case invalidReference
    case invalidSecret
    case unexpectedStatus(OSStatus)
    case invalidSecretEncoding
}

actor ProviderSecretVault: ProviderSecretVaulting {
    private let service: String

    init(service: String = "TypeFree.ProviderSecretVault") {
        self.service = service
    }

    func readSecret(reference: String) throws -> String? {
        let normalizedReference = try normalizedReference(reference)
        let query = baseQuery(reference: normalizedReference).merging(
            [
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
        ) { _, new in new }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw ProviderSecretVaultError.invalidSecretEncoding
            }

            guard let secret = String(data: data, encoding: .utf8) else {
                throw ProviderSecretVaultError.invalidSecretEncoding
            }

            return secret
        case errSecItemNotFound:
            return nil
        default:
            throw ProviderSecretVaultError.unexpectedStatus(status)
        }
    }

    func writeSecret(_ secret: String, reference: String) throws {
        let normalizedReference = try normalizedReference(reference)
        let normalizedSecret = try normalizedSecret(secret)
        let data = Data(normalizedSecret.utf8)
        let query = baseQuery(reference: normalizedReference)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var item = query
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)

            guard addStatus == errSecSuccess else {
                throw ProviderSecretVaultError.unexpectedStatus(addStatus)
            }
        default:
            throw ProviderSecretVaultError.unexpectedStatus(updateStatus)
        }
    }

    func deleteSecret(reference: String) throws {
        let normalizedReference = try normalizedReference(reference)
        let status = SecItemDelete(baseQuery(reference: normalizedReference) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProviderSecretVaultError.unexpectedStatus(status)
        }
    }

    private func baseQuery(reference: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference,
        ]
    }

    private func normalizedReference(_ reference: String) throws -> String {
        let trimmedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedReference.isEmpty else {
            throw ProviderSecretVaultError.invalidReference
        }

        return trimmedReference
    }

    private func normalizedSecret(_ secret: String) throws -> String {
        guard !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderSecretVaultError.invalidSecret
        }

        return secret
    }
}
