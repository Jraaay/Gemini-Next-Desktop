import SwiftUI
import Combine
import Carbon
import ServiceManagement

/// Global hotkey preset options
enum HotKeyPreset: String, CaseIterable, Identifiable {
    case ctrlGrave     = "ctrl_grave"      // Ctrl + `
    case ctrlSpace     = "ctrl_space"      // Ctrl + Space
    case optionGrave   = "option_grave"    // Option + `
    case optionSpace   = "option_space"    // Option + Space
    case cmdShiftG     = "cmd_shift_g"     // Cmd + Shift + G

    var id: String { rawValue }

    /// Display name for the preset
    var displayName: String {
        switch self {
        case .ctrlGrave:   return "Ctrl + `"
        case .ctrlSpace:   return "Ctrl + Space"
        case .optionGrave: return "Option + `"
        case .optionSpace: return "Option + Space"
        case .cmdShiftG:   return "Cmd + Shift + G"
        }
    }

    /// Carbon virtual key code
    var keyCode: UInt32 {
        switch self {
        case .ctrlGrave:   return UInt32(kVK_ANSI_Grave)
        case .ctrlSpace:   return UInt32(kVK_Space)
        case .optionGrave: return UInt32(kVK_ANSI_Grave)
        case .optionSpace: return UInt32(kVK_Space)
        case .cmdShiftG:   return UInt32(kVK_ANSI_G)
        }
    }

    /// Carbon modifier key mask
    var modifiers: UInt32 {
        switch self {
        case .ctrlGrave:   return UInt32(controlKey)
        case .ctrlSpace:   return UInt32(controlKey)
        case .optionGrave: return UInt32(optionKey)
        case .optionSpace: return UInt32(optionKey)
        case .cmdShiftG:   return UInt32(cmdKey | shiftKey)
        }
    }
}

/// App language options
enum AppLanguage: String, CaseIterable, Identifiable {
    case system  = "system"   // Follow system language
    case en      = "en"       // English
    case zhHans  = "zh-Hans"  // Simplified Chinese

    var id: String { rawValue }

    /// Display name (always shown in the target language for clarity)
    var displayName: String {
        switch self {
        case .system: return String(localized: "System Default")
        case .en:     return "English"
        case .zhHans: return "简体中文"
        }
    }
}

/// Background timeout preset options
enum BackgroundTimeoutPreset: String, CaseIterable, Identifiable {
    case never        = "never"          // Never timeout
    case tenMinutes   = "10min"          // 10 minutes
    case thirtyMinutes = "30min"         // 30 minutes
    case sixtyMinutes = "60min"          // 60 minutes

    var id: String { rawValue }

    /// Display name
    var displayName: String {
        switch self {
        case .never:         return String(localized: "Never")
        case .tenMinutes:    return String(localized: "10 minutes")
        case .thirtyMinutes: return String(localized: "30 minutes")
        case .sixtyMinutes:  return String(localized: "60 minutes")
        }
    }

    /// Timeout in seconds; returns nil for never
    var seconds: TimeInterval? {
        switch self {
        case .never:         return nil
        case .tenMinutes:    return 600
        case .thirtyMinutes: return 1800
        case .sixtyMinutes:  return 3600
        }
    }
}

/// App settings manager using UserDefaults + @Published for persistence and reactive binding.
/// All configurable parameters are centrally managed and referenced by other modules.
class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    // MARK: - Defaults

    private enum Defaults {
        static let backgroundTimeout = BackgroundTimeoutPreset.tenMinutes
        static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.3 Safari/605.1.15"
        static let launchAtLogin = false
        static let alwaysOnTop = false
        static let hotKeyPreset = HotKeyPreset.ctrlGrave
        static let windowAnimation = true
    }

    // MARK: - Storage Keys

    private enum Keys {
        static let backgroundTimeout = "backgroundTimeout"
        static let userAgent = "customUserAgent"
        static let launchAtLogin = "launchAtLogin"
        static let alwaysOnTop = "alwaysOnTop"
        static let hotKeyPreset = "hotKeyPreset"
        static let language = "appLanguage"
        static let windowAnimation = "windowAnimation"
    }

    // MARK: - Configurable Properties

    /// Background timeout preset
    @Published var backgroundTimeout: BackgroundTimeoutPreset {
        didSet { UserDefaults.standard.set(backgroundTimeout.rawValue, forKey: Keys.backgroundTimeout) }
    }

    /// Custom User-Agent string
    @Published var userAgent: String {
        didSet { UserDefaults.standard.set(userAgent, forKey: Keys.userAgent) }
    }

    /// Launch at login
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    /// Always on top
    @Published var alwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: Keys.alwaysOnTop)
            updateWindowLevel()
        }
    }

    /// Global hotkey preset
    @Published var hotKeyPreset: HotKeyPreset {
        didSet {
            UserDefaults.standard.set(hotKeyPreset.rawValue, forKey: Keys.hotKeyPreset)
            HotKeyManager.shared.reRegister()
        }
    }

    /// App language override
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
            applyLanguage()
        }
    }

    /// Toggle for window show/hide transition animation
    @Published var windowAnimation: Bool {
        didSet { UserDefaults.standard.set(windowAnimation, forKey: Keys.windowAnimation) }
    }


    // MARK: - Computed Properties



    /// Default User-Agent value
    var defaultUserAgent: String {
        Defaults.userAgent
    }

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard

        // Read background timeout preset
        if let timeoutRaw = defaults.string(forKey: Keys.backgroundTimeout),
           let timeout = BackgroundTimeoutPreset(rawValue: timeoutRaw) {
            self.backgroundTimeout = timeout
        } else {
            self.backgroundTimeout = Defaults.backgroundTimeout
        }

        self.userAgent = defaults.string(forKey: Keys.userAgent) ?? Defaults.userAgent
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.alwaysOnTop = defaults.bool(forKey: Keys.alwaysOnTop)

        if let presetRaw = defaults.string(forKey: Keys.hotKeyPreset),
           let preset = HotKeyPreset(rawValue: presetRaw) {
            self.hotKeyPreset = preset
        } else {
            self.hotKeyPreset = Defaults.hotKeyPreset
        }

        if let langRaw = defaults.string(forKey: Keys.language),
           let lang = AppLanguage(rawValue: langRaw) {
            self.language = lang
        } else {
            self.language = .system
        }

        // windowAnimation defaults to true; only read if user has explicitly set it
        if defaults.object(forKey: Keys.windowAnimation) != nil {
            self.windowAnimation = defaults.bool(forKey: Keys.windowAnimation)
        } else {
            self.windowAnimation = Defaults.windowAnimation
        }
    }

    // MARK: - Private Methods

    /// Update launch-at-login state
    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch-at-login: \(error.localizedDescription)")
        }
    }

    /// Update window level
    func updateWindowLevel() {
        DispatchQueue.main.async {
            for window in NSApp.windows where window.canBecomeKey {
                window.level = self.alwaysOnTop ? .floating : .normal
            }
        }
    }

    /// Apply selected language by overriding AppleLanguages
    private func applyLanguage() {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
}
