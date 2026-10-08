# CLAUDE.md — Panduan Asisten AI & Konvensi Proyek

Berkas konteks cepat untuk asisten LLM (Claude / DeepSeek Harness / GPT) yang bekerja di repositori `dsh-desktop-macos`.

---

## 1. Ringkasan Proyek
`dsh-desktop-macos` adalah native desktop wrapper AppKit + WebKit untuk server lokal `dsh web` (DeepSeek Harness) di macOS, dirancang sebagai pengganti native untuk wrapper Windows WinForms/WebView2 (`Ackow/dsh-desktop`). Ukuran binary release < 500 KB, tanpa overhead Electron.

---

## 2. Command Build & Eksekusi Cepat

```bash
# Build binary & bundle Intel x86_64 lokal (cepat):
./scripts/build-intel.sh

# Build Universal 2 (Intel x86_64 + Apple Silicon arm64):
./scripts/build-universal.sh

# Bungkus ke file DMG siap distribusi:
./scripts/package-dmg.sh

# Menjalankan self-check / sanity test target:
swift run DSHDesktopCheck

# Jalankan build debug SPM langsung:
swift build
```

Hasil build diletakkan di:
- Executable/App: `dist/DSHDesktop.app`
- Binary: `dist/DSHDesktop.app/Contents/MacOS/DSHDesktop`

---

## 3. Konvensi Kode Swift & Arsitektur
- **Bahasa & Runtime:** Swift 6.0, target minimal `macOS 13.0` (Ventura).
- **Paralelisme & Concurrency:** Utamakan modern `async/await`, `@MainActor` untuk UI Controller, dan protokol `Sendable` sesuai standar Swift 6.
- **Framework Native:** Murni memakai `AppKit`, `WebKit`, dan `Network.framework` (`NWConnection`). Hindari dependensi pihak ketiga jika API native macOS sudah menyediakannya.
- **Titlebar & Styling:** Menggunakan `NSWindow.StyleMask.fullSizeContentView` dengan `titlebarAppearsTransparent = true` dan `titleVisibility = .hidden` agar menyatu dengan UI WebKit.
- **Bridge JavaScript-ke-Swift:**
  - Ditangani di `WebViewController.swift` via `WKScriptMessageHandler`.
  - Handler terdaftar: `openTerminal`, `revealInFinder`, `desktopAction`, `pluginLog`.
  - Injeksi runtime helper: `window.dshNative`, `window.dshDesktopActions`, `window.dshDesktop`.

---

## 4. Troubleshooting Singkat
- **Server Tidak Terkoneksi:** Cek status listener port 3080 via `lsof -nP -iTCP:3080 -sTCP:LISTEN`.
- **Halaman Blank atau Cache Usang:** Di dalam app tekan `Cmd + R` untuk memicu hard-reload yang membersihkan cache WebKit `WKWebsiteDataStore`.
- **Log Error JavaScript WebKit:** Buka menu `Window` -> `Plugin Logs` (`Cmd + Shift + L`) untuk melihat streaming log JavaScript/WebKit secara terpusat.
