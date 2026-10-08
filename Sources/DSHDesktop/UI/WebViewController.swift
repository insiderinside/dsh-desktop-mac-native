import Cocoa
import WebKit
import DSHDesktopCore

/// Controller untuk menampung WKWebView, file upload panel handler, dan tampilan loading status.
public final class WebViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {
    private static let zoomDefaultsKey = "DSHWebViewPageZoom"

    public private(set) var webView: WKWebView!
    private var progressIndicator: NSProgressIndicator!
    private let targetURL: URL

    public init(targetURL: URL) {
        self.targetURL = targetURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0).cgColor // Dark mode background agar tidak blank putih
        self.view = root

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Disable automatic spellcheck & autocorrect globally via user script injection
        let disableSpellcheckScript = """
        (function() {
            function disableSpell() {
                var inputs = document.querySelectorAll('input, textarea, [contenteditable="true"]');
                for (var i = 0; i < inputs.length; i++) {
                    inputs[i].setAttribute('spellcheck', 'false');
                    inputs[i].setAttribute('autocorrect', 'off');
                    inputs[i].setAttribute('autocapitalize', 'off');
                }
            }
            disableSpell();
            var observer = new MutationObserver(function() { disableSpell(); });
            observer.observe(document.documentElement, { childList: true, subtree: true });

            // Native bridge helper di window
            window.dshNative = {
                openTerminal: function(path) {
                    window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.openTerminal &&
                    window.webkit.messageHandlers.openTerminal.postMessage({ path: path || "" });
                },
                revealInFinder: function(path) {
                    window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.revealInFinder &&
                    window.webkit.messageHandlers.revealInFinder.postMessage({ path: path || "" });
                }
            };
            window.dshDesktop = Object.freeze({ protocolVersion: 1 });
            window.dshDesktopActions = {
                invoke: function(action) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.desktopAction) {
                        return window.webkit.messageHandlers.desktopAction.postMessage({ action: action });
                    }
                    return Promise.resolve();
                }
            };

            // Interseptor error JavaScript & Plugin untuk debugging
            function forwardLog(level, message, source, line, col) {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pluginLog) {
                        window.webkit.messageHandlers.pluginLog.postMessage({
                            level: level,
                            message: String(message),
                            source: source || "inline",
                            line: line || null,
                            column: col || null
                        });
                    }
                } catch(e) {}
            }

            // Tangkap window.onerror
            window.addEventListener('error', function(e) {
                var src = e.filename || "unknown";
                var msg = e.message || (e.error ? e.error.message : "Uncaught Error");
                forwardLog("ERROR", msg, src, e.lineno, e.colno);
            });

            // Tangkap unhandledrejection (Promise error pada async plugin)
            window.addEventListener('unhandledrejection', function(e) {
                var reason = e.reason;
                var msg = reason ? (reason.stack || reason.message || String(reason)) : "Unhandled Promise Rejection";
                forwardLog("ERROR", msg, "Promise");
            });

            // Intersep console.error dan console.warn
            var origError = console.error;
            console.error = function() {
                var args = Array.prototype.slice.call(arguments);
                forwardLog("ERROR", args.map(String).join(" "), "console.error");
                origError.apply(console, arguments);
            };
            var origWarn = console.warn;
            console.warn = function() {
                var args = Array.prototype.slice.call(arguments);
                forwardLog("WARN", args.map(String).join(" "), "console.warn");
                origWarn.apply(console, arguments);
            };
        })();
        """
        let userScript = WKUserScript(source: disableSpellcheckScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

        let wv = WKWebView(frame: .zero, configuration: config)
        config.userContentController.add(self, name: "openTerminal")
        config.userContentController.add(self, name: "revealInFinder")
        config.userContentController.add(self, name: "pluginLog")
        config.userContentController.add(self, name: "desktopAction")
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        wv.uiDelegate = self

        // Restore zoom preference, atau default ke 0.9 (zoom out 90%)
        let savedZoom = UserDefaults.standard.double(forKey: WebViewController.zoomDefaultsKey)
        wv.pageZoom = savedZoom > 0 ? savedZoom : 0.9

        root.addSubview(wv)
        self.webView = wv

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isDisplayedWhenStopped = false
        spinner.isHidden = true
        root.addSubview(spinner)
        self.progressIndicator = spinner

        NSLayoutConstraint.activate([
            wv.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            wv.topAnchor.constraint(equalTo: root.topAnchor),
            wv.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: root.centerYAnchor)
        ])
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupAuthAndLoad()
    }

    /// Menyiapkan cookie autentikasi ke WKHTTPCookieStore sebelum memuat halaman
    public func setupAuthAndLoad() {
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)

        guard let host = targetURL.host, let port = targetURL.port else {
            loadRequest()
            return
        }

        let authority = "\(host):\(port)"
        if let secret = DshAuthSigner.loadSecret(),
           let cookie = DshAuthSigner.generateSessionCookie(authority: authority, secret: secret) {
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            let properties: [HTTPCookiePropertyKey: Any] = [
                .domain: host,
                .path: "/",
                .name: cookie.name,
                .value: cookie.value,
                .expires: Date().addingTimeInterval(30 * 24 * 60 * 60)
            ]
            if let httpCookie = HTTPCookie(properties: properties) {
                cookieStore.setCookie(httpCookie) { [weak self] in
                    DispatchQueue.main.async {
                        self?.loadRequest(cookieHeader: "\(cookie.name)=\(cookie.value)")
                    }
                }
                return
            }
        }

        loadRequest()
    }

    private func loadRequest(cookieHeader: String? = nil, bypassingCache: Bool = true) {
        // `.reloadIgnoringLocalCacheData` on the FIRST load matters: the DSH web
        // server serves plugin bundles (lib/client.js) as plain static files
        // with no content hash in the URL, so WKWebView happily reuses a
        // previously cached copy of a plugin ACROSS app launches. A server-side
        // plugin fix then looks like it "didn't work" inside the WebView even
        // though `curl` and a hard browser reload see the new code. Bypassing
        // the cache on boot (and on every explicit reload) keeps the shell in
        // lockstep with the server. The persistent store is still used for
        // cookies/localStorage — only the HTTP cache read is skipped.
        let policy: URLRequest.CachePolicy = bypassingCache ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
        var request = URLRequest(url: targetURL, cachePolicy: policy, timeoutInterval: 30)
        if let cookieHeader = cookieHeader {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        webView.load(request)
    }

    // MARK: - Zoom Controls
    @objc public func zoomIn() {
        let current = webView.pageZoom
        let next = min(current + 0.1, 3.0)
        webView.pageZoom = next
        UserDefaults.standard.set(next, forKey: WebViewController.zoomDefaultsKey)
    }

    @objc public func zoomOut() {
        let current = webView.pageZoom
        let next = max(current - 0.1, 0.5)
        webView.pageZoom = next
        UserDefaults.standard.set(next, forKey: WebViewController.zoomDefaultsKey)
    }

    @objc public func resetZoom() {
        webView.pageZoom = 0.9
        UserDefaults.standard.set(0.9, forKey: WebViewController.zoomDefaultsKey)
    }

    @objc public func reloadPage() {
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        // A plain `setupAuthAndLoad()` re-issues the same request, which the
        // WebView may answer from its HTTP cache — so a plugin update on the
        // server would still not be visible. Drop ONLY the cache-backed types
        // (never cookies/localStorage: those hold the session cookie and the
        // sidebar layout, and clearing them would sign the user out).
        let cacheTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeOfflineWebApplicationCache,
        ]
        webView.configuration.websiteDataStore.removeData(ofTypes: cacheTypes, modifiedSince: .distantPast) { [weak self] in
            DispatchQueue.main.async { self?.setupAuthAndLoad() }
        }
    }

    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
    }

    // MARK: - WKUIDelegate (Native File Upload & Dialog Support)
    @MainActor
    public func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable ([URL]?) -> Void
    ) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = parameters.allowsDirectories
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection

        if let window = view.window {
            openPanel.beginSheetModal(for: window) { response in
                if response == .OK {
                    completionHandler(openPanel.urls)
                } else {
                    completionHandler(nil)
                }
            }
        } else {
            let response = openPanel.runModal()
            if response == .OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }
}

// MARK: - WKScriptMessageHandler (Native System Bridge)
extension WebViewController: WKScriptMessageHandler {
    @MainActor
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let dict = message.body as? [String: Any]
        let pathString = (dict?["path"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let targetPath = pathString.isEmpty ? FileManager.default.currentDirectoryPath : pathString

        switch message.name {
        case "openTerminal":
            let openConfig = NSWorkspace.OpenConfiguration()
            if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                let targetURL = URL(fileURLWithPath: targetPath)
                NSWorkspace.shared.open([targetURL], withApplicationAt: terminalURL, configuration: openConfig, completionHandler: nil)
            }
        case "revealInFinder":
            let fileURL = URL(fileURLWithPath: targetPath)
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        case "desktopAction":
            let action = (dict?["action"] as? String) ?? ""
            if action == "terminal" {
                let openConfig = NSWorkspace.OpenConfiguration()
                if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                    let targetURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    NSWorkspace.shared.open([targetURL], withApplicationAt: terminalURL, configuration: openConfig, completionHandler: nil)
                }
            }
        case "pluginLog":
            if let logDict = message.body as? [String: Any] {
                let lvlString = logDict["level"] as? String ?? "INFO"
                let msg = logDict["message"] as? String ?? ""
                let src = logDict["source"] as? String ?? "inline"
                let line = logDict["line"] as? Int
                let col = logDict["column"] as? Int

                let level: PluginLogEntry.LogLevel
                switch lvlString {
                case "ERROR": level = .error
                case "WARN": level = .warn
                default: level = .info
                }
                PluginLogStore.shared.add(level: level, message: msg, source: src, line: line, column: col)
            }
        default:
            break
        }
    }
}
