import WebKit

class GeminiBaseWebView: WKWebView {

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Support standard Command shortcuts (e.g. Cmd+C, Cmd+V, Cmd+A)
        if event.modifierFlags.contains(.command) {
            return super.performKeyEquivalent(with: event)
        }
        
        // For regular keys (e.g. Enter), return false so they are passed to the web page as normal key events
        // This fixes an issue where WKWebView in SwiftUI may intercept certain keys as menu shortcuts
        return false
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {  // Enter key
            print("[IME Debug] Native keyDown: keyCode=\(event.keyCode), characters='\(event.characters ?? "nil")', modifiers=\(event.modifierFlags.rawValue)")
        }
        super.keyDown(with: event)
    }
}
