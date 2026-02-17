import SwiftUI
import WebKit
import Combine

extension Notification.Name {
    /// Posted after browsing data has been cleared from Settings
    static let browsingDataCleared = Notification.Name("BrowsingDataCleared")
}

/// Weak wrapper to avoid retain cycle: WKUserContentController strongly retains message handlers
private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(controller, didReceive: message)
    }
}

class WebViewModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    // MARK: - Constants

    private enum Constants {
        static let geminiURL = URL(string: "https://gemini.google.com/app")!
    }

    /// Settings manager reference
    private let settings = SettingsManager.shared

    /// Subscriptions for observing settings changes
    private var cancellables = Set<AnyCancellable>()

    /// Shared process pool to ensure all WebView instances share the same session, avoiding cookie isolation
    private static let sharedProcessPool = WKProcessPool()

    /// IME fix script — injected at document start to register before any page scripts.
    /// Tracks real composing state and blocks buggy Enter events from reaching the page.
    /// Console log bridge — forwards JS console.log to native Xcode console
    private static let consoleLogBridgeScript = """
    (function() {
        if (window.__consoleBridgeInstalled) return;
        window.__consoleBridgeInstalled = true;
        var originalLog = console.log;
        console.log = function() {
            var args = Array.prototype.slice.call(arguments);
            var msg = args.map(function(a) {
                return typeof a === 'object' ? JSON.stringify(a) : String(a);
            }).join(' ');
            originalLog.apply(console, arguments);
            try {
                window.webkit.messageHandlers.consoleLog.postMessage(msg);
            } catch(e) {}
        };
    })();
    """

    private static let imeFixScript = """
    (function() {
        if (window.__imeFixInstalled) return;
        window.__imeFixInstalled = true;

        var actuallyComposing = false;
        var fixInProgress = false;
        var syntheticEnterInFlight = false;
        var syntheticEnterTimer = null;

        document.addEventListener('compositionstart', function(e) {
            actuallyComposing = true;
            console.log('[IME Debug] compositionstart, data="' + e.data + '"');
        }, true);

        document.addEventListener('compositionend', function(e) {
            actuallyComposing = false;
            console.log('[IME Debug] compositionend, data="' + e.data + '"');

            // FIX for Gemini's "recent composition" flag:
            // Gemini internally tracks composition state and swallows the first
            // Enter after compositionend. We dispatch a synthetic Enter to clear
            // that flag, so the user's real Enter goes through normally.
            //
            // HOWEVER, if an Enter keydown arrives within 50ms of compositionend,
            // it means the Enter key was used to confirm the IME candidate
            // (scenario 1). In that case, we must NOT dispatch synthetic Enter,
            // because Gemini's flag-clearing on that Enter is the correct behavior.
            if (syntheticEnterTimer) clearTimeout(syntheticEnterTimer);
            syntheticEnterTimer = setTimeout(function() {
                syntheticEnterTimer = null;
                var target = document.activeElement || document.body;
                syntheticEnterInFlight = true;
                console.log('[IME Debug] >>> dispatching synthetic Enter to clear Gemini flag');
                var synDown = new KeyboardEvent('keydown', {
                    key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
                    bubbles: true, cancelable: true
                });
                target.dispatchEvent(synDown);
                var synUp = new KeyboardEvent('keyup', {
                    key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
                    bubbles: true, cancelable: true
                });
                target.dispatchEvent(synUp);
                syntheticEnterInFlight = false;
                console.log('[IME Debug] >>> synthetic Enter dispatched, defaultPrevented=' + synDown.defaultPrevented);
            }, 50);
        }, true);

        // Capture-phase keydown logging + fix
        document.addEventListener('keydown', function(e) {
            if (e.key !== 'Enter' || e.shiftKey) return;

            // If a real Enter arrives right after compositionend (within 50ms),
            // cancel the synthetic — this Enter IS the IME confirmation key
            if (syntheticEnterTimer && e.isTrusted) {
                clearTimeout(syntheticEnterTimer);
                syntheticEnterTimer = null;
                console.log('[IME Debug] keydown Enter: cancelled synthetic (IME confirmation Enter detected)');
            }

            // Block the synthetic Enter from our compositionend fix
            // so it only reaches Gemini's handler (clears their flag)
            // but doesn't trigger our own fix logic
            if (syntheticEnterInFlight) {
                console.log('[IME Debug] keydown Enter: SYNTHETIC (clearing Gemini flag)');
                return;
            }

            console.log('[IME Debug] keydown Enter: isComposing=' + e.isComposing +
                ', actuallyComposing=' + actuallyComposing +
                ', fixInProgress=' + fixInProgress +
                ', isTrusted=' + e.isTrusted);

            // Original fix: WKWebView sometimes reports isComposing=true even
            // after compositionend has fired. Block this buggy event and ask
            // native to send a fresh Enter.
            if (e.isComposing && !actuallyComposing && !fixInProgress) {
                console.log('[IME Debug] >>> isComposing FIX: blocking buggy Enter, requesting native re-send');
                e.stopImmediatePropagation();
                e.preventDefault();
                fixInProgress = true;
                setTimeout(function() { fixInProgress = false; }, 1000);
                window.webkit.messageHandlers.imeEnterFix.postMessage('sendEnter');
                return;
            }

            if (fixInProgress) {
                console.log('[IME Debug] --- re-sent fix Enter, letting through');
            } else {
                console.log('[IME Debug] --- normal Enter, letting through');
            }
        }, true);

        // Bubble-phase: check if page preventDefault'd
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' && !syntheticEnterInFlight) {
                console.log('[IME Debug] keydown Enter (BUBBLE): defaultPrevented=' + e.defaultPrevented);
            }
        }, false);

        // Post-Enter state check
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' && !e.shiftKey && !syntheticEnterInFlight) {
                setTimeout(function() {
                    var el = document.activeElement;
                    var textLen = el ? (el.textContent || '').length : 0;
                    console.log('[IME Debug] post-Enter: textLen=' + textLen);
                }, 50);
            }
        }, true);

        console.log('[IME Debug] IME fix script installed with debug logging');
    })();
    """

    // MARK: - Public Properties

    @Published var isLoading: Bool = true
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    /// Loading error message; non-nil indicates an error occurred
    @Published var errorMessage: String?
    /// Whether the page input field is ready (contenteditable or textarea detected)
    @Published var isPageReady: Bool = false

    let webView: WKWebView

    /// Background timeout timer; navigates back to homepage on timeout
    private var backgroundTimer: Timer?

    /// Timer that polls for input field readiness via JavaScript
    private var inputReadyTimer: Timer?

    /// Check if currently on the Gemini homepage
    private var isOnHomePage: Bool {
        guard let url = webView.url else { return false }
        return url.host == Constants.geminiURL.host
            && url.path == Constants.geminiURL.path
    }

    // MARK: - Initialization

    override init() {
        let configuration = WKWebViewConfiguration()
        // Use default persistent data store to preserve cookies / LocalStorage across app restarts
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.processPool = Self.sharedProcessPool
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        // Inject console log bridge first so it captures all subsequent console.log calls
        let consoleScript = WKUserScript(
            source: Self.consoleLogBridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(consoleScript)

        // Inject IME fix script via WKUserScript, more reliable than evaluateJavaScript
        let imeScript = WKUserScript(
            source: Self.imeFixScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(imeScript)

        webView = GeminiBaseWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = settings.userAgent

        super.init()

        // Register message handlers (must be after super.init() so self is available)
        let weakHandler = WeakScriptMessageHandler(self)
        webView.configuration.userContentController.add(weakHandler, name: "imeEnterFix")
        webView.configuration.userContentController.add(weakHandler, name: "consoleLog")

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.load(URLRequest(url: Constants.geminiURL))

        // Observe app activation / deactivation events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        // Listen for browsing data cleared notification to reload the page
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBrowsingDataCleared),
            name: .browsingDataCleared,
            object: nil
        )
    }

    deinit {
        backgroundTimer?.invalidate()
        inputReadyTimer?.invalidate()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "imeEnterFix")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "consoleLog")
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Focus the input field in the page (contenteditable area or textarea)
    func focusInput() {
        let js = """
        (function() {
            // Prefer contenteditable input area (used by Gemini)
            var el = document.querySelector('[contenteditable="true"]');
            if (!el) {
                el = document.querySelector('textarea');
            }
            if (el) {
                el.focus();
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// When app becomes active, cancel the timer and focus the input field
    @objc private func appDidBecomeActive() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil

        // Delay briefly to ensure the window and WebView are fully ready before focusing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.focusInput()
        }
    }

    /// Reload the homepage after browsing data has been cleared
    @objc private func handleBrowsingDataCleared() {
        webView.load(URLRequest(url: Constants.geminiURL))
    }

    /// Start the timeout timer when the app enters background (not started when set to "never")
    @objc private func appDidResignActive() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil

        // Do not start the timer when "never" is selected
        guard let interval = settings.backgroundTimeout.seconds else { return }

        backgroundTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [weak self] _ in
            guard let self = self, !self.isOnHomePage else { return }
            self.webView.load(URLRequest(url: Constants.geminiURL))
        }
    }

    /// Reload the current page and clear error state; fall back to homepage if no current URL
    func retry() {
        errorMessage = nil
        if webView.url != nil {
            webView.reload()
        } else {
            webView.load(URLRequest(url: Constants.geminiURL))
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        errorMessage = nil
        startInputReadyPolling()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        // Ensure page is marked ready when navigation fully completes
        if !isPageReady {
            isPageReady = true
        }
        stopInputReadyPolling()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        // Ignore cancellation errors, which are normal navigation cancellations
        if nsError.code != NSURLErrorCancelled {
            print("Navigation failed: \(error.localizedDescription)")
            errorMessage = String(localized: "Failed to load. Please check your network connection.")
        }
        isLoading = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.code != NSURLErrorCancelled {
            print("Provisional navigation failed: \(error.localizedDescription)")
            errorMessage = String(localized: "Unable to connect to Gemini. Please check your network connection.")
        }
        isLoading = false
    }

    // MARK: - Input Ready Polling

    /// Start polling for input field availability every 200ms, up to 30s
    private func startInputReadyPolling() {
        stopInputReadyPolling()
        isPageReady = false
        let startTime = Date()

        inputReadyTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            // Timeout after 30 seconds, fall back to didFinish
            if Date().timeIntervalSince(startTime) > 30 {
                timer.invalidate()
                self.inputReadyTimer = nil
                return
            }

            let js = """
            (function() {
                var el = document.querySelector('[contenteditable="true"]');
                if (!el) el = document.querySelector('textarea');
                return el !== null;
            })();
            """
            self.webView.evaluateJavaScript(js) { result, _ in
                if let ready = result as? Bool, ready {
                    DispatchQueue.main.async {
                        if !self.isPageReady {
                            self.isPageReady = true
                        }
                        self.stopInputReadyPolling()
                    }
                }
            }
        }
    }

    /// Stop the input ready polling timer
    private func stopInputReadyPolling() {
        inputReadyTimer?.invalidate()
        inputReadyTimer = nil
    }

    // MARK: - WKUIDelegate

    /// Handle target="_blank" link requests by opening them in the system default browser
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    // MARK: - WKScriptMessageHandler (IME Enter Fix)

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        switch message.name {
        case "consoleLog":
            if let msg = message.body as? String {
                print("[JS] \(msg)")
            }
        case "imeEnterFix":
            print("[IME Debug] Native received imeEnterFix message: \(message.body)")
            // Delay to allow WKWebView to clear its internal stale composing state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                print("[IME Debug] Native sending synthetic Enter key after 150ms delay")
                self?.sendEnterKey()
            }
        default:
            break
        }
    }

    /// Send a fresh Enter key event via CGEvent.
    /// By this point WKWebView's composing state should be cleared,
    /// so the JS keydown event will have isComposing=false.
    private func sendEnterKey() {
        guard let window = webView.window else { return }
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        if let cgDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true) {
            cgDown.flags = []
            if let nsDown = NSEvent(cgEvent: cgDown) {
                window.sendEvent(nsDown)
            }
        }
        if let cgUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false) {
            cgUp.flags = []
            if let nsUp = NSEvent(cgEvent: cgUp) {
                window.sendEvent(nsUp)
            }
        }
    }
}
