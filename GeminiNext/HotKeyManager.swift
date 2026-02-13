import Cocoa
import Carbon

/// Global hotkey callback function conforming to @convention(c)
private func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    DispatchQueue.main.async {
        HotKeyManager.shared.onHotKeyPressed()
    }
    return noErr
}

class HotKeyManager {
    static let shared = HotKeyManager()
    private var hotKeyRef: EventHotKeyRef?
    /// Event handler only needs to be installed once
    private var handlerInstalled = false
    /// Prevent repeated triggers during animation
    private var isAnimating = false

    /// Animation duration (seconds), no more than 200ms
    private let animationDuration: TimeInterval = 0.15
    
    private init() {}
    
    /// Register hotkey on initial launch
    func register() {
        installHandlerIfNeeded()
        registerCurrentPreset()
    }

    /// Re-register hotkey (called when settings change)
    func reRegister() {
        unregisterHotKey()
        registerCurrentPreset()
    }

    // MARK: - Private Methods

    /// Install Carbon event handler (only once)
    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, nil)
        
        if status != noErr {
            print("Failed to install event handler: \(status)")
        } else {
            handlerInstalled = true
        }
    }

    /// Register hotkey based on current settings
    private func registerCurrentPreset() {
        let preset = SettingsManager.shared.hotKeyPreset
        let hotKeyID = EventHotKeyID(signature: OSType(0x53574654), id: 1)
        
        let regStatus = RegisterEventHotKey(
            preset.keyCode,
            preset.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if regStatus != noErr {
            print("Failed to register hotkey: \(regStatus)")
        } else {
            print("Global hotkey \(preset.displayName) registered successfully")
        }
    }

    /// Unregister the current hotkey
    private func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
    func onHotKeyPressed() {
        // If animation is in progress, ignore this trigger
        guard !isAnimating else { return }

        // Check if there are any visible windows
        let hasVisibleWindow = NSApp.windows.contains { $0.isVisible } && NSApp.isActive

        if hasVisibleWindow {
            // App is in the foreground with visible windows → hide
            hideWithAnimation()
        } else {
            // Otherwise (background / window not visible) → activate and show
            showWithAnimation()
        }
    }

    // MARK: - Animation Methods

    /// Show window with fade-in animation
    private func showWithAnimation() {
        let useAnimation = SettingsManager.shared.windowAnimation

        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows where window.delegate is AppDelegate {
            if useAnimation {
                // Set fully transparent first, then fade in
                window.alphaValue = 0
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

            if useAnimation {
                isAnimating = true
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = animationDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().alphaValue = 1.0
                }, completionHandler: { [weak self] in
                    self?.isAnimating = false
                })
            } else {
                window.alphaValue = 1.0
            }
        }
    }

    /// Hide window with fade-out animation
    private func hideWithAnimation() {
        let useAnimation = SettingsManager.shared.windowAnimation

        if useAnimation {
            isAnimating = true
            // Perform fade-out animation on all main windows
            for window in NSApp.windows where window.delegate is AppDelegate {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = animationDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    window.animator().alphaValue = 0
                }, completionHandler: { [weak self] in
                    NSApp.hide(nil)
                    // Restore alphaValue for the next show
                    window.alphaValue = 1.0
                    self?.isAnimating = false
                })
            }
        } else {
            NSApp.hide(nil)
        }
    }
}
