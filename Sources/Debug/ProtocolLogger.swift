// ProtocolLogger.swift
// Protocol traffic logger for debugging Samsung Galaxy Buds SPP communication.
// Logs all sent/received messages with hex dumps, timestamps, and structured output.
// Supports replay of captured sessions.

import Foundation
import AppKit

// MARK: - Log Levels

/// Protocol log severity levels.
enum LogLevel: String, CaseIterable, Sendable {
    case verbose  = "VRB"
    case info     = "INF"
    case outgoing = ">>>"
    case incoming = "<<<"
    case warning  = "WRN"
    case error    = "ERR"
}

// MARK: - Log Entry

/// A single protocol log entry.
struct ProtocolLogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let direction: LogDirection
    let messageId: BudsMessageId?
    let rawBytes: [UInt8]?
    let message: String

    enum LogDirection: String, Sendable {
        case none    = "   "
        case sent    = "TX "
        case recv    = "RX "
    }

    /// Formatted timestamp string.
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    /// Hex dump of raw bytes if available.
    var hexDump: String? {
        guard let bytes = rawBytes, !bytes.isEmpty else { return nil }
        return Self.formatHex(bytes)
    }

    /// Format bytes as hex string with grouping.
    static func formatHex(_ bytes: [UInt8], maxBytes: Int = 64) -> String {
        let display = bytes.prefix(maxBytes)
        let hexParts = display.map { String(format: "%02X", $0) }
        let grouped = stride(from: 0, to: hexParts.count, by: 8).map { start in
            let end = min(start + 8, hexParts.count)
            return hexParts[start..<end].joined(separator: " ")
        }
        var result = grouped.joined(separator: "\n        ")
        if bytes.count > maxBytes {
            result += " ... (\(bytes.count) total bytes)"
        }
        return result
    }
}

// MARK: - Protocol Logger

/// Global protocol logger. Stores all entries in memory for the session
/// and supports export for debugging and replay.
actor ProtocolLogger {
    /// Maximum entries to keep in memory.
    static let maxEntries = 5000

    /// In-memory log buffer.
    private static var entries: [ProtocolLogEntry] = []

    /// Whether logging is enabled.
    static var isEnabled: Bool = true

    /// Callback for real-time log streaming (used by debug UI).
    static var onEntry: ((ProtocolLogEntry) -> Void)?

    // MARK: - Logging

    /// Log a protocol event.
    static func log(
        _ level: LogLevel,
        _ message: String,
        direction: ProtocolLogEntry.LogDirection = .none,
        messageId: BudsMessageId? = nil,
        rawBytes: [UInt8]? = nil
    ) {
        guard isEnabled else { return }

        let entry = ProtocolLogEntry(
            timestamp: Date(),
            level: level,
            direction: direction,
            messageId: messageId,
            rawBytes: rawBytes,
            message: message
        )

        entries.append(entry)

        // Trim if over limit
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        // Console output
        let dir = direction.rawValue
        let hexInfo = entry.hexDump.map { " \($0)" } ?? ""
        print("[\(entry.timestampString)] \(dir) [\(level.rawValue)] \(message)\(hexInfo)")

        // Notify observers
        onEntry?(entry)
    }

    /// Log an outgoing message.
    static func logOutgoing(_ message: BudsMessage) {
        let raw = message.encode()
        log(.outgoing, "\(message.id) (\(message.payload.count) bytes)",
            direction: .sent, messageId: message.id, rawBytes: raw)
    }

    /// Log an incoming message.
    static func logIncoming(_ message: BudsMessage, rawBytes: [UInt8]? = nil) {
        log(.incoming, "\(message.id) (\(message.payload.count) bytes)",
            direction: .recv, messageId: message.id, rawBytes: rawBytes)
    }

    // MARK: - Retrieval

    /// Get all logged entries.
    static func getAllEntries() -> [ProtocolLogEntry] {
        return entries
    }

    /// Get entries for a specific message ID.
    static func getEntries(for messageId: BudsMessageId) -> [ProtocolLogEntry] {
        return entries.filter { $0.messageId == messageId }
    }

    /// Get entries in a time range.
    static func getEntries(from start: Date, to end: Date) -> [ProtocolLogEntry] {
        return entries.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    /// Get recent entries (last N).
    static func getRecentEntries(count: Int = 100) -> [ProtocolLogEntry] {
        return Array(entries.suffix(count))
    }

    // MARK: - Export

    /// Export log as human-readable text.
    static func exportText() -> String {
        var output: [String] = []
        output.append("=== Galaxy Buds Protocol Log ===")
        output.append("Session: \(ISO8601DateFormatter().string(from: Date()))")
        output.append("Total entries: \(entries.count)")
        output.append("")

        for entry in entries {
            let dir = entry.direction.rawValue
            var line = "[\(entry.timestampString)] \(dir) [\(entry.level.rawValue)] \(entry.message)"
            if let hex = entry.hexDump {
                line += "\n        \(hex)"
            }
            output.append(line)
        }

        return output.joined(separator: "\n")
    }

    /// Export log as JSON array for programmatic replay.
    static func exportJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonEntries: [[String: Any]] = entries.map { entry in
            var dict: [String: Any] = [
                "timestamp": entry.timestamp,
                "level": entry.level.rawValue,
                "direction": entry.direction.rawValue,
                "message": entry.message
            ]
            if let msgId = entry.messageId {
                dict["messageId"] = Int(msgId.rawValue)
            }
            if let raw = entry.rawBytes {
                dict["rawBytes"] = raw
            }
            return dict
        }
        return try? JSONSerialization.data(withJSONObject: jsonEntries, options: .prettyPrinted)
    }

    // MARK: - Replay

    /// Replay a sequence of messages from a log export.
    /// Returns the raw byte sequences in order for feeding back into the protocol layer.
    static func loadReplayData(from jsonData: Data) -> [[UInt8]]? {
        guard let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return nil
        }

        return array.compactMap { $0["rawBytes"] as? [UInt8] }
    }

    /// Clear all log entries.
    static func clear() {
        entries.removeAll()
    }

    // MARK: - Log Folder

    /// Path to the logs directory.
    static var logDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("GalaxyBudsManager/logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Set up the log directory on disk.
    static func setupLogDirectory() {
        _ = logDirectory
    }

    /// Open the log folder in Finder.
    static func openLogFolder() {
        NSWorkspace.shared.open(logDirectory)
    }
}
