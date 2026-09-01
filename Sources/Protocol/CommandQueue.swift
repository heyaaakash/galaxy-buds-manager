// CommandQueue.swift
// Command queue with retries, timeouts, and acknowledgements for Samsung Galaxy Buds protocol.

import Foundation

// MARK: - Pending Command

/// Represents a command awaiting acknowledgement from the device.
struct PendingCommand: Identifiable {
    let id = UUID()
    let message: BudsMessage
    let sentAt: Date
    var retryCount: Int
    let maxRetries: Int
    let timeout: TimeInterval
    let completion: ((Result<BudsMessage, BudsError>) -> Void)?

    var isExpired: Bool {
        Date().timeIntervalSince(sentAt) > timeout
    }

    var canRetry: Bool {
        retryCount < maxRetries
    }
}

// MARK: - Command Queue

/// Manages outgoing commands with acknowledgement tracking, retries, and timeouts.
actor CommandQueue {
    private var pendingCommands: [UInt8: PendingCommand] = [:]  // keyed by message ID
    private var orderedQueue: [PendingCommand] = []
    private var timerTask: Task<Void, Never>?
    private var onSend: ((BudsMessage) async -> Void)?

    /// Number of currently pending commands.
    var pendingCount: Int {
        orderedQueue.count
    }

    // MARK: - Lifecycle

    /// Start the timeout monitor.
    func start(sendHandler: @escaping (BudsMessage) async -> Void) {
        self.onSend = sendHandler
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            await self?.timeoutLoop()
        }
    }

    /// Stop the queue and cancel all pending commands.
    func stop() {
        timerTask?.cancel()
        timerTask = nil
        for (_, cmd) in pendingCommands {
            cmd.completion?(.failure(.disconnected))
        }
        pendingCommands.removeAll()
        orderedQueue.removeAll()
    }

    // MARK: - Sending

    /// Enqueue a command to be sent with acknowledgement tracking.
    func enqueue(
        _ message: BudsMessage,
        timeout: TimeInterval = BudsConstants.commandTimeout,
        maxRetries: Int = BudsConstants.maxRetries,
        completion: ((Result<BudsMessage, BudsError>) -> Void)? = nil
    ) async {
        let command = PendingCommand(
            message: message,
            sentAt: Date(),
            retryCount: 0,
            maxRetries: maxRetries,
            timeout: timeout,
            completion: completion
        )

        // If there's already a pending command for this message ID, replace it
        if let existing = pendingCommands[message.id.rawValue] {
            existing.completion?(.failure(.commandReplaced))
        }

        pendingCommands[message.id.rawValue] = command
        orderedQueue.append(command)

        ProtocolLogger.log(.outgoing, "\(message)")

        if let onSend = onSend {
            await onSend(message)
        }
    }

    // MARK: - Acknowledgements

    /// Called when a response message is received from the device.
    func handleResponse(_ message: BudsMessage) {
        guard let command = pendingCommands.removeValue(forKey: message.id.rawValue) else {
            ProtocolLogger.log(.info, "Received response for unknown command: \(message.id)")
            return
        }

        // Remove from ordered queue
        orderedQueue.removeAll { $0.id == command.id }

        ProtocolLogger.log(.info, "Command \(message.id) acknowledged")
        command.completion?(.success(message))
    }

    // MARK: - Timeout Loop

    private func timeoutLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

            let now = Date()
            var expiredIds: [UInt8] = []
            var retryIds: [UInt8] = []

            for (id, command) in pendingCommands {
                if now.timeIntervalSince(command.sentAt) > command.timeout {
                    if command.canRetry {
                        retryIds.append(id)
                    } else {
                        expiredIds.append(id)
                    }
                }
            }

            for id in retryIds {
                if var command = pendingCommands.removeValue(forKey: id) {
                    ProtocolLogger.log(.warning, "Command \(command.message.id) timed out, retry \(command.retryCount + 1)")
                    command.retryCount += 1
                    let retryCmd = PendingCommand(
                        message: command.message,
                        sentAt: Date(),
                        retryCount: command.retryCount,
                        maxRetries: command.maxRetries,
                        timeout: command.timeout,
                        completion: command.completion
                    )
                    pendingCommands[id] = retryCmd
                    if let onSend = onSend {
                        await onSend(command.message)
                    }
                }
            }

            for id in expiredIds {
                if let command = pendingCommands.removeValue(forKey: id) {
                    orderedQueue.removeAll { $0.id == command.id }
                    ProtocolLogger.log(.error, "Command \(command.message.id) failed after \(command.maxRetries) retries")
                    command.completion?(.failure(.timeout))
                }
            }
        }
    }

    /// Cancel a specific command by message ID.
    func cancel(_ messageId: BudsMessageId) {
        if let command = pendingCommands.removeValue(forKey: messageId.rawValue) {
            orderedQueue.removeAll { $0.id == command.id }
            command.completion?(.failure(.cancelled))
        }
    }
}
