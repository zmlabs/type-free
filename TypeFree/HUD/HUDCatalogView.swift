#if DEBUG
    import SwiftUI

    struct HUDCatalogView: View {
        static let samples: [(label: String, state: HUDState)] = [
            ("tentativeCapture", .tentativeCapture),
            ("recording", .recording),
            ("transcribing", .transcribing),
            ("canceled", .canceled),
            ("noSpeech", .noSpeech),
            ("permissionBlocked", .permissionBlocked),
            ("audioInputUnavailable", .audioInputUnavailable),
            ("provider.configuration", .providerFailed(.configuration())),
            ("provider.unauthorized", .providerFailed(.unauthorized())),
            ("provider.timeout", .providerFailed(.timeout())),
            ("provider.unavailable", .providerFailed(.unavailable())),
            ("provider.invalidResponse", .providerFailed(.invalidResponse())),
            ("insertion.targetUnavailable", .insertionFailed(.targetUnavailable)),
            ("insertion.targetNotEditable", .insertionFailed(.targetNotEditable)),
            ("insertion.writeFailed", .insertionFailed(.writeFailed)),
        ]

        let onSelect: (HUDState) -> Void
        let onHide: () -> Void

        @State private var selectedIndex = 0

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Picker("HUD State", selection: $selectedIndex) {
                    ForEach(Array(Self.samples.enumerated()), id: \.offset) { index, sample in
                        Text(sample.label).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedIndex) { _, newValue in
                    onSelect(Self.samples[newValue].state)
                }

                HStack {
                    Button("Show") {
                        onSelect(Self.samples[selectedIndex].state)
                    }
                    Button("Hide", action: onHide)
                    Spacer()
                }
            }
            .padding(20)
            .frame(width: 320)
        }
    }
#endif
