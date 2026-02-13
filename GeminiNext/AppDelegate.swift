import SwiftUI
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// Sparkle updater controller, initialized at app launch
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register global hotkeys
        HotKeyManager.shared.register()

        // Delay one frame to configure delegate and window level after SwiftUI creates the main window
        DispatchQueue.main.async {
            self.configureMainWindow()
            // Restore window always-on-top state
            SettingsManager.shared.updateWindowLevel()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            return true
        } else {
            if let window = sender.windows.first(where: { $0.canBecomeKey }) {
                window.makeKeyAndOrderFront(nil)
                return false
            }
            return true
        }
    }

    // MARK: - NSWindowDelegate

    /// Intercept window close event: hide the app instead of destroying it to preserve WebView lifecycle
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if SettingsManager.shared.windowAnimation {
            // Perform fade-out animation then hide
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                sender.animator().alphaValue = 0
            }, completionHandler: {
                NSApp.hide(nil)
                // Restore alphaValue for the next show
                sender.alphaValue = 1.0
            })
        } else {
            NSApp.hide(nil)
        }
        return false
    }

    // MARK: - Private Methods

    /// Find the main window and set AppDelegate as its delegate
    private func configureMainWindow() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeKey }) else { return }
        window.delegate = self
    }
}
