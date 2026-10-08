import Foundation
import Network

/// Probes local TCP port availability in a non-blocking asynchronous manner.
public struct PortProbe: Sendable {
    public enum ProbeResult: Sendable, Equatable {
        case open
        case closed
        case timeout
        case failed(String)
    }

    /// Checks if a local TCP port (`127.0.0.1` or `host`) is actively listening.
    /// - Parameters:
    ///   - port: TCP port number (e.g. 3080 or 43120)
    ///   - host: Destination host (default: "127.0.0.1")
    ///   - timeoutSeconds: Connection timeout in seconds (default: 0.8)
    /// - Returns: `ProbeResult`
    public static func probe(
        port: UInt16,
        host: String = "127.0.0.1",
        timeoutSeconds: Double = 0.8
    ) async -> ProbeResult {
        await withCheckedContinuation { continuation in
            let hostEndpoint = NWEndpoint.Host(host)
            guard let portEndpoint = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: .failed("Invalid port: \(port)"))
                return
            }

            let nwParams = NWParameters.tcp
            nwParams.serviceClass = .responsiveData
            let connection = NWConnection(host: hostEndpoint, port: portEndpoint, using: nwParams)
            let queue = DispatchQueue(label: "dev.dsh.portprobe.\(port)")

            final class ResumeGate: @unchecked Sendable {
                let lock = NSLock()
                var hasResumed = false
                let connection: NWConnection
                let continuation: CheckedContinuation<ProbeResult, Never>

                init(connection: NWConnection, continuation: CheckedContinuation<ProbeResult, Never>) {
                    self.connection = connection
                    self.continuation = continuation
                }

                func resume(_ result: ProbeResult) {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        connection.cancel()
                        continuation.resume(returning: result)
                    }
                }
            }

            let gate = ResumeGate(connection: connection, continuation: continuation)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    gate.resume(.open)
                case .failed:
                    gate.resume(.closed)
                case .cancelled:
                    break
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeoutSeconds) {
                gate.resume(.timeout)
            }
        }
    }

    /// Periodically polls until the port is open or maximum attempts are reached.
    /// - Parameters:
    ///   - port: Target TCP port number
    ///   - host: Target host (default 127.0.0.1)
    ///   - maxAttempts: Total check attempts
    ///   - intervalSeconds: Delay between attempts in seconds
    /// - Returns: `true` if port opened before limit, `false` otherwise.
    public static func waitForPort(
        port: UInt16,
        host: String = "127.0.0.1",
        maxAttempts: Int = 15,
        intervalSeconds: Double = 0.5
    ) async -> Bool {
        for _ in 0..<maxAttempts {
            let result = await probe(port: port, host: host, timeoutSeconds: intervalSeconds)
            if result == .open {
                return true
            }
            try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
        }
        return false
    }
}
