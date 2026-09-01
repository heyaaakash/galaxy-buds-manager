// DataExtensions.swift
// Utility extensions for byte array and data manipulation.

import Foundation

extension Array where Element == UInt8 {

    /// Convert bytes to hex string.
    func toHexString(separator: String = " ") -> String {
        return map { String(format: "%02X", $0) }.joined(separator: separator)
    }

    /// Read a big-endian UInt16 at the given offset.
    func readUInt16BE(at offset: Int) -> UInt16? {
        guard offset + 1 < count else { return nil }
        return UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
    }

    /// Read a big-endian UInt32 at the given offset.
    func readUInt32BE(at offset: Int) -> UInt32? {
        guard offset + 3 < count else { return nil }
        return UInt32(self[offset]) << 24 |
               UInt32(self[offset + 1]) << 16 |
               UInt32(self[offset + 2]) << 8 |
               UInt32(self[offset + 3])
    }

    /// Read a big-endian Int64 at the given offset.
    func readInt64BE(at offset: Int) -> Int64? {
        guard offset + 7 < count else { return nil }
        var value: Int64 = 0
        for i in 0..<8 {
            value = (value << 8) | Int64(self[offset + i])
        }
        return value
    }

    /// Read a little-endian UInt16 at the given offset.
    func readUInt16LE(at offset: Int) -> UInt16? {
        guard offset + 1 < count else { return nil }
        return UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    /// Read a null-terminated string starting at the given offset.
    func readNullTerminatedString(at offset: Int) -> String? {
        guard offset < count else { return nil }
        var bytes = [UInt8]()
        for i in offset..<count {
            if self[i] == 0 { break }
            bytes.append(self[i])
        }
        return String(bytes: bytes, encoding: .utf8)
    }

    /// Subarray from offset to end.
    func subarray(from offset: Int) -> [UInt8] {
        guard offset < count else { return [] }
        return Array(self[offset...])
    }
}

extension Data {

    /// Convert to hex string.
    func toHexString(separator: String = " ") -> String {
        return [UInt8](self).toHexString(separator: separator)
    }
}

extension String {

    /// Pad string to a given length with a pad character.
    func padLeft(toLength length: Int, withPad pad: Character = " ", startingAt start: Int = 0) -> String {
        let padLength = length - self.count
        if padLength <= 0 { return self }
        return String(repeating: String(pad), count: padLength) + self
    }
}

// TimeInterval extensions are not needed — use TimeZone.current.secondsFrom(for:) directly.
