import Cocoa
import DSHDesktopCore

/// Window controller untuk menampilkan log live plugin & JavaScript error
@MainActor
public final class PluginLogWindowController: NSWindowController {
    public static let shared = PluginLogWindowController()

    private let textView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "Memantau log plugin & JavaScript...")

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 150, y: 150, width: 850, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DSH Plugin & JavaScript Log Inspector"
        window.minSize = NSSize(width: 500, height: 300)

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 850, height: 500))

        // Toolbar baris atas: Tombol Bersihkan & Label
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 10
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let clearButton = NSButton(title: "Bersihkan Log", target: nil, action: nil)
        clearButton.bezelStyle = .rounded
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        toolbar.addArrangedSubview(clearButton)
        toolbar.addArrangedSubview(statusLabel)
        root.addSubview(toolbar)

        // Text Scroll View untuk log
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        textView.textColor = NSColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1.0)
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            toolbar.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        window.contentView = root
        super.init(window: window)

        clearButton.target = self
        clearButton.action = #selector(clearLogs)

        // Hubungkan ke PluginLogStore
        refreshLogs()
        PluginLogStore.shared.onNewEntry = { [weak self] _ in
            self?.refreshLogs()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func clearLogs() {
        PluginLogStore.shared.clear()
        textView.string = ""
        statusLabel.stringValue = "Log dibersihkan."
    }

    public func refreshLogs() {
        let entries = PluginLogStore.shared.entries
        let text = entries.map { $0.formatted }.joined(separator: "\n")
        textView.string = text
        if let textStorage = textView.textStorage {
            textView.scrollRangeToVisible(NSRange(location: textStorage.length, length: 0))
        }
        let errorCount = entries.filter { $0.level == .error }.count
        statusLabel.stringValue = "Total: \(entries.count) log | \(errorCount) Error"
    }

    public func showInspector() {
        refreshLogs()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
