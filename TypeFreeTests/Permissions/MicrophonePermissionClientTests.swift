import AVFoundation
import Testing
@testable import TypeFree

struct MicrophonePermissionClientTests {
    @Test(arguments: [
        (AVAuthorizationStatus.notDetermined, PermissionAuthorizationState.undetermined),
        (.authorized, .granted),
        (.denied, .denied),
        (.restricted, .denied),
    ])
    func statusMapsCaptureAuthorizationStatus(
        status: AVAuthorizationStatus,
        expected: PermissionAuthorizationState
    ) {
        let client = SystemMicrophonePermissionClient(
            authorizationController: FakeMicrophoneAuthorizationController(
                currentStatus: status
            )
        )

        #expect(client.status() == expected)
    }

    @Test
    func requestPermissionUsesCaptureAccessRequestResult() async {
        let probe = MicrophoneAuthorizationProbe()
        let client = SystemMicrophonePermissionClient(
            authorizationController: FakeMicrophoneAuthorizationController(
                currentStatus: .notDetermined,
                requestedResult: true,
                probe: probe
            )
        )

        let status = await client.requestPermission()

        #expect(status == .granted)
        #expect(await probe.requestCount() == 1)
    }

    @Test
    func requestPermissionReturnsDeniedWhenCaptureAccessIsRejected() async {
        let probe = MicrophoneAuthorizationProbe()
        let client = SystemMicrophonePermissionClient(
            authorizationController: FakeMicrophoneAuthorizationController(
                currentStatus: .notDetermined,
                requestedResult: false,
                probe: probe
            )
        )

        let status = await client.requestPermission()

        #expect(status == .denied)
        #expect(await probe.requestCount() == 1)
    }

    @Test(arguments: [
        (AVAuthorizationStatus.authorized, PermissionAuthorizationState.granted),
        (.denied, .denied),
        (.restricted, .denied),
    ])
    func requestPermissionReturnsResolvedStatusWithoutReprompting(
        status: AVAuthorizationStatus,
        expected: PermissionAuthorizationState
    ) async {
        let probe = MicrophoneAuthorizationProbe()
        let client = SystemMicrophonePermissionClient(
            authorizationController: FakeMicrophoneAuthorizationController(
                currentStatus: status,
                requestedResult: true,
                probe: probe
            )
        )

        let resolvedStatus = await client.requestPermission()

        #expect(resolvedStatus == expected)
        #expect(await probe.requestCount() == 0)
    }
}

private struct FakeMicrophoneAuthorizationController: MicrophoneAuthorizationControlling {
    let currentStatus: AVAuthorizationStatus
    var requestedResult = false
    let probe: MicrophoneAuthorizationProbe?

    init(
        currentStatus: AVAuthorizationStatus,
        requestedResult: Bool = false,
        probe: MicrophoneAuthorizationProbe? = nil
    ) {
        self.currentStatus = currentStatus
        self.requestedResult = requestedResult
        self.probe = probe
    }

    func status() -> AVAuthorizationStatus {
        currentStatus
    }

    func requestAccess() async -> Bool {
        await probe?.recordRequest()
        return requestedResult
    }
}

private actor MicrophoneAuthorizationProbe {
    private var count = 0

    func recordRequest() {
        count += 1
    }

    func requestCount() -> Int {
        count
    }
}
