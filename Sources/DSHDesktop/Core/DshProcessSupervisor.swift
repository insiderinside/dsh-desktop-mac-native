import Foundation

/// Mengelola lifecycle proses backend `dsh web` (start, status monitor, clean SIGTERM shutdown).
public actor DshProcessSupervisor {
    public enum State: Sendable, Equatable {
        case stopped
        case starting
        case running(pid: Int32)
        case failed(String)
    }

    private var process: Process?
    private(set) public var state: State = .stopped

    public init() {}

    /// Memulai child process `dsh web` jika server belum aktif.
    /// - Parameters:
    ///   - dshBinary: URL path ke executable binary `dsh`
    ///   - port: Port target (default 3080)
    /// - Returns: State proses setelah inisiasi
    public func start(dshBinary: URL, port: UInt16 = 3080) async -> State {
        guard case .stopped = state else {
            return state
        }

        // ponytail: Cek apakah port sudah aktif di luar; jika ya, tidak perlu spawn process baru.
        let isAlreadyOpen = await PortProbe.probe(port: port, timeoutSeconds: 0.5) == .open
        if isAlreadyOpen {
            state = .running(pid: -1) // -1 menandakan instance eksternal yang sudah running
            return state
        }

        self.state = .starting
        let proc = Process()
        proc.executableURL = dshBinary
        proc.arguments = ["web", "--port", String(port), "--no-open"]

        // Setup pipe untuk stderr/stdout agar tidak blocking buffer terminal
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
            let pid = proc.processIdentifier
            self.process = proc
            self.state = .running(pid: pid)

            proc.terminationHandler = { [weak self] p in
                Task { [weak self] in
                    await self?.handleTermination(status: p.terminationStatus)
                }
            }

            return state
        } catch {
            let msg = "Gagal menjalankan dsh web: \(error.localizedDescription)"
            self.state = .failed(msg)
            return state
        }
    }

    private func handleTermination(status: Int32) {
        self.process = nil
        self.state = .stopped
    }

    /// Menghentikan child process menggunakan SIGTERM secara bersih.
    public func stop() {
        guard let proc = process, proc.isRunning else {
            state = .stopped
            process = nil
            return
        }

        proc.terminate() // SIGTERM
        proc.waitUntilExit()
        process = nil
        state = .stopped
    }
}
