# AGENT.md — Agent Operational Instructions (dsh-desktop-macos)

Operational guidelines for AI agents working on the **DSH Desktop macOS** project repository (`/Users/promac/Projects/dsh-desktop-macos`).

---

## 1. Role & Core Philosophy (Lazy Senior Developer)
- **Host Stability First:** Never kill or terminate running `DSHDesktop` or background Node processes blindly while the user is actively engaged in a conversation session.
- **Shortest Working Diff:** Solve issues with minimal, precise, and idiomatic code changes. Never introduce unrequested layers of abstraction or speculative boilerplate.
- **Fail Fast & Test Early:** Verify changes directly via build scripts or SPM test targets (`./scripts/build-intel.sh` or `swift run DSHDesktopCheck`) before declaring task completion.
- **Communication Language:** Respect the global workspace interaction protocol (`~/.dsh/AGENTS.md`).

---

## 2. Project Architecture & Module Ownership
- `Package.swift`: Multi-target SPM manifest (Swift 6.0, macOS 13+).
  - `DSHDesktopCore`: Process supervision, port probe, authentication cookie signer, HTTP health check, notification management, and in-memory log buffer.
  - `DSHDesktopUI`: `WebViewController` (WKWebView container & JS message handler bridge), `MainWindowController`, `MenuBarController`, `PluginLogWindowController`.
  - `DSHDesktop`: Main executable target (`main.swift`, `AppDelegate.swift`).
  - `DSHDesktopCheck`: Diagnostic CLI self-check suite.
- `Resources/`: `Info.plist`, `AppIcon.icns`.
- `scripts/`:
  - `build-intel.sh`: Release build for x86_64 Intel Macs outputting to `dist/DSHDesktop.app`.
  - `build-universal.sh`: Universal 2 (`lipo`) compilation for Intel and Apple Silicon architectures.
  - `package-dmg.sh`: Disk image packager creating `DeepSeek Harness.dmg`.

---

## 3. Important Gotchas & Anti-Patterns
1. **Never Kill Active Interactive Processes:**
   - The user operates conversations through `DSHDesktop` or a browser session. Blindly invoking `pkill` will drop active user sessions abruptly.
   - For frontend or plugin updates, instruct users to reload (`Cmd + R`) or run isolated smoke tests.
2. **WebKit Cache Behavior:**
   - WKWebView caches disk artifacts under `~/Library/Caches/dev.dsh.desktop`.
   - `WebViewController.swift` employs `.reloadIgnoringLocalCacheData` and clears disk/memory caches during explicit reload events without wiping session cookies or local storage.
3. **Host vs Plugin Runtime Version Boundaries:**
   - The DSH Desktop wrapper supports DeepSeek Harness upstream releases, including `v0.2.1-alpha.1` and `0.2.0-rc.2`.
   - Packages located under `~/.dsh/profiles/node_modules/@deepseek-ai/*` may reference differing runtime targets. Maintain awareness of version shims.
4. **Build Verification Standard:**
   - Always run `swift run DSHDesktopCheck` or `./scripts/build-intel.sh` after updating `.swift` source files. Ensure clean exit status 0.

---

## 4. Memory & Logging
- Store durable architectural findings or bug fixes in ICM when appropriate.
- Always append the structured completion block at the end of each response.
