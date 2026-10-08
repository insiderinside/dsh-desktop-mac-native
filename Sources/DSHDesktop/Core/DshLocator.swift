import Foundation

/// Locates the `dsh` executable binary on macOS.
public struct DshLocator: Sendable {
    /// Priority search directory paths for the `dsh` binary
    public static let standardSearchPaths: [String] = {
        let home = NSHomeDirectory()
        return [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.cargo/bin",
            "\(home)/.nvm/current/bin",
            "/usr/bin",
            "/bin"
        ]
    }()

    /// Locates the `dsh` executable based on standard search paths and environment PATH.
    /// - Parameter fileManager: FileManager instance (default: .default)
    /// - Parameter envPath: Optional PATH string value (default: reads ProcessInfo.processInfo.environment["PATH"])
    /// - Returns: Absolute URL path to the `dsh` executable if found, or `nil`.
    public static func locate(
        fileManager: FileManager = .default,
        envPath: String? = ProcessInfo.processInfo.environment["PATH"]
    ) -> URL? {
        var candidatePaths = standardSearchPaths

        if let envPath = envPath {
            let splitPaths = envPath.split(separator: ":").map(String.init)
            for path in splitPaths where !candidatePaths.contains(path) {
                candidatePaths.append(path)
            }
        }

        // ponytail: static directory list check covers 99% of Homebrew, local pip/cargo, and default shell setups.
        for dir in candidatePaths {
            let fullPath = (dir as NSString).appendingPathComponent("dsh")
            if fileManager.isExecutableFile(atPath: fullPath) {
                return URL(fileURLWithPath: fullPath)
            }
        }

        return nil
    }
}
