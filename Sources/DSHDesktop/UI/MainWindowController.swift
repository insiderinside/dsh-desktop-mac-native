import Cocoa
import WebKit

/// Custom window class that detects double clicks on the titlebar/drag region
/// to toggle window maximization across the visible screen frame.
public final class DSHWindow: NSWindow {
    public override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown && event.clickCount == 2 {
            let loc = event.locationInWindow
            // Top drag region (navbar area within 50pt from the top edge of the window)
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
            // Restore previous window frame
            setFrame(prev, display: true, animate: true)
            previousFrame = nil
        } else {
            // Store frame before maximizing
            previousFrame = frame
            setFrame(visibleFrame, display: true, animate: true)
        }
    }
}

/// Primary window controller featuring integrated transparent modern macOS titlebar.
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

        // ponytail: Auto-maximize on fresh launch if no persistent frame exists
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

    /// Maximizes window to fill the entire visible frame of the active display
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
