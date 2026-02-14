import SwiftUI
import Carbon

/// Hotkey recorder view — allows the user to freely record any modifier + key combination
struct HotKeyRecorderView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack {
            Text("Show/Hide Window")

            Spacer()

            // Current hotkey / recording prompt
            Text(isRecording
                 ? String(localized: "Press a key combination…")
                 : (settings.customHotKey?.displayName ?? String(localized: "None")))
                .foregroundStyle(isRecording ? .orange : (settings.customHotKey == nil ? .secondary : .primary))
                .fontWeight(.medium)
                .frame(minWidth: 100, alignment: .trailing)

            if isRecording {
                Button(String(localized: "Stop")) {
                    stopRecording()
                }
                .controlSize(.small)
            } else {
                Button(String(localized: "Record")) {
                    startRecording()
                }
                .controlSize(.small)
            }

            if !isRecording {
                // Show "Clear" button when a hotkey is set
                if settings.customHotKey != nil {
                    Button(String(localized: "Clear")) {
                        settings.customHotKey = nil
                    }
                    .controlSize(.small)
                }

                // Show "Reset to Default" when value differs from default (including cleared state)
                if settings.customHotKey != .defaultHotKey {
                    Button(String(localized: "Reset to Default")) {
                        settings.customHotKey = .defaultHotKey
                    }
                    .controlSize(.small)
                }
            }
        }
        .onDisappear {
            // Ensure monitoring stops when the view disappears
            stopRecording()
        }
    }

    // MARK: - Recording Control

    /// Start recording: install local event monitor
    private func startRecording() {
        // Unregister current hotkey first to avoid interception during recording
        HotKeyManager.shared.reRegister(enabled: false)

        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleKeyEvent(event)
            return nil // Consume the event, do not propagate
        }
    }

    /// Stop recording: remove event monitor
    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        // Re-register the current hotkey
        HotKeyManager.shared.reRegister(enabled: true)
    }

    /// Handle captured key event
    private func handleKeyEvent(_ event: NSEvent) {
        // Esc cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        // Convert Cocoa NSEvent.ModifierFlags to Carbon modifier mask
        let carbonModifiers = cocoaToCarbonModifiers(event.modifierFlags)

        // Must contain at least one modifier key
        guard carbonModifiers != 0 else { return }

        let newHotKey = CustomHotKey(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers
        )

        guard newHotKey.isValid else { return }

        // Update settings (automatically triggers HotKeyManager.reRegister)
        settings.customHotKey = newHotKey
        stopRecording()
    }

    /// Convert Cocoa NSEvent.ModifierFlags to Carbon modifier mask
    private func cocoaToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }
}
