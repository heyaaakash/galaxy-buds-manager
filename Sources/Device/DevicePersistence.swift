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
        static let launchAtLogin = "GalaxyBuds_LaunchAtLogin"
        static let showBatteryInMenuBar = "GalaxyBuds_ShowBatteryInMenuBar"
        static let debugLogging = "GalaxyBuds_DebugLogging"
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
            do { try updateLaunchAtLogin(newValue) }
            catch { ProtocolLogger.log(.warning, "Could not update launch at login: \(error.localizedDescription)") }
        }
    }

    static func updateLaunchAtLogin(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
        UserDefaults.standard.set(enabled, forKey: Keys.launchAtLogin)
    }

    static var debugLogging: Bool {
        get {
            let val = UserDefaults.standard.object(forKey: Keys.debugLogging)
            return (val as? Bool) ?? false
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.debugLogging) }
    }
}
