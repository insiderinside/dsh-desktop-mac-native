import Foundation

/// Runtime configuration for the DSHDesktop application.
public struct AppConfig: Sendable {
    public let defaultPort: UInt16
    public let host: String
    public let webURL: URL
    public let autoLaunchBackend: Bool

    public init(
        defaultPort: UInt16 = 3080,
        host: String = "127.0.0.1",
        autoLaunchBackend: Bool = true
    ) {
        self.defaultPort = defaultPort
        self.host = host
        self.autoLaunchBackend = autoLaunchBackend
        self.webURL = URL(string: "http://\(host):\(defaultPort)")!
    }
}
