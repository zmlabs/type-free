import SwiftUI

struct HUDRootView: View {
    let viewModel: HUDViewModel

    private let pillHeight: CGFloat = 30
    private let recordingWidth: CGFloat = 100

    var body: some View {
        pill
            .frame(height: pillHeight)
            .glassEffect(.regular, in: .capsule)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(duration: 0.35, bounce: 0.15), value: viewModel.state)
    }

    @ViewBuilder
    private var pill: some View {
        if isRecording {
            WaveformBarsView(barLevels: viewModel.barLevels)
                .frame(width: recordingWidth)
                .transition(.blurReplace)
        } else {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(symbolColor)
                    .contentTransition(.symbolEffect(.replace))

                Text(viewModel.message)
                    .font(.footnote.weight(.medium))
                    .id(viewModel.message)
                    .transition(.blurReplace)
            }
            .padding(.horizontal, 16)
            .accessibilityElement(children: .combine)
            .transition(.blurReplace)
        }
    }

    private var isRecording: Bool {
        viewModel.state == .recording || viewModel.state == .tentativeCapture
    }

    private var symbolName: String {
        switch viewModel.state {
        case .hidden, .tentativeCapture, .recording:
            "circle"
        case .transcribing:
            "waveform.and.magnifyingglass"
        case .canceled:
            "xmark.circle.fill"
        case .noSpeech:
            "bubble.left.and.exclamationmark.bubble.right"
        case .permissionBlocked:
            "lock.fill"
        case let .providerFailed(failure):
            providerSymbol(for: failure.category)
        case let .insertionFailed(category):
            insertionSymbol(for: category)
        }
    }

    private func providerSymbol(for category: ProviderFailureCategory) -> String {
        switch category {
        case .configuration: "gear.badge.xmark"
        case .unauthorized: "lock.trianglebadge.exclamationmark.fill"
        case .timeout: "clock.badge.exclamationmark.fill"
        case .unavailable: "wifi.exclamationmark"
        case .invalidResponse: "questionmark.diamond.fill"
        }
    }

    private func insertionSymbol(for category: InsertionFailureCategory) -> String {
        switch category {
        case .targetUnavailable: "character.cursor.ibeam"
        case .targetNotEditable, .writeFailed: "pencil.slash"
        }
    }

    private var symbolColor: Color {
        switch viewModel.state {
        case .transcribing:
            .blue
        case .canceled:
            .orange
        case .hidden, .tentativeCapture, .recording:
            .clear
        case .noSpeech, .permissionBlocked, .providerFailed, .insertionFailed:
            .orange
        }
    }
}
