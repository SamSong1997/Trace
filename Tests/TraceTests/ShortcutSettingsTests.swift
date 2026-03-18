import Carbon
import XCTest
@testable import Trace

final class ShortcutSettingsTests: XCTestCase {
    func testFreshInstallDefaultsModeToggleShortcutToShiftTab() {
        let defaults = makeDefaults(suffix: #function)
        let settings = AppSettings(defaults: defaults, fileManager: .default)

        XCTAssertEqual(settings.modeToggleKeyCode, UInt32(kVK_Tab))
        XCTAssertEqual(settings.modeToggleModifiers, UInt32(shiftKey))
    }

    func testUpdatingModeToggleShortcutPersistsRawValues() {
        let defaults = makeDefaults(suffix: #function)
        let settings = AppSettings(defaults: defaults, fileManager: .default)

        settings.modeToggleKeyCode = UInt32(kVK_ANSI_M)
        settings.modeToggleModifiers = UInt32(cmdKey | shiftKey)

        XCTAssertEqual(defaults.integer(forKey: SettingKeys.modeToggleKeyCode), Int(kVK_ANSI_M))
        XCTAssertEqual(defaults.integer(forKey: SettingKeys.modeToggleModifiers), Int(cmdKey | shiftKey))
    }

    func testResetShortcutSettingsRestoresModeToggleShortcutDefault() {
        let defaults = makeDefaults(suffix: #function)
        let settings = AppSettings(defaults: defaults, fileManager: .default)
        settings.modeToggleKeyCode = UInt32(kVK_ANSI_M)
        settings.modeToggleModifiers = UInt32(cmdKey)

        settings.resetShortcutSettingsToDefault()

        XCTAssertEqual(settings.modeToggleKeyCode, UInt32(kVK_Tab))
        XCTAssertEqual(settings.modeToggleModifiers, UInt32(shiftKey))
    }

    private func makeDefaults(prefix: String = "Trace", suffix: String) -> UserDefaults {
        let suiteName = "\(prefix)Tests.ShortcutSettingsTests.\(suffix)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create test defaults suite: \(suiteName)")
        }

        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
