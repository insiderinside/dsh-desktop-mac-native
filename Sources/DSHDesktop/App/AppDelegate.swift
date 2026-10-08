import Cocoa
import DSHDesktopCore
import DSHDesktopUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var menuBarController: MenuBarController?
    private let supervisor = DshProcessSupervisor()
    private let config = AppConfig()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // ponytail: Assign clear process name in macOS Activity Monitor
        ProcessInfo.processInfo.processName = "DeepSeek Harness Desktop"

        // Initialize notification permissions
        NotificationManager.shared.requestAuthorization()

        Task { @MainActor in
            // 1. Present window immediately in initial loading state
            let webVC = WebViewController(targetURL: config.webURL)
            let winCtrl = MainWindowController(viewController: webVC)
            self.mainWindowController = winCtrl
            self.menuBarController = MenuBarController(windowController: winCtrl)

            setupMainMenu(webVC: webVC)
            setupGlobalHotkeys()

            winCtrl.showWindow(nil)
            winCtrl.window?.makeKeyAndOrderFront(nil)

            // On fresh launch or default narrow window size (width <= 850), maximize window
            let hasSaved = UserDefaults.standard.string(forKey: "NSWindow Frame DSHMainWindowFrame") != nil
            if !hasSaved || (winCtrl.window?.frame.width ?? 0) <= 850 {
                winCtrl.maximizeWindow()
            }

            NSApp.activate(ignoringOtherApps: true)

            // 2. Start backend and verify HTTP 200 OK health check (prevents reconnecting loop)
            await startBackendAndWarmup(webVC: webVC)
        }
    }

    @MainActor
    private func setupMainMenu(webVC: WebViewController) {
        let mainMenu = NSMenu()

        // 1. App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About DeepSeek Harness", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit DeepSeek Harness", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. Edit Menu (Copy, Paste, Cut, Select All)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 3. View Menu (Zoom In, Zoom Out, Actual Size, Reload, Toggle Maximize)
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")

        let zoomInItem = NSMenuItem(title: "Zoom In", action: #selector(WebViewController.zoomIn), keyEquivalent: "+")
        zoomInItem.keyEquivalentModifierMask = .command
        zoomInItem.target = webVC
        viewMenu.addItem(zoomInItem)

        let zoomOutItem = NSMenuItem(title: "Zoom Out", action: #selector(WebViewController.zoomOut), keyEquivalent: "-")
        zoomOutItem.keyEquivalentModifierMask = .command
        zoomOutItem.target = webVC
        viewMenu.addItem(zoomOutItem)

        let actualSizeItem = NSMenuItem(title: "Actual Size", action: #selector(WebViewController.resetZoom), keyEquivalent: "0")
        actualSizeItem.keyEquivalentModifierMask = .command
        actualSizeItem.target = webVC
        viewMenu.addItem(actualSizeItem)

        viewMenu.addItem(NSMenuItem.separator())

        let reloadItem = NSMenuItem(title: "Reload Page", action: #selector(WebViewController.reloadPage), keyEquivalent: "r")
        reloadItem.keyEquivalentModifierMask = .command
        reloadItem.target = webVC
        viewMenu.addItem(reloadItem)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 4. Tools Menu (Terminal, Finder, Plugin Logs)
        let toolsMenuItem = NSMenuItem()
        let toolsMenu = NSMenu(title: "Tools")

        let terminalItem = NSMenuItem(title: "Open Workspace in Terminal", action: #selector(openProjectTerminal), keyEquivalent: "t")
        terminalItem.keyEquivalentModifierMask = [.command, .shift]
        terminalItem.target = self
        toolsMenu.addItem(terminalItem)

        let finderItem = NSMenuItem(title: "Reveal in Finder", action: #selector(openProjectFinder), keyEquivalent: "r")
        finderItem.keyEquivalentModifierMask = [.command, .shift]
        finderItem.target = self
        toolsMenu.addItem(finderItem)

        toolsMenu.addItem(NSMenuItem.separator())

        let inspectorItem = NSMenuItem(title: "Plugin & JS Log Inspector", action: #selector(openPluginLogInspector), keyEquivalent: "l")
        inspectorItem.keyEquivalentModifierMask = [.command, .shift]
        inspectorItem.target = self
        toolsMenu.addItem(inspectorItem)

        toolsMenuItem.submenu = toolsMenu
        mainMenu.addItem(toolsMenuItem)

        // 5. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")

        let newTabItem = NSMenuItem(title: "New Window", action: #selector(openNewTab), keyEquivalent: "n")
        newTabItem.keyEquivalentModifierMask = .command
        newTabItem.target = self
        windowMenu.addItem(newTabItem)

        let maximizeItem = NSMenuItem(title: "Auto Full Width / Maximize", action: #selector(DSHWindow.toggleMaximizeWidth), keyEquivalent: "f")
        maximizeItem.keyEquivalentModifierMask = [.command, .control]
        windowMenu.addItem(maximizeItem)

        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @MainActor
    @objc private func openNewTab() {
        // Create new standalone window to preserve internal web session tabs
        let newWebVC = WebViewController(targetURL: config.webURL)
        let newWinCtrl = MainWindowController(viewController: newWebVC)
        newWinCtrl.showWindow(nil)
        newWinCtrl.window?.makeKeyAndOrderFront(nil)
    }

    @MainActor
    @objc private func openProjectTerminal() {
        let path = FileManager.default.currentDirectoryPath
        let openConfig = NSWorkspace.OpenConfiguration()
        if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let targetURL = URL(fileURLWithPath: path)
            NSWorkspace.shared.open([targetURL], withApplicationAt: terminalURL, configuration: openConfig, completionHandler: nil)
        }
    }

    @MainActor
    @objc private func openProjectFinder() {
        let path = FileManager.default.currentDirectoryPath
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    @MainActor
    @objc private func openPluginLogInspector() {
        PluginLogWindowController.shared.showInspector()
    }

    @MainActor
    private func setupGlobalHotkeys() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Option + Space -> Toggle show / hide window
            if event.modifierFlags.contains(.option) && event.keyCode == 49 {
                self?.toggleMainWindow()
                return nil
            }
            return event
        }
    }

    @MainActor
    @objc private func toggleMainWindow() {
        guard let win = mainWindowController?.window else { return }
        if win.isVisible && win.isKeyWindow {
            win.orderOut(nil)
        } else {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @MainActor
    private func startBackendAndWarmup(webVC: WebViewController) async {
        guard config.autoLaunchBackend else { return }

        // Cek apakah server sudah aktif di port
        let isOpen = await PortProbe.probe(port: config.defaultPort, timeoutSeconds: 0.5) == .open
        if !isOpen {
            if let binary = DshLocator.locate() {
                _ = await supervisor.start(dshBinary: binary, port: config.defaultPort)
                _ = await PortProbe.waitForPort(port: config.defaultPort, maxAttempts: 25, intervalSeconds: 0.4)
            }
        }

        // Siapkan cookie header untuk health-check
        var cookieHeader: String? = nil
        let authority = "\(config.host):\(config.defaultPort)"
        if let secret = DshAuthSigner.loadSecret(),
           let cookie = DshAuthSigner.generateSessionCookie(authority: authority, secret: secret) {
            cookieHeader = "\(cookie.name)=\(cookie.value)"
        }

        // Tunggu hingga HTTP Server benar-benar merespons 200 OK (Warmup delay)
        let isHealthy = await HealthChecker.waitForHealthy(
            url: config.webURL,
            cookieHeader: cookieHeader,
            maxAttempts: 30,
            intervalSeconds: 0.3
        )

        if isHealthy {
            await MainActor.run {
                webVC.setupAuthAndLoad()
                NotificationManager.shared.sendNotification(
                    title: "DeepSeek Harness",
                    body: "Local server is active and ready."
                )
            }
        } else {
            await MainActor.run {
                NotificationManager.shared.sendNotification(
                    title: "DeepSeek Harness",
                    body: "Warning: Local server is not responding."
                )
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        Task {
            await supervisor.stop()
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindowController?.window?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
