import Foundation
import Network

/// Mengecek status ketersediaan port TCP lokal secara non-blocking / async.
public struct PortProbe: Sendable {
    public enum ProbeResult: Sendable, Equatable {
        case open
        case closed
        case timeout
        case failed(String)
    }

    /// Mengecek apakah port TCP lokal (`127.0.0.1` atau `host`) sedang listening.
    /// - Parameters:
    ///   - port: Nomor port TCP (misal 3080 atau 43120)
    ///   - host: Host tujuan (default: "127.0.0.1")
    ///   - timeoutSeconds: Batas waktu koneksi dalam detik (default: 0.8)
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

    /// Polling berkala hingga port terbuka atau batas total percobaan tercapai.
    /// - Parameters:
    ///   - port: Nomor port TCP target
    ///   - host: Target host (default 127.0.0.1)
    ///   - maxAttempts: Total iterasi pengecekan
    ///   - intervalSeconds: Jeda antar percobaan dalam detik
    /// - Returns: `true` jika port terbuka sebelum batas percobaan, `false` jika tidak.
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
