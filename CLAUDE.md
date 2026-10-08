# CLAUDE.md — AI Assistant Guide & Project Conventions

Quick context documentation for LLM assistants (Claude / DeepSeek Harness / GPT) working on the `dsh-desktop-macos` repository.

---

## 1. Project Overview
`dsh-desktop-macos` is an ultra-lightweight native macOS desktop shell built with AppKit + WebKit (WKWebView) for the local `dsh web` (DeepSeek Harness) server. It serves as a modern macOS equivalent to the Windows WinForms/WebView2 wrapper (`Ackow/dsh-desktop`), keeping the release binary size below 500 KB with zero Electron overhead.

---

## 2. Build Commands & Quick Execution

```bash
# Fast local Intel x86_64 compilation:
./scripts/build-intel.sh

# Universal 2 (Intel x86_64 + Apple Silicon arm64) release compilation:
./scripts/build-universal.sh

# Package into distributable DMG installer:
./scripts/package-dmg.sh

# Run self-check / sanity diagnostics target:
swift run DSHDesktopCheck

# Debug build using Swift Package Manager:
swift build
```

Build outputs are placed in:
- Application Bundle: `dist/DSHDesktop.app`
- Executable Binary: `dist/DSHDesktop.app/Contents/MacOS/DSHDesktop`
- DMG Package: `dist/DeepSeek Harness.dmg`

---

## 3. Swift Conventions & Architecture
- **Language & Runtime:** Swift 6.0, minimum deployment target `macOS 13.0` (Ventura).
- **Concurrency & Parallelism:** Prioritize modern `async/await`, `@MainActor` for UI controllers, and `Sendable` conformance following Swift 6 standards.
- **Native Frameworks:** Strictly rely on `AppKit`, `WebKit`, and `Network.framework` (`NWConnection`). Avoid third-party dependencies whenever native macOS APIs suffice.
- **Window Styling:** Configure `NSWindow.StyleMask.fullSizeContentView` with `titlebarAppearsTransparent = true` and `titleVisibility = .hidden` for seamless integration with the WebKit canvas.
- **JavaScript-to-Swift Bridge:**
  - Handled in `WebViewController.swift` via `WKScriptMessageHandler`.
  - Registered message handlers: `openTerminal`, `revealInFinder`, `desktopAction`, `pluginLog`.
  - Runtime global helpers injected: `window.dshNative`, `window.dshDesktopActions`, `window.dshDesktop`.

---

## 4. Quick Troubleshooting
- **Server Not Responding:** Check TCP port 3080 listener status using `lsof -nP -iTCP:3080 -sTCP:LISTEN`.
- **Blank View or Stale Cache:** Press `Cmd + R` inside the application to trigger a hard cache purge of the WebKit HTTP store.
- **JavaScript & Plugin Error Logs:** Open `Window` -> `Plugin & JS Log Inspector` (`Cmd + Shift + L`) to view real-time streaming logs.
