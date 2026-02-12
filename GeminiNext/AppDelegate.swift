import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register global hotkeys
        HotKeyManager.shared.register()

        // Delay one frame to configure delegate and window level after SwiftUI creates the main window
        DispatchQueue.main.async {
            self.configureMainWindow()
            // Restore window always-on-top state
            SettingsManager.shared.updateWindowLevel()
            // 仅在用户未关闭自动更新时静默检查
            if SettingsManager.shared.autoCheckForUpdates {
                UpdateChecker.shared.checkForUpdate(silent: true)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            return true
        } else {
            // If no visible windows (hidden), try to bring it back
            if let window = sender.windows.first(where: { $0.canBecomeKey }) {
                window.makeKeyAndOrderFront(nil)
                return false // Return false to prevent SwiftUI from creating a new window
            }
            return true
        }
    }

    // MARK: - NSWindowDelegate

    /// Intercept window close event: hide the app instead to prevent WebView from being destroyed
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(nil)
        return false
    }

    // MARK: - Private Methods

    /// Find the main window and set AppDelegate as its delegate
    private func configureMainWindow() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeKey }) else { return }
        window.delegate = self
    }
}
