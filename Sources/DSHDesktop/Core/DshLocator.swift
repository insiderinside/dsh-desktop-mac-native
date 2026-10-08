import Foundation

/// Mendeteksi lokasi binary executable `dsh` pada macOS.
public struct DshLocator: Sendable {
    /// Urutan direktori prioritas pencarian binary `dsh`
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

    /// Mencari executable `dsh` berdasarkan urutan path standar dan environment PATH.
    /// - Parameter fileManager: FileManager instance (default: .default)
    /// - Parameter envPath: Nilai PATH string opsional (default: membaca ProcessInfo.processInfo.environment["PATH"])
    /// - Returns: URL path absolut ke file executable `dsh` jika ditemukan, atau `nil`.
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

        // ponytail: pencarian statis list direktori sudah mencakup 99% instalasi homebrew, local pip/cargo, dan shell default.
        for dir in candidatePaths {
            let fullPath = (dir as NSString).appendingPathComponent("dsh")
            if fileManager.isExecutableFile(atPath: fullPath) {
                return URL(fileURLWithPath: fullPath)
            }
        }

        return nil
    }
}
