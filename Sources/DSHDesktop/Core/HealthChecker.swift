import Foundation

/// Helper to ensure the local HTTP server responds with 200 OK
/// and WebSocket endpoints are ready before the UI is rendered.
public struct HealthChecker: Sendable {
    /// Polls HTTP GET requests until status code 200 OK is returned
    /// and internal routes stabilize, or timeout is reached.
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
                    // Stabilization grace period: 1 second for WebSocket engine to accept client connections
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    return true
                }
            } catch {
                // Server not ready yet or connection refused
            }

            try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
        }
        return false
    }
}
