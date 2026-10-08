import Foundation

/// Supervises the lifecycle of the `dsh web` backend process (start, status monitoring, clean SIGTERM shutdown).
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

    /// Starts child process `dsh web` if server is not already active.
    /// - Parameters:
    ///   - dshBinary: URL path to the `dsh` executable binary
    ///   - port: Target port (default 3080)
    /// - Returns: Process state after initiation
    public func start(dshBinary: URL, port: UInt16 = 3080) async -> State {
        guard case .stopped = state else {
            return state
        }

        // ponytail: check if port is already open externally; if so, skip spawning a new process.
        let isAlreadyOpen = await PortProbe.probe(port: port, timeoutSeconds: 0.5) == .open
        if isAlreadyOpen {
            state = .running(pid: -1) // -1 denotes pre-existing external instance
            return state
        }

        self.state = .starting
        let proc = Process()
        proc.executableURL = dshBinary
        proc.arguments = ["web", "--port", String(port), "--no-open"]

        // Setup pipe for stdout/stderr to avoid terminal buffer blocking
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
            let msg = "Failed to launch dsh web: \(error.localizedDescription)"
            self.state = .failed(msg)
            return state
        }
    }

    private func handleTermination(status: Int32) {
        self.process = nil
        self.state = .stopped
    }

    /// Stops child process gracefully via SIGTERM.
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
