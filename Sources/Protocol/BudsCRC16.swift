// BudsCRC16.swift
// CRC16-CCITT checksum used by Samsung Galaxy Buds SPP protocol.
//
// The CRC is computed over: [messageId] + [payload bytes].
// The polynomial is x^16 + x^12 + x^5 + 1 (0x1021), init value 0xFFFF.
//
// Reference: https://gist.github.com/ThePBone/435b625418945592d7a0a3f04adc67b0

import Foundation

/// CRC16-CCITT calculator for Galaxy Buds protocol packets.
enum BudsCRC16 {

    /// CRC lookup table (polynomial 0x1021, no reflection).
    private static let table: [UInt16] = {
        var t = [UInt16](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt16(i) << 8
            for _ in 0..<8 {
                if crc & 0x8000 != 0 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc <<= 1
                }
            }
            t[i] = crc
        }
        return t
    }()

    /// Compute CRC16-CCITT over the given data.
    /// - Parameter data: Raw bytes to checksum.
    /// - Returns: 16-bit CRC value.
    static func compute(_ data: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in data {
            let idx = Int((crc >> 8) ^ UInt16(byte))
            crc = (crc << 8) ^ table[idx & 0xFF]
        }
        return crc
    }

    /// Compute CRC16-CCITT for a message (message ID + payload).
    /// - Parameters:
    ///   - messageId: The 1-byte message ID.
    ///   - payload: The payload bytes.
    /// - Returns: CRC16 value.
    static func compute(messageId: BudsMessageId, payload: [UInt8]) -> UInt16 {
        var data = [messageId.rawValue]
        data.append(contentsOf: payload)
        return compute(data)
    }

    /// Verify CRC of a received packet.
    /// - Parameters:
    ///   - messageId: The message ID.
    ///   - payload: The payload bytes.
    ///   - receivedCRC: The CRC bytes from the packet (little-endian).
    /// - Returns: True if CRC matches.
    static func verify(messageId: BudsMessageId, payload: [UInt8], receivedCRC: [UInt8]) -> Bool {
        guard receivedCRC.count == 2 else { return false }
        let expected = compute(messageId: messageId, payload: payload)
        let received = UInt16(receivedCRC[0]) | (UInt16(receivedCRC[1]) << 8)
        return expected == received
    }

    /// Encode CRC16 value as 2 bytes (little-endian).
    static func encode(_ crc: UInt16) -> [UInt8] {
        return [UInt8(crc & 0xFF), UInt8((crc >> 8) & 0xFF)]
    }
}
