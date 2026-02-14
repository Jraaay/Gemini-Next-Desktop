import SwiftUI
import Combine
import Carbon
import ServiceManagement

/// Custom global hotkey, stores Carbon keyCode and modifiers
struct CustomHotKey: Codable, Equatable {
    /// Carbon virtual key code
    var keyCode: UInt32
    /// Carbon modifier mask (controlKey / optionKey / cmdKey / shiftKey)
    var modifiers: UInt32

    /// Default hotkey: Ctrl + `
    static let defaultHotKey = CustomHotKey(
        keyCode: UInt32(kVK_ANSI_Grave),
        modifiers: UInt32(controlKey)
    )

    /// Validation: requires at least one modifier key + one regular key
    var isValid: Bool {
        return modifiers != 0 && keyCode != 0
    }

    /// Convert keyCode + modifiers to a human-readable string, e.g. "⌃`"
    var displayName: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0  { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0   { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0     { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    /// Map Carbon keyCode to a human-readable key name
    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Grave: return "`"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_ForwardDelete: return "⌦"
        default: return "Key(\(keyCode))"
        }
    }

    /// Migrate legacy HotKeyPreset rawValue to CustomHotKey
    static func fromLegacyPreset(_ rawValue: String) -> CustomHotKey? {
        switch rawValue {
        case "ctrl_grave":   return CustomHotKey(keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(controlKey))
        case "ctrl_space":   return CustomHotKey(keyCode: UInt32(kVK_Space),      modifiers: UInt32(controlKey))
        case "option_grave": return CustomHotKey(keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(optionKey))
        case "option_space": return CustomHotKey(keyCode: UInt32(kVK_Space),      modifiers: UInt32(optionKey))
        case "cmd_shift_g":  return CustomHotKey(keyCode: UInt32(kVK_ANSI_G),     modifiers: UInt32(cmdKey | shiftKey))
        default: return nil
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
        static let customHotKey: CustomHotKey? = CustomHotKey.defaultHotKey
        static let windowAnimation = true
    }

    // MARK: - Storage Keys

    private enum Keys {
        static let backgroundTimeout = "backgroundTimeout"
        static let userAgent = "customUserAgent"
        static let launchAtLogin = "launchAtLogin"
        static let alwaysOnTop = "alwaysOnTop"
        static let customHotKey = "customHotKey"
        static let legacyHotKeyPreset = "hotKeyPreset"
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

    /// Custom global hotkey (nil means disabled)
    @Published var customHotKey: CustomHotKey? {
        didSet {
            if let hotKey = customHotKey {
                if let data = try? JSONEncoder().encode(hotKey) {
                    UserDefaults.standard.set(data, forKey: Keys.customHotKey)
                }
            } else {
                // Store empty Data to mark "cleared", distinct from "never set"
                UserDefaults.standard.set(Data(), forKey: Keys.customHotKey)
            }
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

        // Read custom hotkey (prefer new format, fallback to legacy preset format)
        if let data = defaults.data(forKey: Keys.customHotKey) {
            if data.isEmpty {
                // Empty Data means user has explicitly cleared the hotkey
                self.customHotKey = nil
            } else if let hotKey = try? JSONDecoder().decode(CustomHotKey.self, from: data) {
                self.customHotKey = hotKey
            } else {
                self.customHotKey = Defaults.customHotKey
            }
        } else if let legacyRaw = defaults.string(forKey: Keys.legacyHotKeyPreset),
                  let migrated = CustomHotKey.fromLegacyPreset(legacyRaw) {
            // Migrate legacy preset format
            self.customHotKey = migrated
            if let data = try? JSONEncoder().encode(migrated) {
                defaults.set(data, forKey: Keys.customHotKey)
            }
            defaults.removeObject(forKey: Keys.legacyHotKeyPreset)
        } else {
            self.customHotKey = Defaults.customHotKey
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
