import Foundation

/// Data model representing a single plugin or JavaScript log entry
public struct PluginLogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    public let source: String
    public let line: Int?
    public let column: Int?

    public enum LogLevel: String, Sendable {
        case error = "ERROR"
        case warn = "WARN"
        case info = "INFO"
    }

    public init(timestamp: Date = Date(), level: LogLevel, message: String, source: String, line: Int? = nil, column: Int? = nil) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.source = source
        self.line = line
        self.column = column
    }

    public var formatted: String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        let timeStr = df.string(from: timestamp)
        var loc = source
        if let line = line {
            loc += ":\(line)"
            if let col = column {
                loc += ":\(col)"
            }
        }
        return "[\(timeStr)] [\(level.rawValue)] [\(loc)] \(message)"
    }
}

/// Centralized logger for intercepting WebKit and plugin errors/warnings
@MainActor
public final class PluginLogStore {
    public static let shared = PluginLogStore()

    public private(set) var entries: [PluginLogEntry] = []
    public var onNewEntry: ((PluginLogEntry) -> Void)?

    private init() {}

    public func add(level: PluginLogEntry.LogLevel, message: String, source: String, line: Int? = nil, column: Int? = nil) {
        let entry = PluginLogEntry(level: level, message: message, source: source, line: line, column: column)
        entries.append(entry)
        if entries.count > 1000 {
            entries.removeFirst(entries.count - 1000)
        }
        print("[PLUGIN-LOG] \(entry.formatted)")
        onNewEntry?(entry)
    }

    public func clear() {
        entries.removeAll()
    }
}
