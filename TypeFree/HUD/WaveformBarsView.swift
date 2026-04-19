import SwiftUI

struct WaveformBarsView: View {
    var barLevels: [Float]

    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3.5
    private let minBarHeight: CGFloat = 4
    private let maxBarHeight: CGFloat = 32

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0 ..< barLevels.count, id: \.self) { index in
                Capsule()
                    .frame(width: barWidth, height: barHeight(at: index))
            }
        }
        .accessibilityLabel("Recording audio")
    }

    private func barHeight(at index: Int) -> CGFloat {
        let level = CGFloat(max(0, min(1, barLevels[index])))
        return minBarHeight + (maxBarHeight - minBarHeight) * level
    }
}
