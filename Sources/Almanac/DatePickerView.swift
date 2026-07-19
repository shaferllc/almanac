import SwiftUI

enum DatePickerAction {
    case insert
    case copy
}

/// "Pick a date" window: calendar + time, then insert or copy any saved
/// format rendered at the chosen moment.
struct DatePickerView: View {
    @ObservedObject var store: FormatStore
    @State private var date = Date()
    let onCommit: (String, DatePickerAction) -> Void

    var body: some View {
        VStack(spacing: 10) {
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()

            DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                .frame(maxWidth: 180)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(store.data.formats) { preset in
                        formatRow(preset)
                    }
                }
            }
            .frame(maxHeight: 220)

            Text("Insert pastes into the app that was frontmost. Copy just fills the clipboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .frame(width: 360)
    }

    private func formatRow(_ preset: FormatPreset) -> some View {
        let rendered = Renderer.render(preset, at: date)
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(rendered)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
            }
            Spacer()
            Button {
                onCommit(rendered, .insert)
            } label: {
                Image(systemName: "text.insert")
            }
            .help("Insert into the frontmost app")
            Button {
                onCommit(rendered, .copy)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy to the clipboard")
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
    }
}
