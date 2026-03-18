import XCTest
@testable import Trace

final class AppThemeTests: XCTestCase {
    func testDarkCaptureThemesKeepReadableEditorContrast() {
        let darkPresets: [AppThemePreset] = [.dark]

        for preset in darkPresets {
            let theme = preset.theme

            XCTAssertGreaterThan(perceivedBrightness(theme.editor.textColor), 0.86, "\(preset.title) text is too dim")
            XCTAssertGreaterThan(perceivedBrightness(theme.editor.placeholderColor), 0.68, "\(preset.title) placeholder is too dim")
        }
    }

    func testLegacyCaptureAppearanceMigrationMapping() {
        XCTAssertEqual(
            AppThemePreset.migrated(fromLegacyCaptureAppearance: "light"),
            .light
        )
        XCTAssertEqual(
            AppThemePreset.migrated(fromLegacyCaptureAppearance: "dark"),
            .dark
        )
        XCTAssertNil(AppThemePreset.migrated(fromLegacyCaptureAppearance: nil))
        XCTAssertNil(AppThemePreset.migrated(fromLegacyCaptureAppearance: "unknown"))
    }

    func testLegacyThemeAliasesMapIntoFourSupportedPresets() {
        XCTAssertEqual(AppThemePreset.resolved(fromStoredRawValue: "classicLight"), .light)
        XCTAssertEqual(AppThemePreset.resolved(fromStoredRawValue: "classicDark"), .dark)
        XCTAssertEqual(AppThemePreset.resolved(fromStoredRawValue: "obsidian"), .dark)
        XCTAssertEqual(AppThemePreset.resolved(fromStoredRawValue: "linear"), .dark)
        XCTAssertEqual(AppThemePreset.resolved(fromStoredRawValue: "cursor"), .dark)
        XCTAssertEqual(AppThemePreset.resolved(fromStoredRawValue: "notion"), .paper)
        XCTAssertEqual(AppThemePreset.resolved(fromStoredRawValue: "anthropic"), .dune)
    }

    func testEveryPresetResolvesToCompleteThemeTokens() {
        for preset in AppThemePreset.allCases {
            let theme = preset.theme

            XCTAssertEqual(theme.preset, preset)
            XCTAssertEqual(theme.previewSwatches.count, 4)
        }
    }

    func testFreshInstallDefaultsToDarkAndPersistsValue() {
        let defaults = makeDefaults(suffix: #function)
        let settings = AppSettings(defaults: defaults, fileManager: .default)

        XCTAssertEqual(settings.appThemePreset, .dark)
        XCTAssertEqual(defaults.string(forKey: SettingKeys.appThemePreset), AppThemePreset.dark.rawValue)
    }

    func testStoredThemeAliasTakesPrecedenceOverLegacyAppearance() {
        let defaults = makeDefaults(suffix: #function)
        defaults.set("cursor", forKey: SettingKeys.appThemePreset)
        defaults.set("light", forKey: LegacySettingKeys.captureAppearance)

        let settings = AppSettings(defaults: defaults, fileManager: .default)

        XCTAssertEqual(settings.appThemePreset, .dark)
        XCTAssertEqual(defaults.string(forKey: SettingKeys.appThemePreset), AppThemePreset.dark.rawValue)
    }

    func testLegacyLightThemeMigratesToClassicLight() {
        let defaults = makeDefaults(suffix: #function)
        defaults.set("light", forKey: LegacySettingKeys.captureAppearance)

        let settings = AppSettings(defaults: defaults, fileManager: .default)

        XCTAssertEqual(settings.appThemePreset, .light)
        XCTAssertEqual(defaults.string(forKey: SettingKeys.appThemePreset), AppThemePreset.light.rawValue)
    }

    func testLegacyDarkThemeMigratesToClassicDark() {
        let defaults = makeDefaults(suffix: #function)
        defaults.set("dark", forKey: LegacySettingKeys.captureAppearance)

        let settings = AppSettings(defaults: defaults, fileManager: .default)

        XCTAssertEqual(settings.appThemePreset, .dark)
        XCTAssertEqual(defaults.string(forKey: SettingKeys.appThemePreset), AppThemePreset.dark.rawValue)
    }

    func testLegacyFlashNoteDefaultsSuiteMigratesIntoTraceNamespace() {
        let defaults = makeDefaults(prefix: "Trace", suffix: #function)
        let legacyDefaults = makeDefaults(prefix: "FlashNote", suffix: #function)
        legacyDefaults.set("/tmp/vault", forKey: LegacySettingKeys.vaultPath)
        legacyDefaults.set("dark", forKey: LegacySettingKeys.captureAppearance)

        let settings = AppSettings(defaults: defaults, legacyDefaults: legacyDefaults, fileManager: .default)

        XCTAssertEqual(settings.vaultPath, "/tmp/vault")
        XCTAssertEqual(settings.appThemePreset, .dark)
        XCTAssertEqual(defaults.string(forKey: SettingKeys.vaultPath), "/tmp/vault")
        XCTAssertEqual(defaults.string(forKey: SettingKeys.appThemePreset), AppThemePreset.dark.rawValue)
    }

    func testUpdatingThemePresetPersistsRawValue() {
        let defaults = makeDefaults(suffix: #function)
        let settings = AppSettings(defaults: defaults, fileManager: .default)

        settings.appThemePreset = .dune

        XCTAssertEqual(settings.appThemePreset, .dune)
        XCTAssertEqual(defaults.string(forKey: SettingKeys.appThemePreset), AppThemePreset.dune.rawValue)
    }

    private func makeDefaults(prefix: String = "Trace", suffix: String) -> UserDefaults {
        let suiteName = "\(prefix)Tests.AppThemeTests.\(suffix)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create test defaults suite: \(suiteName)")
        }

        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func perceivedBrightness(_ color: NSColor) -> CGFloat {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        return (0.299 * rgbColor.redComponent) + (0.587 * rgbColor.greenComponent) + (0.114 * rgbColor.blueComponent)
    }
}
