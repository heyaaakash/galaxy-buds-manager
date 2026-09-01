// DebugView.swift
// Debug view for protocol logging and packet replay.
// Shows real-time protocol traffic with hex dumps and allows export/replay.

import SwiftUI

// MARK: - Debug View

/// SwiftUI view that displays protocol log entries in real-time.
struct DebugView: View {
    @State private var logEntries: [ProtocolLogEntry] = []
    @State private var filterLevel: LogLevel? = nil
    @State private var searchText = ""
    @State private var autoScroll = true
    @State private var showExportSheet = false
    @State private var exportText = ""
    @State private var importData: Data?

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()

            // Filter bar
            filterBar

            Divider()

            // Log entries
            logList
        }
        .frame(minWidth: 600, minHeight: 400)
        .onReceive(timer) { _ in
            refreshEntries()
        }
        .sheet(isPresented: $showExportSheet) {
            exportSheet
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("Protocol Debug Log")
                .font(.headline)

            Spacer()

            Text("\(logEntries.count) entries")
                .foregroundStyle(.secondary)
                .font(.caption)

            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.switch)
                .controlSize(.small)

            Button("Export") {
                exportText = ProtocolLogger.exportText()
                showExportSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Clear") {
                ProtocolLogger.clear()
                logEntries.removeAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack {
            Text("Filter:")
                .font(.caption)

            ForEach([nil] + LogLevel.allCases, id: \.self) { level in
                Button(level?.rawValue ?? "ALL") {
                    filterLevel = level
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(filterLevel == level ? .accentColor : .secondary)
            }

            Spacer()

            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredEntries) { entry in
                        logEntryRow(entry)
                            .id(entry.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: logEntries.count) { _, _ in
                if autoScroll, let last = logEntries.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .font(.system(.caption, design: .monospaced))
    }

    // MARK: - Log Entry Row

    private func logEntryRow(_ entry: ProtocolLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 8) {
                Text(entry.timestampString)
                    .foregroundStyle(.secondary)

                Text(entry.direction.rawValue)
                    .fontWeight(.bold)
                    .foregroundColor(directionColor(entry.direction))

                Text("[\(entry.level.rawValue)]")
                    .foregroundColor(levelColor(entry.level))

                Text(entry.message)
            }

            if let hex = entry.hexDump {
                Text("    \(hex)")
                    .foregroundStyle(.secondary)
                    .font(.system(.caption2, design: .monospaced))
            }
        }
        .padding(.vertical, 1)
    }

    // MARK: - Helpers

    private func refreshEntries() {
        logEntries = ProtocolLogger.cachedEntries
    }

    private var filteredEntries: [ProtocolLogEntry] {
        logEntries.filter { entry in
            let matchesLevel = filterLevel == nil || entry.level == filterLevel
            let matchesSearch = searchText.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(searchText)
            return matchesLevel && matchesSearch
        }
    }

    private func directionColor(_ direction: ProtocolLogEntry.LogDirection) -> Color {
        switch direction {
        case .sent: return .green
        case .recv: return .blue
        case .none: return .gray
        }
    }

    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .error:    return .red
        case .warning:  return .orange
        case .outgoing: return .green
        case .incoming: return .blue
        case .info:     return .primary
        case .verbose:  return .secondary
        }
    }

    // MARK: - Export Sheet

    private var exportSheet: some View {
        VStack {
            Text("Protocol Log Export")
                .font(.headline)

            TextEditor(text: $exportText)
                .font(.system(.caption, design: .monospaced))
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportText, forType: .string)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Close") {
                    showExportSheet = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 700, height: 500)
    }
}

// MARK: - Static Cache for Non-Sendable Access

/// ProtocolLogger is an actor, so we maintain a simple static cache for SwiftUI views.
extension ProtocolLogger {
    /// Cached entries for SwiftUI display (updated periodically).
    nonisolated(unsafe) static var cachedEntries: [ProtocolLogEntry] = []

    nonisolated static func setupCache() {
        onEntry = { entry in
            cachedEntries.append(entry)
            if cachedEntries.count > maxEntries {
                cachedEntries.removeFirst(cachedEntries.count - maxEntries)
            }
        }
    }
}
