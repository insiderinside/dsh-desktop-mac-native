# DeepSeek Harness Desktop for macOS (DSH Desktop)

[![CI](https://github.com/insiderinside/dsh-desktop-mac-native/actions/workflows/ci.yml/badge.svg)](https://github.com/insiderinside/dsh-desktop-mac-native/actions/workflows/ci.yml)
[![Release](https://github.com/insiderinside/dsh-desktop-mac-native/actions/workflows/release.yml/badge.svg)](https://github.com/insiderinside/dsh-desktop-mac-native/actions/workflows/release.yml)
[![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B-lightgrey.svg?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square)](https://swift.org)
[![Architecture](https://img.shields.io/badge/arch-Universal%202%20(Intel%20%2B%20Apple%20Silicon)-blue.svg?style=flat-square)](#building-from-source)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)

[English](README.md) | [中文说明](README.zh-CN.md)

Ultra-lightweight native macOS desktop shell (< 500 KB binary) for the local [DeepSeek Harness](https://github.com/deepseek-ai) web interface (`dsh web`), built using Swift, AppKit, and WebKit (WKWebView).

Designed as an efficient macOS equivalent to Windows WinForms/WebView2 wrappers, completely eliminating the heavy 150+ MB overhead of Electron.

---

## Key Features

- **Blazing Fast & Ultra-Lightweight**: Native binary under 500 KB, minimal memory footprint, instant startup.
- **Universal 2 Binary**: Full native support for both Apple Silicon (M1/M2/M3/M4) and Intel (x86_64) Macs.
- **Seamless Modern UI**: `fullSizeContentView` with transparent titlebar, matching macOS design aesthetics.
- **Native macOS Tabs**: Native window tab support (`Cmd + T`) to manage multiple sessions side by side.
- **Global Hotkey Toggle**: Instant show/hide via `Option + Space` with automatic input focus.
- **macOS Menu Bar Companion**: Real-time server connection indicator, quick profile switcher, and window toggle.
- **Bidirectional Native Bridge (`WKScriptMessageHandler`)**:
  - Open current project directly in `Terminal.app` (`Cmd + Shift + T`).
  - Reveal active files or project directories in Finder (`Cmd + Shift + R`).
  - Integrated console log streaming window (`Cmd + Shift + L`).
- **Native Notifications**: Desktop banner alerts when long-running agent tasks or background jobs complete.
- **Local Server Lifecycle Supervisor**: Automatically discovers local `dsh` installation, probes port readiness, and manages lifecycle cleanups.

---

## System Requirements

- **Operating System**: macOS 13.0 (Ventura) or newer
- **Architecture**: Apple Silicon (`arm64`) or Intel (`x86_64`)
- **Backend Service**: `dsh` CLI installed and accessible locally (running on `http://127.0.0.1:3080`)

---

## Quick Installation

Download the latest `.dmg` or `.app` from [GitHub Releases](../../releases).

1. Open `DeepSeek Harness.dmg`.
2. Drag **DeepSeek Harness** into your `/Applications` directory.
3. Launch the app. If `dsh web` is already running on port 3080, it connects immediately. Otherwise, it will launch or prompt automatically.

---

## Building from Source

### Prerequisites

- Xcode 15.0+ or Command Line Tools with Swift 6.0 toolchain.
- macOS 13.0+ SDK.

### Build Commands

Clone the repository and build using SPM or provided shell scripts:

```bash
git clone https://github.com/your-username/dsh-desktop-macos.git
cd dsh-desktop-macos

# Fast local Intel x86_64 build:
./scripts/build-intel.sh

# Universal 2 (Intel + Apple Silicon) release build:
./scripts/build-universal.sh

# Create distributable DMG installer:
./scripts/package-dmg.sh

# Run lightweight diagnostic sanity check:
swift run DSHDesktopCheck
```

Build outputs are saved to:
- Application Bundle: `dist/DSHDesktop.app`
- Executable Binary: `dist/DSHDesktop.app/Contents/MacOS/DSHDesktop`
- DMG Package: `dist/DeepSeek Harness.dmg`

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Option + Space` | Toggle main window visibility (Global Hotkey) |
| `Cmd + T` | Open new native session tab |
| `Cmd + R` | Reload WebKit view and purge cache |
| `Cmd + Shift + T` | Open current workspace in Terminal.app |
| `Cmd + Shift + R` | Reveal workspace folder in Finder |
| `Cmd + Shift + L` | Open Plugin & WebKit Logs inspector |
| `Cmd + +` / `Cmd + -` | Zoom in / Zoom out |
| `Cmd + 0` | Reset zoom to default (90%) |

---

## Architecture Overview

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
    │  │  - Native Bridge: openTerminal, revealInFinder... │  │
    │  └───────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────┘
```

For in-depth design details, refer to [ARCHITECTURE.md](ARCHITECTURE.md).

---

## License

This project is licensed under the [MIT License](LICENSE).
