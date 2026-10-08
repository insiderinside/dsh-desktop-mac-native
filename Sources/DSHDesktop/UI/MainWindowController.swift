import Cocoa
import WebKit

/// Window khusus yang mendeteksi double click pada titlebar/top drag region
/// untuk melakukan toggle auto-maximize (full width & height pada visible screen).
public final class DSHWindow: NSWindow {
    public override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown && event.clickCount == 2 {
            let loc = event.locationInWindow
            // Top region (area drag / header navbar setinggi 50pt dari atas window)
            if loc.y >= (frame.height - 50) {
                toggleMaximizeWidth()
                return
            }
        }
        super.sendEvent(event)
    }

    private var previousFrame: NSRect?

    @objc public func toggleMaximizeWidth() {
        guard let screen = self.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        if let prev = previousFrame, frame.equalTo(visibleFrame) {
            // Restore ke ukuran semula
            setFrame(prev, display: true, animate: true)
            previousFrame = nil
        } else {
            // Simpan ukuran sebelum maximize
            previousFrame = frame
            setFrame(visibleFrame, display: true, animate: true)
        }
    }
}

/// Window Controller utama dengan titlebar terintegrasi bergaya modern macOS.
public final class MainWindowController: NSWindowController, NSWindowDelegate {
    private static let frameAutosaveKey = "DSHMainWindowFrame"

    public init(viewController: NSViewController) {
        let defaultRect = NSRect(x: 100, y: 100, width: 1200, height: 800)
        let window = DSHWindow(
            contentRect: defaultRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DeepSeek Harness Desktop"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 800, height: 600)

        // ponytail: Jika user menginginkan saat buka pertama aplikasi langsung full width / maximized
        let hasSavedFrame = UserDefaults.standard.string(forKey: "NSWindow Frame \(MainWindowController.frameAutosaveKey)") != nil
        if !hasSavedFrame, let screen = NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        } else {
            _ = window.setFrameUsingName(MainWindowController.frameAutosaveKey)
        }
        window.setFrameAutosaveName(MainWindowController.frameAutosaveKey)

        window.contentViewController = viewController

        super.init(window: window)
        window.delegate = self
    }

    /// Memaksimalkan jendela ke seluruh lebar dan tinggi layar yang tersedia (visibleFrame)
    public func maximizeWindow() {
        guard let win = self.window, let screen = win.screen ?? NSScreen.main else { return }
        win.setFrame(screen.visibleFrame, display: true, animate: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        if let dshWin = window as? DSHWindow {
            dshWin.toggleMaximizeWidth()
            return false
        }
        return true
    }

    public func windowWillClose(_ notification: Notification) {
        window?.saveFrame(usingName: MainWindowController.frameAutosaveKey)
    }
}
