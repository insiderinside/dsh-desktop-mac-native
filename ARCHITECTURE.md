# ARCHITECTURE.md — System Architecture for DSH Desktop macOS

System architecture documentation for the native macOS desktop shell of **DeepSeek Harness (DSH)**.

---

## 1. High-Level Architecture Overview

`dsh-desktop-macos` adopts a **Hybrid Host-Client** architectural pattern:
- **Host Layer (Native AppKit/Swift):** Manages application lifecycle, TCP socket probing, window management, status bar companion, native notifications, global hotkeys, and system bridges (Terminal, Finder).
- **Embedded Web Client Layer (WebKit / WKWebView):** Renders the DeepSeek Harness web interface running on localhost (`http://127.0.0.1:3080`).

```text
┌─────────────────────────────────────────────────────────────┐
│                       macOS System                          │
│   (AppKit Event Loop, NotificationCenter, NSWorkspace)     │
└───────────────▲─────────────────────────────▲───────────────┘
                │                             │
    ┌───────────┴──────────────┐  ┌───────────┴──────────────┐
    │     NSApplication        │  │     NSStatusItem         │
    │  (AppDelegate / main)    │  │   (MenuBarController)    │
    └───────────┬──────────────┘  └──────────────────────────┘
                │
    ┌───────────▼──────────────┐
    │  MainWindowController    │
    │  (NSWindow, Tabs)        │
    └───────────┬──────────────┘
                │
    ┌───────────▼─────────────────────────────────────────────┐
    │                 WebViewController                       │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │                   WKWebView                       │  │
    │  │  - URL: http://127.0.0.1:3080                      │  │
    │  │  - Script Message Handlers:                       │  │
    │  │    * openTerminal       * revealInFinder          │  │
    │  │    * desktopAction      * pluginLog               │  │
    │  └───────────────────────▲───────────────────────────┘  │
    └──────────────────────────┼──────────────────────────────┘
                               │ WebKit Message Bridge
    ┌──────────────────────────▼──────────────────────────────┐
    │                 DSHDesktopCore                          │
    │  - PortProbe (TCP 3080 Polling via NWConnection)        │
    │  - DshLocator (CLI Binary Path Discovery)               │
    │  - DshProcessSupervisor (Lifecycle Management)          │
    │  - DshAuthSigner (Cookie & Session Signing)             │
    │  - HealthChecker (Warmup & HTTP Verification)           │
    │  - NotificationManager (UNUserNotificationCenter)       │
    │  - PluginLogStore (In-Memory Ring Buffer, 1000 items)   │
    └─────────────────────────────────────────────────────────┘
```

---

## 2. Package Structure & SPM Targets

The project is structured in `Package.swift` across four distinct targets:

### A. `DSHDesktopCore` (Framework / Library)
System utilities, socket networking, and runtime supervision:
1. **`PortProbe.swift`**: Asynchronously verifies TCP port availability using `Network.framework` (`NWConnection`) without blocking the main UI thread.
2. **`DshLocator.swift`**: Discovers the local `dsh` CLI binary across standard Unix installation paths (`~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, etc.).
3. **`DshProcessSupervisor.swift`**: Manages child process spawning for `dsh web --port 3080` and guarantees clean SIGTERM process termination upon application exit.
4. **`DshAuthSigner.swift`**: Computes local HMAC authentication cookies matching `@deepseek-ai/dsh-client-connection` specifications for authenticated WebView sessions.
5. **`HealthChecker.swift`**: Polls HTTP status codes prior to initial WebView load to prevent infinite "reconnecting" blank screens.
6. **`NotificationManager.swift`**: Dispatches system banner alerts via `UserNotifications` when long-running agent tasks complete.
7. **`PluginLogStore.swift`**: Thread-safe in-memory circular buffer (`@MainActor`) capturing up to 1,000 WebKit console errors and plugin warnings.

### B. `DSHDesktopUI` (Framework / Library)
AppKit and WebKit user interface components:
1. **`MainWindowController.swift`**:
   - Manages `NSWindow` with `fullSizeContentView` and transparent titlebar styling.
   - Restores window size and position from `UserDefaults` with first-launch auto-maximization.
   - Native macOS window tabbing support (`NSWindow.tabbingMode = .preferred`).
2. **`WebViewController.swift`**:
   - Manages `WKWebView` lifecycle and dark mode placeholder backgrounds.
   - Injects user scripts to disable spellcheck/autocorrect and provisions `window.dshNative`, `window.dshDesktopActions`, and `window.dshDesktop`.
   - Handles `WKScriptMessageHandler` events:
     - `openTerminal`: Opens macOS `Terminal.app` at the workspace target path.
     - `revealInFinder`: Reveals project directory in Finder via `NSWorkspace`.
     - `desktopAction`: Custom desktop interface actions.
     - `pluginLog`: Captures uncaught JavaScript errors into `PluginLogStore`.
   - Cache policy: Purges HTTP cache on reload (`Cmd + R`) while preserving local session cookies and preferences.
3. **`MenuBarController.swift`**:
   - Manages macOS status bar item (`NSStatusItem`).
   - Quick action menu: window toggle, active profile switcher (`~/.dsh/profiles`), log inspector launcher, and quit.
4. **`PluginLogWindowController.swift`**:
   - Dedicated floating window for live streaming WebKit JavaScript and plugin error logs (`NSTextView`).

### C. `DSHDesktop` (Executable Target)
- **`main.swift`**: Application runtime entry point.
- **`AppDelegate.swift`**:
  - Initializes `NSApplication`.
  - Configures macOS standard menu bar items (File, Edit, View, Tools, Window, Help).
  - Registers global shortcut listener (`Option + Space`) to toggle main window visibility.

### D. `DSHDesktopCheck` (Diagnostic Target)
- Lightweight CLI tool to verify port probing, locator resolution, supervisor transitions, and log store integrity without rendering any UI.

---

## 3. Communication & Native System Bridge

### JavaScript-to-Swift Bridge (`WKScriptMessageHandler`)
The WebKit runtime exposes global bridge helpers on `window`:
```javascript
// Open workspace directory in native macOS Terminal
window.dshNative.openTerminal(projectPath);

// Reveal project files in Finder
window.dshNative.revealInFinder(filePath);

// Trigger desktop-specific actions
window.dshDesktopActions.invoke("openTerminal");
```

Calls pass through `window.webkit.messageHandlers.<name>.postMessage(...)` and are intercepted by `WebViewController.userContentController(_:didReceive:)` in Swift to execute native macOS APIs (`NSWorkspace.shared`).

---

## 4. Lifecycle & Boot Flow

```text
[1] User launches DSHDesktop
      │
[2] AppDelegate: Configures Menu Bar & Main Window Controllers
      │
[3] PortProbe: Checks TCP port 3080 availability
      ├─── Inactive ──► DshProcessSupervisor: Spawns "dsh web" child process
      │                       │ (Polls until port opens)
      └─── Active ────────────┘
      │
[4] HealthChecker: Polls HTTP 200 OK endpoint with authentication cookie
      │
[5] MainWindowController: Displays primary NSWindow
      │
[6] WebViewController: Loads WKWebView request (http://127.0.0.1:3080)
      │
[7] User Script: Injects window.dshNative & window.dshDesktop bridges
      │
[8] Application Ready for Interactive Chat & Tool Workflows
```

---

## 5. Performance & Memory Profile
- **Binary Footprint:** < 500 KB executable bundle (versus 150+ MB Electron distributions).
- **RAM Overhead:** Native Swift shell consumes < 25 MB RAM outside macOS WebKit shared engine resources.
- **Universal Binary:** Compiled for Mach-O Universal 2 (`x86_64` for Intel and `arm64` for Apple Silicon) with zero Rosetta 2 emulation overhead.
