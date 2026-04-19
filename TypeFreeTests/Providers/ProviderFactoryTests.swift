import Foundation
import Testing
@testable import TypeFree

@MainActor
struct ProviderFactoryTests {
    @Test
    func makeProviderBuildsOpenAICompatibleProviderForTheActiveConfiguration() async throws {
        let secretVault = TestProviderSecretVault(secrets: ["active-key": "sk-live"])
        let factory = ProviderFactory(secretVault: secretVault)
        let provider = try await factory.makeProvider(for: .fixture())

        #expect(provider.kind == .openAICompatible)
        #expect(await secretVault.readCount() == 1)
    }

    @Test
    func makeProviderBuildsQwen3ASRProviderForTheActiveConfiguration() async throws {
        let secretVault = TestProviderSecretVault(secrets: ["active-key": "sk-live"])
        let factory = ProviderFactory(secretVault: secretVault)
        let provider = try await factory.makeProvider(
            for: .fixture(
                kind: .qwen3ASR,
                baseURL: ProviderKind.qwen3ASR.defaultBaseURL,
                modelIdentifier: ProviderKind.qwen3ASR.defaultModelIdentifier
            )
        )

        #expect(provider.kind == .qwen3ASR)
        #expect(await secretVault.readCount() == 1)
    }

    @Test
    func makeProviderFailsWhenTheActiveCredentialCannotBeResolved() async {
        let secretVault = TestProviderSecretVault(secrets: [:])
        let factory = ProviderFactory(secretVault: secretVault)

        do {
            _ = try await factory.makeProvider(for: .fixture())
            Issue.record("Expected missing credential resolution to fail")
        } catch let error as TranscriptionProviderError {
            #expect(error == .missingCredential)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private actor TestProviderSecretVault: ProviderSecretVaulting {
    private let secrets: [String: String]
    private var reads = 0

    init(secrets: [String: String]) {
        self.secrets = secrets
    }

    func readSecret(reference: String) throws -> String? {
        reads += 1
        return secrets[reference]
    }

    func readCount() -> Int {
        reads
    }

    func writeSecret(_: String, reference _: String) throws {}

    func deleteSecret(reference _: String) throws {}
}

@MainActor
private extension ProviderConfigurationSnapshot {
    static func fixture(
        kind: ProviderKind = .openAICompatible,
        baseURL: String = "https://api.openai.com/v1/audio/transcriptions",
        modelIdentifier: String = "whisper-1",
        languageHint: String? = "en",
        timeoutSeconds: Int = 30,
        apiKeyReference: String = "active-key"
    ) -> ProviderConfigurationSnapshot {
        ProviderConfigurationSnapshot(
            kind: kind,
            baseURL: baseURL,
            modelIdentifier: modelIdentifier,
            languageHint: languageHint,
            requestTimeoutSeconds: timeoutSeconds,
            apiKeyReference: apiKeyReference
        )
    }
}
