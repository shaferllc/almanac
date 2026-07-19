import AppKit
import SwiftUI

@main
struct AlmanacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu-bar-only app; all windows are managed by the delegate.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = FormatStore()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var settingsWindow: NSWindow?
    private var pickerWindow: NSWindow?
    private var pickerTarget: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "calendar.badge.clock",
            accessibilityDescription: "Almanac")
        menu.delegate = self
        item.menu = menu
        statusItem = item

        store.onChange = { [weak self] in self?.registerHotKeys() }
        registerHotKeys()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let now = Date()

        for preset in store.data.formats {
            let rendered = Renderer.render(preset, at: now)

            let item = NSMenuItem(title: rendered, action: #selector(menuInsert(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.id
            item.attributedTitle = menuTitle(rendered: rendered, name: preset.name)
            menu.addItem(item)

            // Hold ⌥ to copy instead of insert.
            let alt = NSMenuItem(title: "Copy \(rendered)", action: #selector(menuCopy(_:)), keyEquivalent: "")
            alt.target = self
            alt.representedObject = preset.id
            alt.isAlternate = true
            alt.keyEquivalentModifierMask = .option
            menu.addItem(alt)
        }

        menu.addItem(.separator())

        let pick = NSMenuItem(title: "Pick a Date…", action: #selector(openDatePicker), keyEquivalent: "")
        pick.target = self
        menu.addItem(pick)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit Almanac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func menuTitle(rendered: String, name: String) -> NSAttributedString {
        let title = NSMutableAttributedString(
            string: rendered,
            attributes: [.font: NSFont.menuFont(ofSize: 0)])
        title.append(NSAttributedString(
            string: "   \(name)",
            attributes: [
                .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]))
        return title
    }

    @objc private func menuInsert(_ sender: NSMenuItem) {
        guard let preset = preset(for: sender) else { return }
        Inserter.insert(Renderer.render(preset, at: Date()), mode: store.data.insertMode)
    }

    @objc private func menuCopy(_ sender: NSMenuItem) {
        guard let preset = preset(for: sender) else { return }
        Inserter.copy(Renderer.render(preset, at: Date()))
    }

    private func preset(for sender: NSMenuItem) -> FormatPreset? {
        guard let id = sender.representedObject as? UUID else { return nil }
        return store.data.formats.first { $0.id == id }
    }

    // MARK: - Hotkeys

    private func registerHotKeys() {
        HotKeyCenter.shared.unregisterAll()

        if let primary = store.data.primaryHotKey {
            HotKeyCenter.shared.register(primary) { [weak self] in
                guard let self, let first = self.store.data.formats.first else { return }
                Inserter.insert(Renderer.render(first, at: Date()), mode: self.store.data.insertMode)
            }
        }

        // Per-format hotkeys, honored for the first five formats.
        for preset in store.data.formats.prefix(5) {
            guard let combo = preset.hotKey else { continue }
            let id = preset.id
            HotKeyCenter.shared.register(combo) { [weak self] in
                guard let self,
                      let p = self.store.data.formats.first(where: { $0.id == id })
                else { return }
                Inserter.insert(Renderer.render(p, at: Date()), mode: self.store.data.insertMode)
            }
        }
    }

    // MARK: - Windows

    @objc func openSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(store: store))
            let window = NSWindow(contentViewController: host)
            window.title = "Almanac Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func openDatePicker() {
        // Remember which app should receive the insertion.
        pickerTarget = NSWorkspace.shared.frontmostApplication

        pickerWindow?.orderOut(nil)
        let view = DatePickerView(store: store) { [weak self] rendered, action in
            self?.commitFromPicker(rendered, action: action)
        }
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Insert a Date"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        pickerWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func commitFromPicker(_ rendered: String, action: DatePickerAction) {
        pickerWindow?.orderOut(nil)

        switch action {
        case .copy:
            Inserter.copy(rendered)
        case .insert:
            let mode = store.data.insertMode
            NSApp.hide(nil)
            pickerTarget?.activate()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                Inserter.insert(rendered, mode: mode)
            }
        }
    }
}
