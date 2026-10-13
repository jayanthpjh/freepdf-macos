import AppKit
import UniformTypeIdentifiers

@MainActor
enum Dialogs {
    static func text(_ title: String, message: String = "", value: String = "", secure: Bool = false) -> String? {
        let alert = NSAlert()
        alert.messageText = title; alert.informativeText = message
        let field: NSTextField = secure ? NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 26)) : NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 26))
        field.stringValue = value
        field.setAccessibilityLabel(title)
        alert.accessoryView = field
        alert.addButton(withTitle: "Continue"); alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }
    static func confirm(_ title: String, _ message: String, button: String = "Continue") -> Bool {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = message
        alert.addButton(withTitle: button); alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
    static func error(_ error: Error) { NSAlert(error: error).runModal() }
    static func info(_ title: String, _ message: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = message; alert.runModal()
    }
    static func open(types: [UTType], multiple: Bool = false) -> [URL] {
        let panel = NSOpenPanel(); panel.allowedContentTypes = types
        panel.allowsMultipleSelection = multiple; panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.urls : []
    }
    static func save(name: String, type: UTType) -> URL? {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.allowedContentTypes = [type]
        return panel.runModal() == .OK ? panel.url : nil
    }
}
