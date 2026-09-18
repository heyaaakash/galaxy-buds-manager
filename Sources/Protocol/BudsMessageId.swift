// BudsMessageId.swift
// Galaxy Buds2 Pro SPP Message IDs
//
// Derived from public protocol documentation at:
//   https://github.com/timschneeb/GalaxyBudsClient/blob/master/Galaxy%20Buds%20Plus%20RFComm%20Protocol%20Notes.md
//   https://gadgetbridge.org/internals/specifics/galaxy-buds-protocol/
//
// This is an independent implementation; no GPL-licensed code has been copied.

import Foundation

// MARK: - Message ID Enum

/// All known Samsung Galaxy Buds SPP message IDs.
/// Only the IDs relevant to Buds2 Pro are named with human-readable names;
/// the rest retain their numeric identifiers for future reference.
enum BudsMessageId: UInt8, CustomStringConvertible, CaseIterable, Sendable {

    case setHearingEnhancements = 0x8F
    case outsideDoubleTap = 0x95
    case universalAcknowledgement = 0x42

    // MARK: - Status & Connection

    /// Basic status update: battery L/R, placement, connection.
    case statusUpdated           = 0x60

    /// Extended status update: battery, ANC, ambient, equalizer, touch, color, etc.
    case extendedStatusUpdated   = 0x61

    /// Connection topology changed (left/right roles).
    case connectionUpdated       = 0x62

    /// Firmware version information (short).
    case versionInfo             = 0x63

    /// Firmware version information (long, includes more detail).
    case versionInfoLong         = 0x68

    // MARK: - Manager Handshake

    /// Response to extendedStatusUpdated; client must send this with app info.
    case managerInfo             = 0x88

    /// Sync device time to earbuds.
    case updateTime              = 0xA7

    // MARK: - Noise Control

    /// Notification: noise control state changed on device.
    case noiseControlsUpdate     = 0x77

    /// Set noise control mode (ANC / Off / Ambient).
    case noiseControls           = 0x78

    /// Set touch-and-hold noise control behavior.
    case setTouchAndHoldNoiseControls = 0x79

    /// Set whether ANC works with one earbud removed.
    case setAncWithOneEarbud     = 0x6F

    // MARK: - Ambient Sound

    /// Set ambient mode on/off.
    case setAmbientMode          = 0x80

    /// Notification: ambient mode state updated.
    case ambientModeUpdated      = 0x81

    /// Customize ambient sound levels (3-band).
    case customizeAmbientSound   = 0x82

    /// Noise reduction level for ambient mode.
    case noiseReductionLevel     = 0x83

    /// Set ambient volume level.
    case ambientVolume           = 0x84

    /// Adjust sound sync (low latency mode).
    case adjustSoundSync         = 0x85

    /// Enable extra-high ambient volume step.
    case extraHighAmbient        = 0x96

    /// Amplify ambient sound setting.
    case setAmplifyAmbientSound  = 0x7E

    // MARK: - Equalizer

    /// Set equalizer preset (0-5).
    case equalizer               = 0x86

    /// Send custom equalizer curve.
    case customEqualizeSend      = 0x89

    /// Receive custom equalizer curve.
    case customEqualizeRecv      = 0x69

    // MARK: - Touch & Controls

    /// Lock/unlock touchpad.
    case lockTouchpad            = 0x90

    /// Notification: touch settings updated.
    case touchUpdated            = 0x91

    /// Set left/right touchpad long-press options.
    case setTouchpadOption       = 0x92

    /// Set other touchpad options.
    case setTouchpadOtherOption  = 0x93

    /// Touch on buds event (tap detected).
    case touchOnBuds             = 0x2D

    // MARK: - Voice & Call

    /// Set Bixby wake-up keyword.
    case setBixbyKeyword         = 0x66

    /// Set voice wake-up on/off.
    case setVoiceWakeUp          = 0x97

    /// Voice wake-up language.
    case voiceWakeUpLanguage     = 0x99

    /// Voice notification status.
    case voiceNotiStatus         = 0xA4

    /// Voice notification stop.
    case voiceNotiStop           = 0xA9

    /// Detect conversations setting.
    case setDetectConversations       = 0x7A

    /// Detect conversations duration.
    case setDetectConversationsDuration = 0x7B

    /// In-band ringtone setting.
    case setInBandRingtone       = 0x8A

    /// Sidetone setting.
    case setSidetone             = 0x8B

    /// Set call path control.
    case setCallPathControl      = 0x6E

    /// Extra clear call sound.
    case extraClearSoundCall     = 0x48

    /// Pause media when one bud removed.
    case pauseMediaWhenOneBudRemoved = 0x6C

    // MARK: - Game Mode

    /// Game mode (low latency).
    case gameMode                = 0x87

    // MARK: - Spatial Audio

    /// Set spatial audio on/off.
    case setSpatialAudio         = 0x7C

    /// Spatial audio data (head tracking).
    case spatialAudioData        = 0xC2

    /// Spatial audio control.
    case spatialAudioControl     = 0xC3

    // MARK: - Find My Earbuds

    /// Start find-my-earbuds beeping.
    case findMyEarbudsStart      = 0xA0

    /// Stop find-my-earbuds.
    case findMyEarbudsStop       = 0xA1

    /// Find my earbuds while wearing (gentler).
    case findMyEarbudsOnWearingStart = 0xA6

    /// Mute/unmute earbuds (only in find-my-earbuds mode).
    case muteEarbud              = 0xA2

    /// Mute status update.
    case muteEarbudStatusUpdated = 0xA3

    // MARK: - Battery

    /// Battery type information.
    case batteryType             = 0x94

    /// SOC battery cycle count.
    case socBatteryCycle         = 0xCE

    // MARK: - Adaptive

    /// Adaptive volume enabled.
    case setAdaptiveVolumeEnabled = 0xC5

    /// Adaptive EQ volume control.
    case adaptiveEqVolumeControl = 0xD9

    /// Adaptive EQ control.
    case adaptiveEqControl       = 0xDA

    /// Adaptive EQ status.
    case adaptiveEqStatus        = 0xDB

    // MARK: - Firmware Update (FOTA)

    /// FOTA session start.
    case fotaSession             = 0xB0

    /// FOTA control.
    case fotaControl             = 0xBC

    /// FOTA download data.
    case fotaDownloadData        = 0xBD

    /// FOTA update.
    case fotaUpdate              = 0xBE

    /// FOTA result.
    case fotaResult              = 0xB9

    // MARK: - System & Debug

    /// Reset to factory defaults.
    case reset                   = 0x50

    /// Response to reset.
    case resp                    = 0x51

    /// Reboot device.
    case reboot                  = 0x52

    /// Power off device.
    case poweroff                = 0x53

    /// Status alert (e.g., water detected).
    case statusAlert             = 0x57

    /// Debug: get all data.
    case debugGetAllData         = 0x26

    /// Debug: serial number.
    case debugSerialNumber       = 0x29

    /// Debug: build info.
    case debugBuildInfo          = 0x28

    /// Debug: SKU.
    case debugSku                = 0x22

    /// Debug: version.
    case debugGetVersion         = 0x24

    /// Self-test.
    case selfTest                = 0xAB

    /// Usage report.
    case usageReport             = 0x40

    /// Usage report v2.
    case usageReportV2           = 0x47

    /// Check fit of earbuds.
    case checkFitOfEarbuds       = 0x9D

    /// Check fit result.
    case checkFitResult          = 0x9E

    /// Seamlessly connection setting.
    case setSeamlessConnection   = 0xAF

    /// Auto switch audio output.
    case autoSwitchAudioOutput   = 0x73

    /// Pairing mode.
    case pairingMode             = 0x72

    /// Cradle serial number.
    case cradleSerialNumber      = 0xCD

    /// Device color info.
    case deviceColor             = 0x65

    /// Profile control.
    case profileControl          = 0x71

    /// Hot command manage.
    case hotCommandManage        = 0x0F

    /// Hot command language update.
    case setHotCommand           = 0x64

    /// Multipoint info.
    case multipointInfo          = 0x76

    /// Read property (alt mode).
    case readProperty            = 0x44

    /// Write property (alt mode).
    case writeProperty           = 0x43

    /// Notify property (alt mode).
    case notifyProperty          = 0x45

    /// Pass through mode.
    case passThrough             = 0x9F

    /// Speak seamlessly setting.
    case setSpeakSeamlessly      = 0x7D

    /// Notification info (beep sound).
    case notificationInfo        = 0xA5

    /// Overheat status.
    case overheat                = 0xCA

    /// Get/set personal name.
    case getPersonalName         = 0xD3

    // MARK: - Catch-all

    /// Unknown / unimplemented message ID.
    case unknown                 = 0x00

    /// Forward-compatible init with raw byte.
    static func from(_ raw: UInt8) -> BudsMessageId {
        return BudsMessageId(rawValue: raw) ?? .unknown
    }

    var description: String {
        return String(format: "0x%02X", rawValue)
    }
}
