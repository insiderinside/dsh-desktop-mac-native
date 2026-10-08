# Plan Porting Web ke Native macOS WKWebView Shell (Universal 2: Intel x86_64 & Apple Silicon arm64)

## 1. Tujuan
Membangun native shell macOS yang ringan (< 5 MB) menggunakan Swift + AppKit + WKWebView untuk membungkus server lokal `dsh web`, menggantikan pendekatan Windows WinForms/WebView2 dari `Ackow/dsh-desktop`.

## 2. Struktur Direktori Proyek
Path: `/Users/promac/Projects/dsh-desktop-macos`

```text
/Users/promac/Projects/dsh-desktop-macos/
├── Package.swift
├── Sources/
│   └── DSHDesktop/
│       ├── App/
│       │   ├── AppDelegate.swift
│       │   └── main.swift
│       ├── UI/
│       │   ├── MainWindowController.swift
│       │   ├── WebViewController.swift
│       │   └── MenuBarController.swift
│       ├── Core/
│       │   ├── DshLocator.swift
│       │   ├── PortProbe.swift
│       │   ├── DshProcessSupervisor.swift
│       │   └── AppConfig.swift
│       └── Check/
│           └── main.swift
├── Resources/
│   ├── AppIcon.icns
│   └── Info.plist
└── scripts/
    ├── build-intel.sh
    ├── build-universal.sh
    └── package-dmg.sh
```

## 3. Status Realisasi & Eksekusi
- [x] **Fase 1: Project Scaffolding & Build System**
  - Setup multi-target SPM di `Package.swift` (Swift 6.0, macOS 13+).
  - Target: `DSHDesktopCore`, `DSHDesktopUI`, `DSHDesktop` (executable), `DSHDesktopCheck` (self-check).
- [x] **Fase 2: Core Subprocess & Port Management**
  - `DshLocator.swift`: Deteksi path binary `dsh` pada direktori standar macOS.
  - `PortProbe.swift`: Async TCP socket polling via `Network.framework` (`NWConnection`).
  - `DshProcessSupervisor.swift`: Manajemen lifecycle process `dsh web` dan penanganan shutdown bersih (SIGTERM).
  - `AppConfig.swift`: Konfigurasi host dan target port web.
- [x] **Fase 3: Native WebKit View & Window Shell**
  - `WebViewController.swift`: WKWebView container dengan loading indicator.
  - `MainWindowController.swift`: Full-size content window dengan titlebar modern transparan.
  - `MenuBarController.swift`: Menu bar item status (`NSStatusItem`) dengan kontrol window & keluar aplikasi.
- [x] **Fase 4: Packaging & Universal Binary Verification**
  - `scripts/build-intel.sh`: Build cepat khusus x86_64 Intel Mac (< 1 detik, binary ~158 KB).
  - `scripts/build-universal.sh`: Kompilasi Universal 2 (`lipo`) menggabungkan x86_64 dan arm64.
  - `scripts/package-dmg.sh`: Pembuatan installer DMG drag-and-drop (`DeepSeek Harness.dmg` ~127 KB).
- [x] **Fase 5: UX Polish & Lifecycle Stabilization**
  - Window frame autosave persistence (`NSUserDefaults`) & auto-maximize full-screen pada peluncuran pertama.
  - Skala zoom default 90% (0.9) dengan persistence state.
  - Disable auto-spelling dan autocorrect pada semua field input web via script injection (`WKUserScript`).
  - Native file upload integration via `WKUIDelegate` (`NSOpenPanel`).
  - Warmup delay & HTTP health checker untuk eliminasi bug stuck "reconnecting".
  - Sinkronisasi penamaan sistem (`DeepSeek Harness Desktop`) di AppKit dan Info.plist.
  - Integrasi modul notifikasi desktop (`dsh-turn-done-notify`) untuk penyelesaian turn dan background jobs.

---

## 4. Roadmap Pengembangan Lanjutan (Next Features)

### [x] Fase 6: Native System Bridge (`WKScriptMessageHandler`)
- Menambahkan bridge komunikasi JavaScript-ke-Swift dua arah via `WKScriptMessageHandler`:
  - **Aksi "Buka Terminal" (`openTerminal`)**: Mengeksekusi pembukaan project workspace langsung di `Terminal.app` bawaan macOS. Tersedia juga via Menu Bar dan Shortcut `Cmd + Shift + T`.
  - **Aksi "Buka di Finder" (`revealInFinder`)**: Menampilkan direktori file project di Finder menggunakan `NSWorkspace.shared.activateFileViewerSelecting`. Tersedia via Menu Bar dan Shortcut `Cmd + Shift + R`.
  - Injeksi global helper `window.dshNative.openTerminal()` dan `window.dshNative.revealInFinder()` di runtime webview.

### [x] Fase 7: Menu Bar Popover & Status Agent (Raycast Style)
- Mengembangkan `MenuBarController.swift`:
  - Indikator visual status server real-time pada menu bar (`● DSH` - Port 3080: Aktif).
  - Header status detail port dan menu toggle jendela instan.

### [x] Fase 8: Global Hotkey Quick Toggle
- Menambahkan listener event keyboard shortcut (`Option + Space`):
  - Memanggil / menyembunyikan (toggle) jendela utama DeepSeek Harness Desktop secara instan.
  - Menjamin fokus input otomatis kembali ke area prompt saat jendela dimunculkan.

### [x] Fase 9: Multi-Profile & Workspace Switcher
- Menambahkan integrasi profil manager pada Menu Bar:
  - Otomatis memindai profil yang terdaftar di `~/.dsh/profiles/` (desktop, dsh-tui, headless, web, web-custom, webplugins).
  - Menampilkan profil aktif (`webplugins`) dengan tanda centang dan dialog pemilih profil.

### [x] Fase 10: Multi-Window / Native Tab Support
- Mengaktifkan fitur AppKit Window Tabbing (`NSWindow.tabbingMode = .preferred`):
  - Membuka sesi obrolan dalam tab native macOS yang terintegrasi di jendela yang sama menggunakan shortcut standar `Cmd + T` (Menu Window -> Tab Baru).
