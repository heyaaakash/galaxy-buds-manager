// BudsMessageTypes.swift
// Message type and constants for Samsung Galaxy Buds SPP protocol

import Foundation

// MARK: - Message Constants

/// Protocol framing constants for Samsung Galaxy Buds SPP messages.
enum BudsConstants {
    /// Start of Message byte (standard, non-legacy).
    static let som: UInt8 = 0xFD

    /// End of Message byte (standard, non-legacy).
    static let eom: UInt8 = 0xDD

    /// Start of Message byte (legacy Buds 2019).
    static let legacySom: UInt8 = 0xFE

    /// End of Message byte (legacy Buds 2019).
    static let legacyEom: UInt8 = 0xEE

    /// Alternative mode (SMEP) SOM.
    static let smepSom: UInt8 = 0xFC

    /// Alternative mode (SMEP) EOM.
    static let smepEom: UInt8 = 0xCC

    /// Size of the header field (2 bytes).
    static let headerSize = 2

    /// Size of the CRC field (2 bytes).
    static let crcSize = 2

    /// Minimum packet size: SOM(1) + Header(2) + MsgId(1) + CRC(2) + EOM(1) = 7.
    static let minimumPacketSize = 7

    /// Standard SPP service UUID used by Buds+, Buds Live, and Buds Pro.
    static let sppUuid = "00001101-0000-1000-8000-00805F9B34FB"

    /// Buds2 Pro configuration service, advertised through classic Bluetooth SDP.
    static let sppNewUuid = "2E73A4AD-332D-41FC-90E2-16BEF06523F2"

    /// Maximum payload size for non-fragmented messages.
    static let maxPayloadSize = 256

    /// Default command timeout in seconds.
    static let commandTimeout: TimeInterval = 5.0

    /// Retry count for failed commands.
    static let maxRetries = 2
}

// MARK: - Message Types

/// Direction of a message: request from client or response from device.
enum BudsMessageType: UInt8, CustomStringConvertible {
    case request  = 0
    case response = 1

    var description: String {
        switch self {
        case .request:  return "Request"
        case .response: return "Response"
        }
    }
}

// MARK: - Header Bit Layout

/// Parses and constructs the 2-byte SPP message header.
///
/// Bit layout (big-endian):
/// ```
/// Byte 0: [payloadSizeLow8]
/// Byte 1: [isResponse:1][isFragment:1][payloadSizeHigh3:3][unused:3]
/// ```
/// The total payload size is an 11-bit value: `(header[1] & 0x07) << 8 | header[0]`.
struct BudsMessageHeader {
    /// Payload size (11 bits, max 2047).
    var payloadSize: Int

    /// Whether this message is a response.
    var isResponse: Bool

    /// Whether this is a fragmented message.
    var isFragment: Bool

    /// Encode header to 2 bytes.
    func encode() -> [UInt8] {
        let size = min(payloadSize, 0x7FF) // clamp to 11 bits
        let byte0 = UInt8(size & 0xFF)
        var byte1 = UInt8((size >> 8) & 0x07)

        if isResponse {
            byte1 |= 0x10
        }
        if isFragment {
            byte1 |= 0x20
        }

        return [byte0, byte1]
    }

    /// Decode header from 2 bytes.
    static func decode(_ bytes: [UInt8]) -> BudsMessageHeader? {
        guard bytes.count >= 2 else { return nil }
        let low = Int(bytes[0])
        let high = Int(bytes[1])
        let payloadSize = low | ((high & 0x07) << 8)
        let isResponse = (high & 0x10) != 0
        let isFragment = (high & 0x20) != 0

        return BudsMessageHeader(
            payloadSize: payloadSize,
            isResponse: isResponse,
            isFragment: isFragment
        )
    }
}
