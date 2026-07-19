import AppKit
import Carbon.HIToolbox

// MARK: - Key combo

struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let defaultPrimary = KeyCombo(
        keyCode: UInt32(kVK_ANSI_D),
        carbonModifiers: UInt32(cmdKey | optionKey)
    ) // ⌥⌘D

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    /// Builds a combo from key-down event data. Requires at least one of
    /// ⌘/⌥/⌃ so a bare letter can never become a global hotkey.
    init?(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        guard mods & UInt32(cmdKey | optionKey | controlKey) != 0 else { return nil }
        self.init(keyCode: UInt32(keyCode), carbonModifiers: mods)
    }

    var description: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        s += KeyCombo.keyNames[keyCode] ?? "key\(keyCode)"
        return s
    }

    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
        9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`", 51: "⌫", 53: "⎋", 36: "↩", 76: "⌤",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}

// MARK: - Hot key center (Carbon RegisterEventHotKey)

@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var installed = false
    private var registrations: [(ref: EventHotKeyRef, id: UInt32)] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1

    private init() {}

    func fire(_ id: UInt32) {
        handlers[id]?()
    }

    func unregisterAll() {
        for reg in registrations {
            UnregisterEventHotKey(reg.ref)
        }
        registrations.removeAll()
        handlers.removeAll()
    }

    @discardableResult
    func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> Bool {
        installIfNeeded()
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: 0x414C_4D43 /* 'ALMC' */, id: id)
        let status = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers, hkID,
            GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        registrations.append((ref, id))
        handlers[id] = handler
        return true
    }

    private func installIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), almanacHotKeyHandler, 1, &spec, nil, nil)
    }
}

private func almanacHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hkID = EventHotKeyID()
    let err = GetEventParameter(
        event, EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID), nil,
        MemoryLayout<EventHotKeyID>.size, nil, &hkID)
    guard err == noErr else { return err }
    let id = hkID.id
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            HotKeyCenter.shared.fire(id)
        }
    }
    return noErr
}
