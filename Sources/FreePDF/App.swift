import AppKit
import PDFKit
import FreePDFCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var recoveryTimer: Timer?
    var finishedLaunching = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        let demo = CommandLine.arguments.contains("--demo") || Bundle.main.object(forInfoDictionaryKey: "FreePDFDemoOnLaunch") as? Bool == true
        finishedLaunching = true
        buildMenus()
        NSApp.activate(ignoringOtherApps: true)
        if !CommandLine.arguments.contains("--startup-test") && !demo { AppRecovery.restore() }
        recoveryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated { AppRecovery.checkpoint() }
        }
        if demo { openSampleDocument() }
        presentDocumentWindows()
    }
    func presentDocumentWindows() {
        let controller = NSDocumentController.shared
        if controller.documents.isEmpty { controller.newDocument(nil) }
        for document in controller.documents {
            if document.windowControllers.isEmpty { document.makeWindowControllers() }
            document.showWindows()
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { presentDocumentWindows() }
        return true
    }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    @objc func command(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? String,
              let controller = NSApp.keyWindow?.windowController as? EditorWindowController else { return }
        if action == "find" { controller.window?.makeFirstResponder(controller.search) }
        else { controller.perform(action) }
    }
    func buildMenus() {
        let main = NSMenu()
        NSApp.mainMenu = main
        func menu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: ""); let submenu = NSMenu(title: title)
            item.submenu = submenu; main.addItem(item); return submenu
        }
        func item(_ menu: NSMenu, _ title: String, _ selector: Selector, _ key: String = "", target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key); item.target = target; menu.addItem(item)
        }
        let app = menu("FreePDF")
        item(app, "About FreePDF", #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        app.addItem(.separator()); item(app, "Hide FreePDF", #selector(NSApplication.hide(_:)), "h")
        app.addItem(.separator()); item(app, "Quit FreePDF", #selector(NSApplication.terminate(_:)), "q")
        let file = menu("File")
        item(file, "New", #selector(NSDocumentController.newDocument(_:)), "n", target: NSDocumentController.shared)
        item(file, "Open…", #selector(NSDocumentController.openDocument(_:)), "o", target: NSDocumentController.shared)
        item(file, "Open sample document", #selector(openSampleDocument), target: self)
        file.addItem(.separator())
        item(file, "Close", #selector(NSWindow.performClose(_:)), "w")
        item(file, "Save", #selector(NSDocument.save(_:)), "s")
        let saveAs = NSMenuItem(title: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "s"); saveAs.keyEquivalentModifierMask = [.command, .shift]; file.addItem(saveAs)
        item(file, "Revert to Saved…", #selector(NSDocument.revertToSaved(_:)))
        file.addItem(.separator()); item(file, "Print…", #selector(NSDocument.printDocument(_:)), "p")
        let edit = menu("Edit")
        item(edit, "Undo", Selector(("undo:")), "z"); item(edit, "Redo", Selector(("redo:")), "Z")
        edit.addItem(.separator())
        item(edit, "Cut", #selector(NSText.cut(_:)), "x"); item(edit, "Copy", #selector(NSText.copy(_:)), "c"); item(edit, "Paste", #selector(NSText.paste(_:)), "v"); item(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        let find = NSMenuItem(title: "Find…", action: #selector(command(_:)), keyEquivalent: "f"); find.target = self; find.representedObject = "find"; edit.addItem(find)
        for (title, group) in [("Annotate", "annotateMenu"), ("Pages", "pagesMenu"), ("Tools", "toolsMenu"), ("Export", "exportMenu")] {
            let submenu = menu(title)
            // Menu and toolbar share the exact same commands.
            let groups: [(String, String)] = commandGroups(group)
            for (label, action) in groups { let item = NSMenuItem(title: label, action: #selector(command(_:)), keyEquivalent: ""); item.target = self; item.representedObject = action; submenu.addItem(item) }
        }
        let window = menu("Window"); NSApp.windowsMenu = window
        item(window, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        item(window, "Zoom", #selector(NSWindow.performZoom(_:)))
        item(window, "Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))
    }
    func commandGroups(_ group: String) -> [(String, String)] {
        // The command catalog has no window state; this is provided by the shared static helper below.
        EditorWindowController.commandCatalog(group)
    }
}

@main
struct FreePDFApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        if CommandLine.arguments.contains("--smoke-test") {
            delegate.buildMenus()
            do { try smokeTestApplication() }
            catch { fputs("Native smoke test failed: \(error)\n", stderr); exit(1) }
            return
        }
        if CommandLine.arguments.contains("--startup-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let documents = NSDocumentController.shared.documents
                let visible = documents.flatMap(\.windowControllers).compactMap(\.window).filter(\.isVisible)
                let counts = documents.map { "class=\(String(describing: type(of: $0))), windows=\($0.windowControllers.count)" }.joined(separator: ",")
                print("Startup: callback=\(delegate.finishedLaunching), documents=\(documents.count), visible=\(visible.count), active=\(application.isActive), defaultType=\(NSDocumentController.shared.defaultType ?? "nil"), \(counts)")
                for document in documents { document.updateChangeCount(.changeCleared); document.close() }
                exit(delegate.finishedLaunching && !visible.isEmpty ? 0 : 1)
            }
        }
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}
