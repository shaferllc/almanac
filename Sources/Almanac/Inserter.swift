import AppKit
import ApplicationServices

/// Puts a rendered date string into the frontmost app: saves the pasteboard,
/// writes the string, synthesizes ⌘V, then restores the old contents. Falls
/// back to copy-only when Accessibility is not granted or the user prefers it.
@MainActor
enum Inserter {
    static var accessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Copies the string, replacing the pasteboard (no restore).
    static func copy(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }

    /// Inserts according to mode. In `.paste` mode with Accessibility granted,
    /// this pastes at the cursor and restores the prior pasteboard after a beat.
    static func insert(_ string: String, mode: InsertMode) {
        guard mode == .paste, accessibilityTrusted else {
            copy(string)
            return
        }

        let pb = NSPasteboard.general
        // Best-effort snapshot of current pasteboard contents.
        let saved: [NSPasteboardItem] = (pb.pasteboardItems ?? []).map { item in
            let clone = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    clone.setData(data, forType: type)
                }
            }
            return clone
        }

        pb.clearContents()
        pb.setString(string, forType: .string)

        Task { @MainActor in
            // Give the menu/hotkey event a beat to settle so the target app
            // has keyboard focus again, then paste.
            try? await Task.sleep(for: .milliseconds(180))
            sendPasteKeystroke()
            // Let the target app read the pasteboard before restoring.
            try? await Task.sleep(for: .milliseconds(700))
            pb.clearContents()
            if !saved.isEmpty {
                pb.writeObjects(saved)
            }
        }
    }

    private static func sendPasteKeystroke() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKeyCode: CGKeyCode = 9 // ANSI V
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
