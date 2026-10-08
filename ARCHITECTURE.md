# ARCHITECTURE.md — Arsitektur Sistem DSH Desktop macOS

Dokumentasi arsitektur sistem native shell macOS untuk **DeepSeek Harness (DSH)**.

---

## 1. Ikhtisar Arsitektur (High-Level Architecture)

`dsh-desktop-macos` mengadopsi model **Hybrid Host-Client**:
- **Host Layer (Native AppKit/Swift):** Bertanggung jawab atas inisialisasi lifecycle aplikasi macOS, port probe, manajemen window, menu bar, system bridge, dan integrasi OS native (Terminal, Finder, Notification, Global Hotkey).
- **Embedded Web Client Layer (WebKit / WKWebView):** Menampilkan antarmuka DeepSeek Harness web yang berjalan di localhost (`http://127.0.0.1:3080`).

```
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
    │  (NSWindow, Tabbing)     │
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
    │  - DshLocator (Deteksi Path Binary DSH di macOS)        │
    │  - DshProcessSupervisor (Lifecycle Management)          │
    │  - DshAuthSigner (Cookie & Session Signing)             │
    │  - HealthChecker (Warmup & HTTP Verification)           │
    │  - NotificationManager (UNUserNotificationCenter)       │
    │  - PluginLogStore (In-Memory Ring Buffer 1000 Baris)    │
    └─────────────────────────────────────────────────────────┘
```

---

## 2. Struktur Paket & Target SPM (Swift Package Manager)

Proyek didefinisikan dalam `Package.swift` dengan 4 target:

### A. `DSHDesktopCore` (Framework / Library)
Modul utilitas independen sistem dan networking:
1. **`PortProbe.swift`**: Polling ketersediaan TCP port target menggunakan `Network.framework` (`NWConnection`). Mendeteksi kesiapan server web secara asinkron tanpa memblokir thread UI.
2. **`DshLocator.swift`**: Menemukan lokasi binary CLI `dsh` pada path instalasi standar (`/usr/local/bin/dsh`, `~/.local/bin/dsh`, dll).
3. **`DshProcessSupervisor.swift`**: Mengelola spawning proses sub-server `dsh web --profile webplugins --port 3080` dan memastikan cleanup proses secara tertib saat aplikasi ditutup.
4. **`DshAuthSigner.swift`**: Menghasilkan token tanda tangan/cookie autentikasi lokal untuk memvalidasi sesi WebView ke server internal.
5. **`HealthChecker.swift`**: Memvalidasi respon HTTP sebelum halaman utama dimuat untuk mengeliminasi status stuck "reconnecting".
6. **`NotificationManager.swift`**: Mengirimkan notifikasi banner sistem native saat agent menyelesaikan giliran percakapan atau background tasks.
7. **`PluginLogStore.swift`**: Menyimpan entri log JavaScript/WebKit secara thread-safe (`@MainActor`) dengan kapasitas buffer 1.000 log terbaru.

### B. `DSHDesktopUI` (Framework / Library)
Modul antarmuka AppKit dan WebKit:
1. **`MainWindowController.swift`**:
   - Menangani pembuatan `NSWindow` dengan `fullSizeContentView`.
   - Konfigurasi window autosave frame (`UserDefaults`) dan auto-maximize saat pertama kali dibuka.
   - Dukungan native macOS tabbed windows (`NSWindow.tabbingMode = .preferred`).
2. **`WebViewController.swift`**:
   - Mengelola lifecycle `WKWebView`.
   - Menginjeksi user scripts: disable spellcheck/autocorrect dan membuat bridge `window.dshNative`, `window.dshDesktopActions`, `window.dshDesktop`.
   - Menerima event via `WKScriptMessageHandler`:
     - `openTerminal`: Membuka `Terminal.app` bawaan macOS pada target path.
     - `revealInFinder`: Menampilkan path di Finder (`NSWorkspace`).
     - `desktopAction`: Aksi antarmuka khusus desktop.
     - `pluginLog`: Menangkap console error/warn dari WebKit ke `PluginLogStore`.
   - Kebijakan cache: `.reloadIgnoringLocalCacheData` dan pembersihan cache selektif pada reload (`Cmd + R`) tanpa menghapus session cookie/localStorage.
3. **`MenuBarController.swift`**:
   - Mengelola icon status item di macOS Menu Bar (`NSStatusItem`).
   - Menyediakan menu cepat: toggle window, switch profil DSH (`~/.dsh/profiles`), buka logs window, dan quit.
4. **`PluginLogWindowController.swift`**:
   - Jendela antarmuka terpisah untuk memantau streaming log JavaScript/WebKit secara real-time (`NSTableView`).

### C. `DSHDesktop` (Executable Target)
- **`main.swift`**: Titik masuk runtime program.
- **`AppDelegate.swift`**:
   - Inisialisasi `NSApplication`.
   - Pengaturan menu utama macOS (File, Edit, View, Window, Help).
   - Registrasi global shortcut (`Option + Space`) untuk toggle jendela utama.

### D. `DSHDesktopCheck` (Diagnostic Target)
- Binary CLI ringan untuk memeriksa kesehatan port 3080, validasi konfigurasi, dan self-check tanpa menampilkan UI.

---

## 3. Komunikasi & System Bridge

### Bridge JavaScript-ke-Swift (WebKit Script Message Handler)
Runtime web menyuntikkan objek global di `window`:
```javascript
// Membuka direktori kerja di Terminal native macOS
window.dshNative.openTerminal(projectPath);

// Menampilkan file/folder di Finder
window.dshNative.revealInFinder(filePath);

// Menjalankan aksi desktop tertentu
window.dshDesktopActions.openTerminal();
```

Saat fungsi dipanggil, WebKit mengirimkan pesan melalui channel `window.webkit.messageHandlers.<name>.postMessage(...)` yang langsung diterima oleh `WebViewController.userContentController(_:didReceive:)` di sisi Swift untuk dieksekusi secara native via `NSWorkspace.shared`.

---

## 4. Lifecycle & Alur Booting

```
[1] User Meluncurkan DSHDesktop
      │
[2] AppDelegate: Inisialisasi Menu Bar & Menu Utama
      │
[3] PortProbe: Cek ketersediaan TCP port 3080
      ├─── Belum Aktif ──► DshProcessSupervisor: Spawn proses "dsh web"
      │                             │ (Poll sampai port terbuka)
      └─── Sudah Aktif ─────────────┘
      │
[4] HealthChecker: Lakukan HTTP ping ringan ke port 3080
      │
[5] MainWindowController: Buka NSWindow utama
      │
[6] WebViewController: Buat WKWebView & loadRequest(http://127.0.0.1:3080)
      │
[7] User Script: Injeksi bridge window.dshNative & window.dshDesktop
      │
[8] App Siap Digunakan (Interaksi Chat & Workbench)
```

---

## 5. Pertimbangan Performa & Footprint Memori
- **Binary Size:** < 500 KB (dibandingkan bundle Electron yang berukuran > 150 MB).
- **RAM Overhead:** Shell native Swift mengonsumsi < 25 MB RAM di luar engine WebKit webview bawaan macOS.
- **Kompilasi Universal:** Menggunakan arsitektur Mach-O Universal 2 (`x86_64` untuk Intel dan `arm64` untuk Apple Silicon) sehingga berjalan optimal tanpa layer emulasi Rosetta 2 di Apple Silicon.
