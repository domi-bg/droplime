import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    /// Formate, die auf diesem Mac erzeugt werden können.
    let available: Set<Format>
    /// Zusatzwerkzeug → gefunden?
    let tools: [(name: String, found: Bool, install: String)]

    /// Welches Werkzeug ein sonst nicht verfügbares Format freischaltet.
    private static let requiredTool: [String: String] = [
        "mkv": "FFmpeg", "webm": "FFmpeg", "mp3": "FFmpeg", "flac": "FFmpeg", "ogg": "FFmpeg", "opus": "FFmpeg",
        "xlsx": "LibreOffice", "ods": "LibreOffice", "csv": "LibreOffice", "pptx": "LibreOffice",
        "md": "Pandoc", "epub": "Pandoc",
    ]

    var body: some View {
        Form {
            Section(L.settingsLanguage) {
                Picker(L.settingsLanguage, selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
            }

            Section(L.settingsAfterConversion) {
                Picker(L.settingsAfterConversion, selection: $settings.afterConversion) {
                    ForEach(AfterConversion.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section {
                ForEach(Format.groups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.title).font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4), spacing: 6) {
                            ForEach(group.formats, id: \.self) { formatToggle($0) }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text(L.settingsFormats)
            } footer: {
                Text(L.settingsFormatsFooter)
                    .foregroundStyle(.secondary)
            }

            Section(L.settingsTools) {
                ForEach(tools, id: \.name) { tool in
                    HStack {
                        Text(tool.name)
                        Spacer()
                        if tool.found {
                            Label(L.toolFound, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Text(tool.install).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text(L.restartAfterInstall).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func formatToggle(_ format: Format) -> some View {
        let isAvailable = available.contains(format)
        Toggle(isOn: Binding(get: { isAvailable && settings.isEnabled(format) },
                             set: { settings.setEnabled(format, $0) })) {
            Text(format.label)
        }
        .toggleStyle(.checkbox)
        .disabled(!isAvailable)
        .help(isAvailable ? "" : Self.requiredTool[format.ext].map(L.needsTool) ?? L.notAvailableHere)
    }
}
