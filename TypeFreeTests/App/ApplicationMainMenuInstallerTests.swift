import AppKit
import Testing
@testable import TypeFree

@Suite(.serialized)
@MainActor
struct ApplicationMainMenuInstallerTests {
    @Test
    func installIfNeededCreatesEditMenuWithStandardPasteAction() {
        let application = FakeMainMenuHost()

        ApplicationMainMenuInstaller.installIfNeeded(
            on: application,
            appName: "TypeFree"
        )

        let mainMenu = application.mainMenu
        #expect(mainMenu != nil)

        let editMenu = mainMenu?.item(withTitle: "Edit")?.submenu
        #expect(editMenu != nil)

        let pasteItem = editMenu?.item(withTitle: "Paste")
        #expect(pasteItem?.action == #selector(NSText.paste(_:)))
        #expect(pasteItem?.target == nil)
        #expect(pasteItem?.keyEquivalent == "v")
        #expect(pasteItem?.keyEquivalentModifierMask == [.command])
    }

    @Test
    func installIfNeededDoesNotReplaceAnExistingMainMenu() {
        let application = FakeMainMenuHost()
        let existingMenu = NSMenu(title: "Existing")
        application.mainMenu = existingMenu

        ApplicationMainMenuInstaller.installIfNeeded(
            on: application,
            appName: "TypeFree"
        )

        #expect(application.mainMenu === existingMenu)
    }
}

@MainActor
private final class FakeMainMenuHost: MainMenuHosting {
    var mainMenu: NSMenu?
}
