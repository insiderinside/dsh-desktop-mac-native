import Foundation
import DSHDesktopCore

@main
struct CheckRunner {
    static func main() async {
        print("[CHECK] Memulai self-check DSHDesktopCore...")

        // 1. DshLocator Check
        print("[CHECK] 1. Menguji DshLocator...")
        let found = DshLocator.locate()
        assert(found != nil, "DshLocator gagal menemukan binary dsh!")
        if let found = found {
            print("  -> Ditemukan dsh di: \(found.path)")
            assert(found.lastPathComponent == "dsh", "Nama file binary bukan 'dsh'")
        }

        // Custom path test
        let customFound = DshLocator.locate(envPath: "/dummy/path:/nonexistent")
        assert(customFound != nil, "DshLocator seharusnya tetap menemukan dari standardSearchPaths")

        // 2. PortProbe Check (Closed port)
        print("[CHECK] 2. Menguji PortProbe pada closed port (59123)...")
        let closedRes = await PortProbe.probe(port: 59123, timeoutSeconds: 0.3)
        assert(closedRes == .closed || closedRes == .timeout, "Closed port seharusnya .closed atau .timeout, dapat: \(closedRes)")
        print("  -> Closed port test lulus: \(closedRes)")

        // 3. PortProbe Check (Active port 3080 jika server aktif, atau fallback gracefully)
        print("[CHECK] 3. Menguji PortProbe pada port 3080...")
        let portRes = await PortProbe.probe(port: 3080, timeoutSeconds: 1.0)
        print("  -> Port 3080 probe result: \(portRes)")

        // 4. PortProbe.waitForPort Check
        print("[CHECK] 4. Menguji PortProbe.waitForPort...")
        if portRes == .open {
            let waitSuccess = await PortProbe.waitForPort(port: 3080, maxAttempts: 3, intervalSeconds: 0.2)
            assert(waitSuccess, "waitForPort seharusnya mengembalikan true untuk port 3080")
            print("  -> waitForPort lulus: true")
        } else {
            let waitFail = await PortProbe.waitForPort(port: 59123, maxAttempts: 2, intervalSeconds: 0.1)
            assert(!waitFail, "waitForPort pada port tertutup seharusnya false")
            print("  -> waitForPort closed test lulus: false")
        }

        // 5. AppConfig Check
        print("[CHECK] 5. Menguji AppConfig...")
        let config = AppConfig(defaultPort: 3080)
        assert(config.webURL.absoluteString == "http://127.0.0.1:3080", "URL AppConfig tidak sesuai")
        print("  -> AppConfig test lulus: \(config.webURL)")

        // 6. DshProcessSupervisor Check
        print("[CHECK] 6. Menguji DshProcessSupervisor...")
        let supervisor = DshProcessSupervisor()
        let initState = await supervisor.state
        assert(initState == .stopped, "State awal harusnya .stopped")
        if let binary = found {
            if portRes == .open {
                // Jika port 3080 sudah aktif, supervisor mendeteksi instance eksternal
                let runningState = await supervisor.start(dshBinary: binary, port: 3080)
                assert(runningState == .running(pid: -1), "Supervisor harus mendeteksi server yang sudah aktif")
                print("  -> Supervisor mendeteksi server yang sudah aktif: \(runningState)")
            }
            await supervisor.stop()
            let stoppedState = await supervisor.state
            assert(stoppedState == .stopped, "Supervisor stop harus mengembalikan state .stopped")
            print("  -> Supervisor stop test lulus: \(stoppedState)")
        }

        // 7. PluginLogStore Testing (Verifikasi Logging & JS Error Interception)
        print("[CHECK] 7. Menguji PluginLogStore & JavaScript Error Interception...")
        await MainActor.run {
            PluginLogStore.shared.clear()
            assert(PluginLogStore.shared.entries.isEmpty, "PluginLogStore harus kosong setelah clear()")

            // Simulasi penangkapan error dari plugin
            PluginLogStore.shared.add(
                level: .error,
                message: "TypeError: Cannot read properties of undefined (reading 'register')",
                source: "dsh-sample-plugin/lib/index.js",
                line: 42,
                column: 15
            )

            // Simulasi console.warn dari JavaScript
            PluginLogStore.shared.add(
                level: .warn,
                message: "Warning: Missing required configuration 'apiKey'",
                source: "console.warn",
                line: nil,
                column: nil
            )

            assert(PluginLogStore.shared.entries.count == 2, "Jumlah log harus 2")
            let first = PluginLogStore.shared.entries[0]
            assert(first.level == .error, "Level pertama harus ERROR")
            assert(first.source == "dsh-sample-plugin/lib/index.js", "Source harus sesuai")
            assert(first.line == 42, "Line harus 42")
            assert(first.formatted.contains("[ERROR] [dsh-sample-plugin/lib/index.js:42:15]"), "Format string log harus benar")
            print("  -> PluginLogStore testing lulus: \(first.formatted)")
        }

        print("[CHECK] SEMUA SELF-CHECK BERHASIL LOLOS 100%!")
    }
}
