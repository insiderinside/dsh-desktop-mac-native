import Foundation
import DSHDesktopCore

@main
struct CheckRunner {
    static func main() async {
        print("[CHECK] Starting DSHDesktopCore self-check...")

        // 1. DshLocator Check
        print("[CHECK] 1. Testing DshLocator...")
        let found = DshLocator.locate()
        assert(found != nil, "DshLocator failed to find dsh binary!")
        if let found = found {
            print("  -> Found dsh at: \(found.path)")
            assert(found.lastPathComponent == "dsh", "Binary filename is not 'dsh'")
        }

        // Custom path test
        let customFound = DshLocator.locate(envPath: "/dummy/path:/nonexistent")
        assert(customFound != nil, "DshLocator should still find binary from standardSearchPaths")

        // 2. PortProbe Check (Closed port)
        print("[CHECK] 2. Testing PortProbe on closed port (59123)...")
        let closedRes = await PortProbe.probe(port: 59123, timeoutSeconds: 0.3)
        assert(closedRes == .closed || closedRes == .timeout, "Closed port should return .closed or .timeout, got: \(closedRes)")
        print("  -> Closed port test passed: \(closedRes)")

        // 3. PortProbe Check (Active port 3080 if server is running, or fallback gracefully)
        print("[CHECK] 3. Testing PortProbe on port 3080...")
        let portRes = await PortProbe.probe(port: 3080, timeoutSeconds: 1.0)
        print("  -> Port 3080 probe result: \(portRes)")

        // 4. PortProbe.waitForPort Check
        print("[CHECK] 4. Testing PortProbe.waitForPort...")
        if portRes == .open {
            let waitSuccess = await PortProbe.waitForPort(port: 3080, maxAttempts: 3, intervalSeconds: 0.2)
            assert(waitSuccess, "waitForPort should return true for open port 3080")
            print("  -> waitForPort passed: true")
        } else {
            let waitFail = await PortProbe.waitForPort(port: 59123, maxAttempts: 2, intervalSeconds: 0.1)
            assert(!waitFail, "waitForPort on closed port should return false")
            print("  -> waitForPort closed test passed: false")
        }

        // 5. AppConfig Check
        print("[CHECK] 5. Testing AppConfig...")
        let config = AppConfig(defaultPort: 3080)
        assert(config.webURL.absoluteString == "http://127.0.0.1:3080", "AppConfig URL mismatch")
        print("  -> AppConfig test passed: \(config.webURL)")

        // 6. DshProcessSupervisor Check
        print("[CHECK] 6. Testing DshProcessSupervisor...")
        let supervisor = DshProcessSupervisor()
        let initState = await supervisor.state
        assert(initState == .stopped, "Initial state should be .stopped")
        if let binary = found {
            if portRes == .open {
                // If port 3080 is already active, supervisor detects pre-existing instance
                let runningState = await supervisor.start(dshBinary: binary, port: 3080)
                assert(runningState == .running(pid: -1), "Supervisor should detect pre-existing server")
                print("  -> Supervisor detected pre-existing server: \(runningState)")
            }
            await supervisor.stop()
            let stoppedState = await supervisor.state
            assert(stoppedState == .stopped, "Supervisor stop should return .stopped state")
            print("  -> Supervisor stop test passed: \(stoppedState)")
        }

        // 7. PluginLogStore Testing (Logging & JS Error Interception)
        print("[CHECK] 7. Testing PluginLogStore & JavaScript Error Interception...")
        await MainActor.run {
            PluginLogStore.shared.clear()
            assert(PluginLogStore.shared.entries.isEmpty, "PluginLogStore should be empty after clear()")

            // Simulate capturing plugin error
            PluginLogStore.shared.add(
                level: .error,
                message: "TypeError: Cannot read properties of undefined (reading 'register')",
                source: "dsh-sample-plugin/lib/index.js",
                line: 42,
                column: 15
            )

            // Simulate console.warn from JavaScript
            PluginLogStore.shared.add(
                level: .warn,
                message: "Warning: Missing required configuration 'apiKey'",
                source: "console.warn",
                line: nil,
                column: nil
            )

            assert(PluginLogStore.shared.entries.count == 2, "Log count should be 2")
            let first = PluginLogStore.shared.entries[0]
            assert(first.level == .error, "First level should be ERROR")
            assert(first.source == "dsh-sample-plugin/lib/index.js", "Source mismatch")
            assert(first.line == 42, "Line should be 42")
            assert(first.formatted.contains("[ERROR] [dsh-sample-plugin/lib/index.js:42:15]"), "Log format string mismatch")
            print("  -> PluginLogStore testing passed: \(first.formatted)")
        }

        print("[CHECK] ALL SELF-CHECKS PASSED 100%!")
    }
}
