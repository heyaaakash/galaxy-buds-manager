// DevicePersistence.swift
// Persistence for device info, user preferences, and crash-safe state restoration.

import Foundation
import ServiceManagement

/// Handles persistence of device information and user preferences.
enum DevicePersistence {

    private enum Keys {
        static let lastDeviceAddress = "GalaxyBuds_LastDeviceAddress"
        static let lastDeviceName = "GalaxyBuds_LastDeviceName"
        static let lastDeviceModel = "GalaxyBuds_LastDeviceModel"
        static let autoReconnect = "GalaxyBuds_AutoReconnect"
        static let launchAtLogin = "GalaxyBuds_LaunchAtLogin"
        static let showBatteryInMenuBar = "GalaxyBuds_ShowBatteryInMenuBar"
        static let debugLogging = "GalaxyBuds_DebugLogging"
        static let lastDisconnectTime = "GalaxyBuds_LastDisconnectTime"
    }

    // MARK: - Last Known Device

    static var lastDeviceAddress: String? {
        UserDefaults.standard.string(forKey: Keys.lastDeviceAddress)
    }

    static func saveLastDevice(address: String, name: String) {
        UserDefaults.standard.set(address, forKey: Keys.lastDeviceAddress)
        UserDefaults.standard.set(name, forKey: Keys.lastDeviceName)
    }

    static var lastDeviceName: String? {
        UserDefaults.standard.string(forKey: Keys.lastDeviceName)
    }

    static func clearLastDevice() {
        UserDefaults.standard.removeObject(forKey: Keys.lastDeviceAddress)
        UserDefaults.standard.removeObject(forKey: Keys.lastDeviceName)
    }

    static var hasLastDevice: Bool {
        lastDeviceAddress != nil
    }

    // MARK: - Preferences

    static var autoReconnect: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.autoReconnect) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.autoReconnect) }
    }

    static var showBatteryInMenuBar: Bool {
        get {
            let val = UserDefaults.standard.object(forKey: Keys.showBatteryInMenuBar)
            return (val as? Bool) ?? true
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showBatteryInMenuBar) }
    }

    static var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                return UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.launchAtLogin)
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        if SMAppService.mainApp.status != .enabled {
                            try SMAppService.mainApp.register()
                        }
                    } else {
                        if SMAppService.mainApp.status == .enabled {
                            try SMAppService.mainApp.unregister()
                        }
                    }
                } catch {
                    ProtocolLogger.log(.warning, "Could not update SMAppService launchAtLogin: \(error.localizedDescription)")
                }
            }
        }
    }

    static var debugLogging: Bool {
        get {
            let val = UserDefaults.standard.object(forKey: Keys.debugLogging)
            return (val as? Bool) ?? false
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.debugLogging) }
    }

    // MARK: - State Restoration

    static func recordDisconnect() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastDisconnectTime)
    }

    static var lastDisconnectTime: Date? {
        guard let interval = UserDefaults.standard.object(forKey: Keys.lastDisconnectTime) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    /// Whether we should attempt reconnection based on time since last disconnect.
    /// If disconnected for less than 30 seconds, try to reconnect.
    static var shouldAutoReconnect: Bool {
        guard autoReconnect, hasLastDevice else { return false }
        guard let lastDisconnect = lastDisconnectTime else { return true }
        return Date().timeIntervalSince(lastDisconnect) < 30
    }
}
