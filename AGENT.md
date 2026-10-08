# AGENT.md — Instruksi Kerja Agent (dsh-desktop-macos)

Panduan operasional agent untuk proyek **DSH Desktop macOS** (`/Users/promac/Projects/dsh-desktop-macos`).

---

## 1. Peran & Nilai Inti (Lazy Senior Developer)
- **Kenyamanan & Stabilitas Host Nomor Satu:** Dilarang mematikan atau membunuh proses `DSHDesktop` / Node secara membabi-buta saat user sedang aktif menggunakannya untuk percakapan.
- **Shortest Working Diff:** Selesaikan masalah dengan kode paling ringkas dan tepat sasaran. Jangan menambahkan layer abstraksi atau boilerplate yang tidak diminta.
- **Fail Fast & Test Early:** Uji perubahan langsung melalui build script atau unit check (`./scripts/build-intel.sh` atau SPM check) sebelum melaporkan hasil.
- **Semua Respon Wajib Bahasa Indonesia:** Memenuhi aturan global `~/.dsh/AGENTS.md`.

---

## 2. Struktur Proyek & Tanggung Jawab Modul
- `Package.swift`: Multi-target SPM (Swift 6.0, macOS 13+).
  - Target `DSHDesktopCore`: Logika supervisor proses, port probe, auth signer, health checker, notification manager, plugin log store.
  - Target `DSHDesktopUI`: `WebViewController` (WKWebView container & JavaScript message handler bridge), `MainWindowController`, `MenuBarController`, `PluginLogWindowController`.
  - Target `DSHDesktop`: Executable utama (`main.swift`, `AppDelegate.swift`).
  - Target `DSHDesktopCheck`: Executable self-check / diagnostic.
- `Resources/`: `Info.plist`, `AppIcon.icns`.
- `scripts/`:
  - `build-intel.sh`: Build release untuk x86_64 Intel Mac ke `dist/DSHDesktop.app`.
  - `build-universal.sh`: Kompilasi Universal 2 (`lipo`) untuk Intel + Apple Silicon.
  - `package-dmg.sh`: Membungkus bundle ke file `.dmg`.

---

## 3. Aturan & Batasan Penting (Gotchas & Anti-Patterns)
1. **Jangan Bunuh Aplikasi yang Sedang Digunakan User:**
   - User menjalankan percakapan chat melalui `DSHDesktop` atau browser. `pkill` sembarangan akan memutuskan sesi secara kasar.
   - Jika butuh reload kode frontend/plugin, prioritaskan petunjuk refresh UI (`Cmd + R`) atau verifikasi terisolasi.
2. **WebKit Cache Awareness:**
   - WKWebView menyimpan disk cache di `~/Library/Caches/dev.dsh.desktop`.
   - `WebViewController.swift` telah dipasang kebijakan `.reloadIgnoringLocalCacheData` dan purge disk/memory cache pada `reloadPage()`. Jangan kembalikan ke `.useProtocolCachePolicy` polos.
3. **Pemisahan Host vs Plugin Runtime:**
   - DSH Desktop host berjalan pada `0.2.0-rc.2`.
   - Modul di `~/.dsh/profiles/node_modules/@deepseek-ai/*` mungkin merujuk ke symlink yang berbeda. Sadari perbedaan versi sebelum mendiagnosa error plugin pihak ketiga.
4. **Verifikasi Build:**
   - Selalu jalankan `./scripts/build-intel.sh` setelah memodifikasi file `.swift`. Pastikan status exit code 0 (`Build complete!`).

---

## 4. Siklus Memori (ICM & Agent Notes)
- Simpan keputusan teknis dan penyelesaian bug ke ICM (`icm --db /tmp/icm-mirror.db --no-embeddings store`).
- Selalu cantumkan blok `## Verdict` di akhir setiap respon.
