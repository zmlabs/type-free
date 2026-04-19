import SwiftUI

struct StatusBadge: View {
    let text: LocalizedStringKey
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isPositive ? .green : .orange)
                .imageScale(.small)
            Text(text)
                .foregroundStyle(isPositive ? .primary : .secondary)
        }
    }
}
