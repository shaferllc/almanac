import AppKit
import SwiftUI

// MARK: - Settings root

struct SettingsView: View {
    @ObservedObject var store: FormatStore

    var body: some View {
        TabView {
            FormatsTab(store: store)
                .tabItem { Label("Formats", systemImage: "list.bullet") }
            GeneralTab(store: store)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 620, height: 460)
    }
}

// MARK: - Formats tab

struct FormatsTab: View {
    @ObservedObject var store: FormatStore
    @State private var selection: UUID?
    @State private var editing: FormatPreset?
    @State private var editingIsNew = false

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(Array(store.data.formats.enumerated()), id: \.element.id) { index, preset in
                    FormatRow(preset: preset, index: index)
                        .tag(preset.id)
                        .contextMenu {
                            Button("Edit…") { beginEdit(preset) }
                            Button("Delete", role: .destructive) { store.remove(id: preset.id) }
                        }
                        .onTapGesture(count: 2) { beginEdit(preset) }
                }
                .onMove { indices, destination in
                    store.moveFormats(from: indices, to: destination)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack(spacing: 10) {
                Button { beginAdd() } label: { Image(systemName: "plus") }
                Button { removeSelected() } label: { Image(systemName: "minus") }
                    .disabled(selection == nil)
                Button("Edit…") {
                    if let preset = selectedPreset() { beginEdit(preset) }
                }
                .disabled(selection == nil)
                Spacer()
                Text("Drag to reorder. The first format is what the main hotkey inserts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
        .sheet(item: $editing) { preset in
            FormatEditor(store: store, preset: preset, isNew: editingIsNew)
        }
    }

    private func selectedPreset() -> FormatPreset? {
        guard let selection else { return nil }
        return store.data.formats.first { $0.id == selection }
    }

    private func beginAdd() {
        editingIsNew = true
        editing = FormatPreset(name: "New format")
    }

    private func beginEdit(_ preset: FormatPreset) {
        editingIsNew = false
        editing = preset
    }

    private func removeSelected() {
        guard let selection else { return }
        store.remove(id: selection)
        self.selection = nil
    }
}

private struct FormatRow: View {
    let preset: FormatPreset
    let index: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                HStack(spacing: 6) {
                    Text(preset.timeZone.shortLabel)
                    if preset.dayOffset != 0 {
                        Text(preset.offsetDescription)
                    }
                    if let combo = preset.hotKey, index < 5 {
                        Text(combo.description)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(Renderer.render(preset, at: context.date))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

// MARK: - Format editor sheet

struct FormatEditor: View {
    @ObservedObject var store: FormatStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: FormatPreset
    @State private var showZonePicker = false
    let isNew: Bool

    init(store: FormatStore, preset: FormatPreset, isNew: Bool) {
        self.store = store
        self.isNew = isNew
        _draft = State(initialValue: preset)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                    Picker("Type", selection: $draft.kind) {
                        ForEach(FormatKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    if draft.kind == .pattern {
                        TextField("Pattern", text: $draft.pattern)
                        Text("Unicode date pattern — e.g. yyyy-MM-dd, MMMM d, EEE, HH:mm, zzz")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if draft.kind != .unix {
                        LabeledContent("Time zone") {
                            Button(draft.timeZone.label) { showZonePicker = true }
                                .popover(isPresented: $showZonePicker, arrowEdge: .trailing) {
                                    TimeZonePicker(selection: $draft.timeZone, isPresented: $showZonePicker)
                                }
                        }
                    }
                    Stepper(value: $draft.dayOffset, in: -365...365) {
                        LabeledContent("Day offset", value: draft.offsetDescription)
                    }
                }

                Section {
                    LabeledContent("Hotkey") {
                        HotKeyRecorder(combo: $draft.hotKey)
                    }
                    Text("Per-format hotkeys apply to the first five formats in the list.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Preview") {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(Renderer.render(draft, at: context.date))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button(isNew ? "Add" : "Save") {
                    if isNew { store.add(draft) } else { store.update(draft) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 480, height: 500)
    }
}

// MARK: - Time zone picker

struct TimeZonePicker: View {
    @Binding var selection: TimeZoneSpec
    @Binding var isPresented: Bool
    @State private var query = ""

    private var matches: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.replacingOccurrences(of: "_", with: " ")
                .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            TextField("Search time zones", text: $query)
                .textFieldStyle(.roundedBorder)
            List {
                row(label: "System (\(TimeZone.current.identifier))", spec: .system, zone: .current)
                row(label: "UTC", spec: .utc, zone: TimeZone(identifier: "UTC"))
                ForEach(matches, id: \.self) { id in
                    row(label: id.replacingOccurrences(of: "_", with: " "),
                        spec: .named(id),
                        zone: TimeZone(identifier: id))
                }
            }
            .listStyle(.plain)
        }
        .padding(10)
        .frame(width: 320, height: 380)
    }

    private func row(label: String, spec: TimeZoneSpec, zone: TimeZone?) -> some View {
        Button {
            selection = spec
            isPresented = false
        } label: {
            HStack {
                Text(label).lineLimit(1)
                Spacer()
                if let zone {
                    Text(Self.gmtOffset(zone))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if selection == spec {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func gmtOffset(_ zone: TimeZone) -> String {
        let seconds = zone.secondsFromGMT()
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds < 0 ? "-" : "+"
        return minutes == 0
            ? "GMT\(sign)\(hours)"
            : "GMT\(sign)\(hours):\(String(format: "%02d", minutes))"
    }
}

// MARK: - General tab

struct GeneralTab: View {
    @ObservedObject var store: FormatStore

    private var modeBinding: Binding<InsertMode> {
        Binding(get: { store.data.insertMode }, set: { store.data.insertMode = $0 })
    }

    private var primaryBinding: Binding<KeyCombo?> {
        Binding(get: { store.data.primaryHotKey }, set: { store.data.primaryHotKey = $0 })
    }

    var body: some View {
        Form {
            Section("Inserting") {
                Picker("When inserting a date", selection: modeBinding) {
                    Text("Paste into the frontmost app").tag(InsertMode.paste)
                    Text("Copy to the clipboard only").tag(InsertMode.copyOnly)
                }
                .pickerStyle(.radioGroup)
                LabeledContent("Insert hotkey") {
                    HotKeyRecorder(combo: primaryBinding)
                }
                Text("The hotkey inserts the first format in your list. Default is ⌥⌘D.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Accessibility") {
                TimelineView(.periodic(from: .now, by: 2)) { _ in
                    accessibilityStatus
                }
                Button("Open Accessibility Settings") {
                    Inserter.openAccessibilitySettings()
                }
                Text("Pasting at the cursor works by synthesizing ⌘V, which macOS only allows for apps granted Accessibility. Without it, Almanac quietly falls back to copying the date so you can paste it yourself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var accessibilityStatus: some View {
        let trusted = Inserter.accessibilityTrusted
        return HStack(spacing: 8) {
            Circle()
                .fill(trusted ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            Text(trusted
                ? "Accessibility granted — paste-at-cursor is available."
                : "Accessibility not granted — Almanac will copy instead of paste.")
        }
    }
}

// MARK: - Hotkey recorder

struct HotKeyRecorder: View {
    @Binding var combo: KeyCombo?
    @State private var recording = false
    @State private var monitor = KeyDownMonitor()

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggle) {
                Text(recording ? "Type shortcut…" : (combo?.description ?? "None"))
                    .frame(minWidth: 110)
            }
            if combo != nil && !recording {
                Button {
                    combo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove hotkey")
            }
        }
        .onDisappear { stop() }
    }

    private func toggle() {
        recording ? stop() : start()
    }

    private func start() {
        recording = true
        monitor.start { keyCode, flags in
            // Escape cancels; Delete clears.
            if keyCode == 53 {
                stop()
                return true
            }
            if keyCode == 51 {
                combo = nil
                stop()
                return true
            }
            guard let newCombo = KeyCombo(keyCode: keyCode, flags: flags) else {
                NSSound.beep()
                return true
            }
            combo = newCombo
            stop()
            return true
        }
    }

    private func stop() {
        recording = false
        monitor.stop()
    }
}

/// Small helper owning an NSEvent local monitor; swallows key-downs while active.
@MainActor
final class KeyDownMonitor {
    private var monitor: Any?

    func start(_ onKeyDown: @escaping @MainActor (UInt16, NSEvent.ModifierFlags) -> Bool) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let handled = MainActor.assumeIsolated {
                onKeyDown(keyCode, flags)
            }
            return handled ? nil : event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
