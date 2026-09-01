// BudsError.swift
// Error types for the Galaxy Buds Manager protocol and connection layers.

import Foundation

/// Errors that can occur during protocol operations and Bluetooth connection.
enum BudsError: Error, CustomStringConvertible, Sendable {
    // MARK: - Protocol Errors
    case invalidPacket(String)
    case crcMismatch
    case unknownMessageId(UInt8)
    case payloadTooLarge(Int)
    case payloadMalformed
    case unsupportedFeature(String)

    // MARK: - Command Errors
    case timeout
    case commandReplaced
    case cancelled
    case notConnected

    // MARK: - Bluetooth Errors
    case bluetoothUnavailable
    case bluetoothPermissionDenied
    case deviceNotFound
    case connectionFailed(String)
    case disconnected
    case rfcommFailed(String)
    case pairingRequired

    // MARK: - Device Errors
    case unsupportedDevice(String)
    case firmwareUnsupported(String)

    var description: String {
        switch self {
        // Protocol
        case .invalidPacket(let reason):      return "Invalid packet: \(reason)"
        case .crcMismatch:                    return "CRC checksum mismatch"
        case .unknownMessageId(let id):       return "Unknown message ID: 0x\(String(id, radix: 16))"
        case .payloadTooLarge(let size):      return "Payload too large: \(size) bytes"
        case .payloadMalformed:               return "Malformed payload"
        case .unsupportedFeature(let f):      return "Unsupported feature: \(f)"

        // Commands
        case .timeout:                        return "Command timed out"
        case .commandReplaced:                return "Command was replaced by a newer one"
        case .cancelled:                      return "Command was cancelled"
        case .notConnected:                   return "Device not connected"

        // Bluetooth
        case .bluetoothUnavailable:           return "Bluetooth is unavailable"
        case .bluetoothPermissionDenied:      return "Bluetooth permission denied"
        case .deviceNotFound:                 return "Galaxy Buds not found"
        case .connectionFailed(let reason):   return "Connection failed: \(reason)"
        case .disconnected:                   return "Device disconnected"
        case .rfcommFailed(let reason):       return "RFCOMM error: \(reason)"
        case .pairingRequired:                return "Device must be paired in System Settings first"

        // Device
        case .unsupportedDevice(let model):   return "Unsupported device: \(model)"
        case .firmwareUnsupported(let fw):    return "Unsupported firmware: \(fw)"
        }
    }
}
