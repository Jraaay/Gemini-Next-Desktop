import SwiftUI

/// Settings view, displayed using the native macOS Settings Scene
struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @FocusState private var isUAFieldFocused: Bool
    @State private var isEditingUA = false
    @State private var showRestartHint = false

    /// Track whether the UA has been customized (differs from default)
    private var isCustomUA: Bool {
        settings.userAgent != settings.defaultUserAgent
    }

    var body: some View {
        Form {
            // MARK: - General Settings
            Section("General") {
                Picker("Background Timeout", selection: $settings.backgroundTimeout) {
                    ForEach(BackgroundTimeoutPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                Toggle("Launch at Login", isOn: $settings.launchAtLogin)

                Toggle("Always on Top", isOn: $settings.alwaysOnTop)

                Picker("Global Hotkey", selection: $settings.hotKeyPreset) {
                    ForEach(HotKeyPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .onChange(of: settings.language) {
                    showRestartHint = true
                }

                if showRestartHint {
                    Text("Language change takes effect after restarting the app")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Toggle("Auto Check for Updates", isOn: $settings.autoCheckForUpdates)
            }

            // MARK: - Advanced Settings
            Section("Advanced") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("User-Agent")
                        Spacer()
                        if isEditingUA {
                            Button("Done") {
                                isEditingUA = false
                            }
                            .font(.caption)
                        } else {
                            Button("Edit") {
                                isEditingUA = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isUAFieldFocused = true
                                }
                            }
                            .font(.caption)
                        }
                        if isCustomUA {
                            Button("Reset to Default") {
                                settings.userAgent = settings.defaultUserAgent
                            }
                            .font(.caption)
                        }
                    }
                    if isEditingUA {
                        TextEditor(text: $settings.userAgent)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 60)
                            .border(Color.secondary.opacity(0.3), width: 1)
                            .focused($isUAFieldFocused)
                        Text("Changes take effect after refreshing (Cmd+R)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(settings.userAgent)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isEditingUA = true
                                // Delay focus to the input field
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isUAFieldFocused = true
                                }
                            }
                    }
                }
            }

            // MARK: - About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Check for Updates")
                    Spacer()
                    Button {
                        updateChecker.checkForUpdate(silent: false)
                    } label: {
                        switch updateChecker.status {
                        case .checking:
                            HStack(spacing: 4) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Checking...")
                                    .foregroundStyle(.secondary)
                            }
                        case .upToDate:
                            Text("You're up to date")
                                .foregroundStyle(.green)
                        case .available(let version):
                            Text("v\(version)")
                                .foregroundStyle(.orange)
                        case .error(let msg):
                            Text(msg)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        case .idle:
                            Text("Check for Updates")
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(updateChecker.status == .checking)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 430)
        .onAppear {
            // Delay one frame to dismiss auto-focus on appearance
            DispatchQueue.main.async {
                isUAFieldFocused = false
                // Move focus away from TextField to the window itself
                NSApp.keyWindow?.makeFirstResponder(nil)

                // If always-on-top is enabled, elevate the settings window to floating level
                if settings.alwaysOnTop, let settingsWindow = NSApp.keyWindow {
                    settingsWindow.level = .floating
                }
            }
        }
    }

    /// Read version number from Bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
