import SwiftUI
import Sparkle
import Combine
import WebKit

/// SwiftUI wrapper for Sparkle's "Check for Updates" button
/// Follows Sparkle's officially recommended SwiftUI integration approach
struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

/// Observes the Sparkle updater's canCheckForUpdates state
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private var cancellable: Any?

    init(updater: SPUUpdater) {
        // Use KVO to observe canCheckForUpdates property changes
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .assign(to: \.canCheckForUpdates, on: self)
    }
}

/// Settings view, displayed using the native macOS Settings Scene
struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @FocusState private var isUAFieldFocused: Bool
    @State private var isEditingUA = false
    @State private var showRestartHint = false
    @State private var showClearDataConfirmation = false
    @State private var showClearDataSuccess = false
    @State private var isClearingData = false

    /// Sparkle updater instance, injected from parent
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

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

                Toggle("Window Animation", isOn: $settings.windowAnimation)

                HotKeyRecorderView(
                    label: "Show/Hide Window",
                    hotKey: $settings.customHotKey,
                    defaultHotKey: .defaultHotKey
                )

                HotKeyRecorderView(
                    label: "New Chat",
                    hotKey: $settings.newChatHotKey,
                    defaultHotKey: .newChatDefaultHotKey
                )

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

                // Auto check for updates toggle, bound directly to Sparkle's automaticallyChecksForUpdates
                Toggle("Auto Check for Updates", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))
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

                // MARK: - Clear Browsing Data

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear Browsing Data")
                        Text("Remove cookies, cache and local storage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if showClearDataSuccess {
                        Label("Cleared", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                    Button(role: .destructive) {
                        showClearDataConfirmation = true
                    } label: {
                        Text("Clear Data")
                    }
                    .disabled(isClearingData)
                }
                .confirmationDialog(
                    "Are you sure you want to clear all browsing data?",
                    isPresented: $showClearDataConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear Data", role: .destructive) {
                        clearBrowsingData()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove cookies, cache and local storage. You will need to sign in again.")
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

                Toggle("Receive Beta Updates", isOn: $settings.betaChannel)

                HStack {
                    Text("Check for Updates")
                    Spacer()
                    CheckForUpdatesView(updater: updater)
                        .buttonStyle(.borderless)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 480)
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

    /// Clear all browsing data (cookies, cache, localStorage) and notify WebView to reload
    private func clearBrowsingData() {
        isClearingData = true
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            dataStore.removeData(
                ofTypes: dataTypes,
                for: records
            ) {
                DispatchQueue.main.async {
                    isClearingData = false
                    withAnimation {
                        showClearDataSuccess = true
                    }
                    // Hide success indicator after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showClearDataSuccess = false
                        }
                    }
                    // Notify WebViewModel to reload the page
                    NotificationCenter.default.post(name: .browsingDataCleared, object: nil)
                }
            }
        }
    }
}
