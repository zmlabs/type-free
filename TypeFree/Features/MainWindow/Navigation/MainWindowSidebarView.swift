import SwiftUI

struct MainWindowSidebarView: View {
    @Binding var selection: MainWindowSection?
    let sections: [MainWindowSection]

    var body: some View {
        List(sections, selection: $selection) { section in
            Label(section.title, systemImage: section.symbolName)
                .tag(section)
                .accessibilityIdentifier(section.accessibilityIdentifier)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
        .listStyle(.sidebar)
        .accessibilityIdentifier(MainWindowAccessibilityIdentifiers.sidebar)
    }
}
