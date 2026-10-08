import Cocoa

/// Status item di macOS menu bar untuk toggle jendela dan keluar dari aplikasi.
@MainActor
public final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private weak var windowController: MainWindowController?

    public init(windowController: MainWindowController) {
        self.windowController = windowController
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "● DSH"
            button.toolTip = "DeepSeek Harness Desktop (Port 3080: Aktif)"
        }

        let menu = NSMenu()
        
        // Header Status
        let statusHeader = NSMenuItem(title: "Status: Aktif (Port 3080)", action: nil, keyEquivalent: "")
        statusHeader.isEnabled = false
        menu.addItem(statusHeader)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Tampilkan / Sembunyikan Jendela", action: #selector(toggleWindow), keyEquivalent: "d"))
        
        // Submenu: Beralih Profil (Fase 9)
        let profileMenuItem = NSMenuItem(title: "Profil Aktif: webplugins", action: nil, keyEquivalent: "")
        let profileSubmenu = NSMenu()
        let availableProfiles = detectAvailableProfiles()
        for prof in availableProfiles {
            let pItem = NSMenuItem(title: prof, action: #selector(selectProfile(_:)), keyEquivalent: "")
            pItem.target = self
            if prof == "webplugins" {
                pItem.state = .on
            }
            profileSubmenu.addItem(pItem)
        }
        profileMenuItem.submenu = profileSubmenu
        menu.addItem(profileMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Inspeksi Log Plugin & JS Error", action: #selector(openLogInspector), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Buka Terminal Proyek", action: #selector(openTerminal), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Buka di Finder", action: #selector(revealInFinder), keyEquivalent: "f"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Keluar", action: #selector(quitApp), keyEquivalent: "q"))

        for menuItem in menu.items {
            if menuItem.action != nil {
                menuItem.target = self
            }
        }

        item.menu = menu
        self.statusItem = item
    }

    private func detectAvailableProfiles() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let profilesDir = home.appendingPathComponent(".dsh/profiles")
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: profilesDir.path) else {
            return ["default", "webplugins"]
        }
        return contents.filter { !$0.hasPrefix(".") && $0 != "node_modules" }.sorted()
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        let selectedProfile = sender.title
        let alert = NSAlert()
        alert.messageText = "Beralih ke Profil: \(selectedProfile)"
        alert.informativeText = "Profil '\(selectedProfile)' dipilih. Untuk sesi backend saat ini sedang aktif di port 3080 dengan profil webplugins."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func toggleWindow() {
        guard let win = windowController?.window else { return }
        if win.isVisible && win.isKeyWindow {
            win.orderOut(nil)
        } else {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func openTerminal() {
        let path = FileManager.default.currentDirectoryPath
        let openConfig = NSWorkspace.OpenConfiguration()
        if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let targetURL = URL(fileURLWithPath: path)
            NSWorkspace.shared.open([targetURL], withApplicationAt: terminalURL, configuration: openConfig, completionHandler: nil)
        }
    }

    @objc private func revealInFinder() {
        let path = FileManager.default.currentDirectoryPath
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    @objc private func openLogInspector() {
        PluginLogWindowController.shared.showInspector()
    }

    @objc private func showWindow() {
        guard let win = windowController?.window else { return }
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
