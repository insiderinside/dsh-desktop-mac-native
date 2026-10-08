import Foundation

/// Helper untuk memastikan server HTTP lokal benar-benar merespons 200 OK
/// dan endpoint WebSocket / Remote siap sebelum UI dibuka.
public struct HealthChecker: Sendable {
    /// Melakukan polling HTTP GET request hingga status code 200 OK diterima
    /// dan rute internal stabil atau batas waktu tercapai.
    public static func waitForHealthy(
        url: URL,
        cookieHeader: String? = nil,
        maxAttempts: Int = 30,
        intervalSeconds: Double = 0.5
    ) async -> Bool {
        for _ in 0..<maxAttempts {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 2.0
            if let cookieHeader = cookieHeader {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                    // Beri jeda stabilisasi (grace period) 1 detik agar engine WebSocket Node.js siap menerima koneksi client
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    return true
                }
            } catch {
                // Server belum siap atau connection refused
            }

            try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
        }
        return false
    }
}
