// BudsMessage.swift
// Core message type for Samsung Galaxy Buds SPP protocol.
// Handles encoding/decoding of the binary packet format.

import Foundation

// MARK: - BudsMessage

/// Represents a single Samsung Galaxy Buds SPP message.
/// Handles encoding to wire format and decoding from raw bytes.
struct BudsMessage: CustomStringConvertible, Sendable {
    /// The message ID.
    let id: BudsMessageId

    /// Request or Response.
    let type: BudsMessageType

    /// Payload bytes.
    let payload: [UInt8]

    /// Whether this is a fragment (rarely used outside FOTA).
    let isFragment: Bool

    /// Timestamp when this message was created or received.
    let timestamp: Date

    /// Computed payload size for the header (3 = msgId + crc2).
    var headerPayloadSize: Int {
        return 1 + payload.count + BudsConstants.crcSize
    }

    /// Total packet size including SOM, header, msgId, payload, CRC, EOM.
    var totalPacketSize: Int {
        return 1 + BudsConstants.headerSize + headerPayloadSize + 1
    }

    /// Computed CRC16 over (messageId + payload).
    var crc16: UInt16 {
        return BudsCRC16.compute(messageId: id, payload: payload)
    }

    // MARK: - Initialization

    init(
        id: BudsMessageId,
        type: BudsMessageType = .request,
        payload: [UInt8] = [],
        isFragment: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.payload = payload
        self.isFragment = isFragment
        self.timestamp = timestamp
    }

    // MARK: - Encoding

    /// Encode this message to wire format bytes.
    func encode() -> [UInt8] {
        var packet: [UInt8] = []

        // SOM
        packet.append(BudsConstants.som)

        // Header (2 bytes)
        let header = BudsMessageHeader(
            payloadSize: headerPayloadSize,
            isResponse: type == .response,
            isFragment: isFragment
        )
        packet.append(contentsOf: header.encode())

        // Message ID
        packet.append(id.rawValue)

        // Payload
        packet.append(contentsOf: payload)

        // CRC16 (little-endian)
        packet.append(contentsOf: BudsCRC16.encode(crc16))

        // EOM
        packet.append(BudsConstants.eom)

        return packet
    }

    // MARK: - Decoding

    static func isValidSom(_ byte: UInt8) -> Bool {
        return byte == BudsConstants.som || byte == BudsConstants.legacySom || byte == BudsConstants.smepSom
    }

    static func matchingEom(for som: UInt8) -> UInt8 {
        switch som {
        case BudsConstants.legacySom: return BudsConstants.legacyEom
        case BudsConstants.smepSom: return BudsConstants.smepEom
        default: return BudsConstants.eom
        }
    }

    /// Decode a single message from raw bytes.
    /// - Parameter data: Raw bytes starting from SOM.
    /// - Returns: Parsed message, or nil if decoding fails.
    static func decode(_ data: [UInt8]) -> BudsMessage? {
        guard data.count >= BudsConstants.minimumPacketSize else {
            return nil
        }

        var offset = 0

        // SOM
        let somByte = data[offset]
        guard isValidSom(somByte) else {
            return nil
        }
        let expectedEom = matchingEom(for: somByte)
        offset += 1

        // Header
        guard let header = BudsMessageHeader.decode(Array(data[offset..<offset + 2])) else {
            return nil
        }
        offset += 2

        // Message ID
        guard offset < data.count else { return nil }
        let msgId = BudsMessageId.from(data[offset])
        offset += 1

        // Payload size from header = msgId(1) + payload + CRC(2)
        let payloadSize = header.payloadSize - 3
        guard payloadSize >= 0 else {
            return nil
        }

        // Payload
        guard offset + payloadSize <= data.count else {
            return nil
        }
        let payload = Array(data[offset..<offset + payloadSize])
        offset += payloadSize

        // CRC (2 bytes, little-endian)
        guard offset + 2 <= data.count else { return nil }
        let crcBytes = Array(data[offset..<offset + 2])
        offset += 2

        // Verify CRC
        if !BudsCRC16.verify(messageId: msgId, payload: payload, receivedCRC: crcBytes) {
            ProtocolLogger.log(.warning, "CRC mismatch for message \(msgId)")
        }

        // EOM
        guard offset < data.count, data[offset] == expectedEom else {
            return nil
        }

        return BudsMessage(
            id: msgId,
            type: header.isResponse ? .response : .request,
            payload: payload,
            isFragment: header.isFragment,
            timestamp: Date()
        )
    }

    /// Decode multiple messages from a raw data buffer, consuming processed bytes.
    /// - Parameter data: Incoming data buffer (will be modified to remove consumed bytes).
    /// - Returns: Array of decoded messages.
    static func decodeChunk(_ data: inout [UInt8]) -> [BudsMessage] {
        var messages: [BudsMessage] = []

        while data.count >= BudsConstants.minimumPacketSize {
            // Find SOM
            guard let somIndex = data.firstIndex(where: { isValidSom($0) }) else {
                data.removeAll()
                break
            }

            // Skip garbage before SOM
            if somIndex > 0 {
                data.removeFirst(somIndex)
            }

            guard data.count >= BudsConstants.minimumPacketSize else {
                break
            }

            // Inspect header
            guard let header = BudsMessageHeader.decode(Array(data[1..<3])) else {
                data.removeFirst()
                continue
            }

            // Expected packet size = SOM(1) + Header(2) + header.payloadSize (msgId + payload + CRC) + EOM(1)
            let expectedTotalSize = 1 + BudsConstants.headerSize + header.payloadSize + 1
            guard expectedTotalSize >= BudsConstants.minimumPacketSize else {
                data.removeFirst()
                continue
            }

            // Wait for full packet if incomplete
            if data.count < expectedTotalSize {
                break
            }

            // Decode packet
            let packetData = Array(data.prefix(expectedTotalSize))
            if let message = decode(packetData) {
                data.removeFirst(expectedTotalSize)
                messages.append(message)
            } else {
                // If decode failed at this SOM (e.g. invalid EOM), advance by 1
                data.removeFirst()
            }
        }

        return messages
    }

    // MARK: - Convenience

    /// Create a request message.
    static func request(_ id: BudsMessageId, payload: [UInt8] = []) -> BudsMessage {
        return BudsMessage(id: id, type: .request, payload: payload)
    }

    /// Create a response message.
    static func response(_ id: BudsMessageId, payload: [UInt8] = []) -> BudsMessage {
        return BudsMessage(id: id, type: .response, payload: payload)
    }

    /// Create an acknowledgement (zero-byte response).
    static func ack(for id: BudsMessageId) -> BudsMessage {
        return BudsMessage(id: id, type: .response, payload: [])
    }

    var description: String {
        let hex = payload.map { String(format: "%02X", $0) }.joined(separator: " ")
        return "BudsMessage[\(id), \(type), payload=\(hex)]"
    }
}
