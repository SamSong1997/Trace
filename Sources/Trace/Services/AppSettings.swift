import AppKit
import Combine
import Carbon
import Foundation
import ServiceManagement

enum SettingKeys {
    static let vaultPath = "trace.vaultPath"
    static let dailyFolderName = "trace.dailyFolderName"
    static let dailyFileDateFormat = "trace.dailyFileDateFormat"
    static let noteWriteMode = "trace.noteWriteMode"
    static let inboxFolderName = "trace.inboxFolderName"
    static let hotKeyCode = "trace.hotKeyCode"
    static let hotKeyModifiers = "trace.hotKeyModifiers"
    static let sendNoteKeyCode = "trace.sendNoteKeyCode"
    static let sendNoteModifiers = "trace.sendNoteModifiers"
    static let appendNoteKeyCode = "trace.appendNoteKeyCode"
    static let appendNoteModifiers = "trace.appendNoteModifiers"
    static let modeToggleKeyCode = "trace.modeToggleKeyCode"
    static let modeToggleModifiers = "trace.modeToggleModifiers"
    static let launchAtLogin = "trace.launchAtLogin"
    static let panelOriginX = "trace.panel.originX"
    static let panelOriginY = "trace.panel.originY"
    static let panelWidth = "trace.panel.width"
    static let panelHeight = "trace.panel.height"
    static let appThemePreset = "trace.appThemePreset"
    static let sectionTitles = "trace.sectionTitles"
    static let sectionTitlesOrderVersion = "trace.sectionTitlesOrderVersion"
    static let dailyEntryThemePreset = "trace.dailyEntryThemePreset"
    static let markdownEntrySeparatorStyle = "trace.markdownEntrySeparatorStyle"
}

enum LegacySettingKeys {
    static let bundleIdentifier = "com.flashnote.app"
    static let vaultPath = "flashnote.vaultPath"
    static let dailyFolderName = "flashnote.dailyFolderName"
    static let dailyFileDateFormat = "flashnote.dailyFileDateFormat"
    static let noteWriteMode = "flashnote.noteWriteMode"
    static let inboxFolderName = "flashnote.inboxFolderName"
    static let hotKeyCode = "flashnote.hotKeyCode"
    static let hotKeyModifiers = "flashnote.hotKeyModifiers"
    static let sendNoteKeyCode = "flashnote.sendNoteKeyCode"
    static let sendNoteModifiers = "flashnote.sendNoteModifiers"
    static let appendNoteKeyCode = "flashnote.appendNoteKeyCode"
    static let appendNoteModifiers = "flashnote.appendNoteModifiers"
    static let modeToggleKeyCode = "flashnote.modeToggleKeyCode"
    static let modeToggleModifiers = "flashnote.modeToggleModifiers"
    static let launchAtLogin = "flashnote.launchAtLogin"
    static let panelOriginX = "flashnote.panel.originX"
    static let panelOriginY = "flashnote.panel.originY"
    static let panelWidth = "flashnote.panel.width"
    static let panelHeight = "flashnote.panel.height"
    static let appThemePreset = "flashnote.appThemePreset"
    static let captureAppearance = "flashnote.captureAppearance"
    static let sectionTitles = "flashnote.sectionTitles"
    static let sectionTitlesOrderVersion = "flashnote.sectionTitlesOrderVersion"
    static let dailyEntryThemePreset = "flashnote.dailyEntryThemePreset"
    static let markdownEntrySeparatorStyle = "flashnote.markdownEntrySeparatorStyle"
    static let dailyEntryContainerStyle = "flashnote.dailyEntryContainerStyle"
    static let dailyCardTheme = "flashnote.dailyCardTheme"
}

enum NoteWriteMode: String, CaseIterable, Identifiable {
    case dimension
    case file

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dimension:
            return "条目（Daily）"
        case .file:
            return "文档（Inbox）"
        }
    }

    var compactTitle: String {
        switch self {
        case .dimension:
            return "条目"
        case .file:
            return "文档"
        }
    }

    var iconName: String {
        switch self {
        case .dimension:
            return "square.grid.2x2"
        case .file:
            return "doc.text"
        }
    }

    var destinationTitle: String {
        switch self {
        case .dimension:
            return "写入 Daily 条目"
        case .file:
            return "写入独立文档"
        }
    }

    var summary: String {
        switch self {
        case .dimension:
            return "保留在今天的 Daily 条目里，适合快速收集和后续整理。"
        case .file:
            return "每次新建一篇独立 Markdown 文档，适合沉淀为正式稿件。"
        }
    }

    var targetSummary: String {
        switch self {
        case .dimension:
            return "继续按模块写入 Daily，底部保留 5 个条目模块切换。"
        case .file:
            return "新建独立文件，可选标题，目录由 Settings 中的 Inbox 配置管理。"
        }
    }

    var toggled: NoteWriteMode {
        switch self {
        case .dimension:
            return .file
        case .file:
            return .dimension
        }
    }
}

enum DailyEntryThemePreset: String, CaseIterable, Identifiable {
    case plainTextTimestamp
    case codeBlockClassic
    case markdownQuote
    case linear
    case notion
    case obsidian
    case anthropic
    case openAI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plainTextTimestamp:
            return "文本 + 时间戳"
        case .codeBlockClassic:
            return "代码块（经典）"
        case .markdownQuote:
            return "引用（Markdown）"
        case .linear:
            return "Linear"
        case .notion:
            return "Notion"
        case .obsidian:
            return "Obsidian"
        case .anthropic:
            return "Anthropic"
        case .openAI:
            return "OpenAI"
        }
    }

    // Uses Obsidian built-in callout types so output stays plugin-independent.
    var calloutType: String? {
        switch self {
        case .plainTextTimestamp:
            return nil
        case .codeBlockClassic:
            return nil
        case .markdownQuote:
            return nil
        case .linear:
            return "info"
        case .notion:
            return "quote"
        case .obsidian:
            return "example"
        case .anthropic:
            return "warning"
        case .openAI:
            return "tip"
        }
    }

    fileprivate static func migrated(
        from legacyContainer: LegacyDailyEntryContainerStyle,
        legacyCardTheme: LegacyDailyCardTheme
    ) -> DailyEntryThemePreset {
        guard legacyContainer == .calloutCard else {
            return .plainTextTimestamp
        }

        switch legacyCardTheme {
        case .anthropic:
            return .anthropic
        case .obsidianPurple:
            return .obsidian
        case .slate:
            return .linear
        }
    }
}

enum MarkdownEntrySeparatorStyle: String, CaseIterable, Identifiable {
    case none
    case horizontalRule
    case asteriskRule

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "仅空行"
        case .horizontalRule:
            return "--- 分割线"
        case .asteriskRule:
            return "*** 分割线"
        }
    }

    var markdown: String? {
        switch self {
        case .none:
            return nil
        case .horizontalRule:
            return "---"
        case .asteriskRule:
            return "***"
        }
    }
}

private enum LegacyDailyEntryContainerStyle: String {
    case codeBlock
    case calloutCard
}

private enum LegacyDailyCardTheme: String {
    case anthropic
    case obsidianPurple
    case slate
}

enum VaultPathValidationIssue: Equatable {
    case empty
    case doesNotExist
    case notDirectory
    case notWritable

    var message: String {
        switch self {
        case .empty:
            return "请先选择 Obsidian Vault 文件夹。"
        case .doesNotExist:
            return "Vault 路径不存在，请重新选择。"
        case .notDirectory:
            return "Vault 路径必须是文件夹。"
        case .notWritable:
            return "Vault 路径不可写，请检查文件夹权限。"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private static let currentSectionTitleOrderVersion = 2
    private static let defaultGlobalHotKeyCode = UInt32(kVK_ANSI_N)
    private static let defaultGlobalHotKeyModifiers = UInt32(cmdKey)
    private static let defaultSendNoteKeyCode = UInt32(kVK_Return)
    private static let defaultSendNoteModifiers = UInt32(cmdKey)
    private static let defaultAppendNoteKeyCode = UInt32(kVK_Return)
    private static let defaultAppendNoteModifiers = UInt32(cmdKey | shiftKey)
    private static let defaultModeToggleKeyCode = UInt32(kVK_Tab)
    private static let defaultModeToggleModifiers = UInt32(shiftKey)

    private let defaults: UserDefaults
    private let fileManager: FileManager

    @Published var vaultPath: String {
        didSet {
            defaults.set(vaultPath, forKey: SettingKeys.vaultPath)
        }
    }

    @Published var dailyFolderName: String {
        didSet {
            defaults.set(dailyFolderName, forKey: SettingKeys.dailyFolderName)
        }
    }

    @Published var dailyFileDateFormat: String {
        didSet {
            defaults.set(dailyFileDateFormat, forKey: SettingKeys.dailyFileDateFormat)
        }
    }

    @Published var noteWriteMode: NoteWriteMode {
        didSet {
            defaults.set(noteWriteMode.rawValue, forKey: SettingKeys.noteWriteMode)
        }
    }

    @Published var inboxFolderName: String {
        didSet {
            defaults.set(inboxFolderName, forKey: SettingKeys.inboxFolderName)
        }
    }

    @Published var hotKeyCode: UInt32 {
        didSet {
            defaults.set(Int(hotKeyCode), forKey: SettingKeys.hotKeyCode)
        }
    }

    @Published var hotKeyModifiers: UInt32 {
        didSet {
            let normalized = KeyboardShortcut.sanitizedCarbonModifiers(hotKeyModifiers)
            if normalized != hotKeyModifiers {
                hotKeyModifiers = normalized
                return
            }
            defaults.set(Int(hotKeyModifiers), forKey: SettingKeys.hotKeyModifiers)
        }
    }

    @Published var sendNoteKeyCode: UInt32 {
        didSet {
            defaults.set(Int(sendNoteKeyCode), forKey: SettingKeys.sendNoteKeyCode)
        }
    }

    @Published var sendNoteModifiers: UInt32 {
        didSet {
            let normalized = KeyboardShortcut.sanitizedCarbonModifiers(sendNoteModifiers)
            if normalized != sendNoteModifiers {
                sendNoteModifiers = normalized
                return
            }
            defaults.set(Int(sendNoteModifiers), forKey: SettingKeys.sendNoteModifiers)
        }
    }

    @Published var appendNoteKeyCode: UInt32 {
        didSet {
            defaults.set(Int(appendNoteKeyCode), forKey: SettingKeys.appendNoteKeyCode)
        }
    }

    @Published var appendNoteModifiers: UInt32 {
        didSet {
            let normalized = KeyboardShortcut.sanitizedCarbonModifiers(appendNoteModifiers)
            if normalized != appendNoteModifiers {
                appendNoteModifiers = normalized
                return
            }
            defaults.set(Int(appendNoteModifiers), forKey: SettingKeys.appendNoteModifiers)
        }
    }

    @Published var modeToggleKeyCode: UInt32 {
        didSet {
            defaults.set(Int(modeToggleKeyCode), forKey: SettingKeys.modeToggleKeyCode)
        }
    }

    @Published var modeToggleModifiers: UInt32 {
        didSet {
            let normalized = KeyboardShortcut.sanitizedCarbonModifiers(modeToggleModifiers)
            if normalized != modeToggleModifiers {
                modeToggleModifiers = normalized
                return
            }
            defaults.set(Int(modeToggleModifiers), forKey: SettingKeys.modeToggleModifiers)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: SettingKeys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    @Published var appThemePreset: AppThemePreset {
        didSet {
            defaults.set(appThemePreset.rawValue, forKey: SettingKeys.appThemePreset)
        }
    }

    @Published var sectionTitles: [String] {
        didSet {
            let normalized = Self.normalizedSectionTitles(sectionTitles)
            if normalized != sectionTitles {
                sectionTitles = normalized
                return
            }
            defaults.set(sectionTitles, forKey: SettingKeys.sectionTitles)
        }
    }

    @Published var dailyEntryThemePreset: DailyEntryThemePreset {
        didSet {
            defaults.set(dailyEntryThemePreset.rawValue, forKey: SettingKeys.dailyEntryThemePreset)
        }
    }

    @Published var markdownEntrySeparatorStyle: MarkdownEntrySeparatorStyle {
        didSet {
            defaults.set(markdownEntrySeparatorStyle.rawValue, forKey: SettingKeys.markdownEntrySeparatorStyle)
        }
    }

    init(
        defaults: UserDefaults = .standard,
        legacyDefaults: UserDefaults? = nil,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.fileManager = fileManager

        Self.migrateLegacyDefaultsIfNeeded(
            into: defaults,
            legacyDefaults: legacyDefaults ?? Self.defaultLegacyDefaults(for: defaults)
        )

        vaultPath = defaults.string(forKey: SettingKeys.vaultPath) ?? ""
        dailyFolderName = defaults.string(forKey: SettingKeys.dailyFolderName) ?? "Daily"
        dailyFileDateFormat = defaults.string(forKey: SettingKeys.dailyFileDateFormat) ?? "yyyy M月d日 EEEE"
        noteWriteMode = NoteWriteMode(rawValue: defaults.string(forKey: SettingKeys.noteWriteMode) ?? "") ?? .dimension
        inboxFolderName = defaults.string(forKey: SettingKeys.inboxFolderName) ?? "inbox"

        hotKeyCode = {
            let value = defaults.integer(forKey: SettingKeys.hotKeyCode)
            return value == 0 ? Self.defaultGlobalHotKeyCode : UInt32(value)
        }()
        hotKeyModifiers = {
            let value = defaults.integer(forKey: SettingKeys.hotKeyModifiers)
            let candidate = value == 0 ? Self.defaultGlobalHotKeyModifiers : UInt32(value)
            return KeyboardShortcut.sanitizedCarbonModifiers(candidate)
        }()
        sendNoteKeyCode = {
            let value = defaults.integer(forKey: SettingKeys.sendNoteKeyCode)
            return value == 0 ? Self.defaultSendNoteKeyCode : UInt32(value)
        }()
        sendNoteModifiers = {
            let value = defaults.integer(forKey: SettingKeys.sendNoteModifiers)
            let candidate = value == 0 ? Self.defaultSendNoteModifiers : UInt32(value)
            return KeyboardShortcut.sanitizedCarbonModifiers(candidate)
        }()
        appendNoteKeyCode = {
            let value = defaults.integer(forKey: SettingKeys.appendNoteKeyCode)
            return value == 0 ? Self.defaultAppendNoteKeyCode : UInt32(value)
        }()
        appendNoteModifiers = {
            let value = defaults.integer(forKey: SettingKeys.appendNoteModifiers)
            let candidate = value == 0 ? Self.defaultAppendNoteModifiers : UInt32(value)
            return KeyboardShortcut.sanitizedCarbonModifiers(candidate)
        }()
        modeToggleKeyCode = {
            let value = defaults.integer(forKey: SettingKeys.modeToggleKeyCode)
            return value == 0 ? Self.defaultModeToggleKeyCode : UInt32(value)
        }()
        modeToggleModifiers = {
            let value = defaults.integer(forKey: SettingKeys.modeToggleModifiers)
            let candidate = value == 0 ? Self.defaultModeToggleModifiers : UInt32(value)
            return KeyboardShortcut.sanitizedCarbonModifiers(candidate)
        }()

        launchAtLogin = defaults.bool(forKey: SettingKeys.launchAtLogin)
        let storedThemeRawValue = defaults.string(forKey: SettingKeys.appThemePreset)
        if let storedThemePreset = AppThemePreset.resolved(fromStoredRawValue: storedThemeRawValue) {
            appThemePreset = storedThemePreset
            if storedThemeRawValue != storedThemePreset.rawValue {
                defaults.set(storedThemePreset.rawValue, forKey: SettingKeys.appThemePreset)
            }
        } else {
            appThemePreset = .defaultValue
            defaults.set(AppThemePreset.defaultValue.rawValue, forKey: SettingKeys.appThemePreset)
        }
        let storedOrderVersion = defaults.integer(forKey: SettingKeys.sectionTitlesOrderVersion)
        let persistedSectionTitles = defaults.stringArray(forKey: SettingKeys.sectionTitles) ?? []
        let migratedSectionTitles = Self.migrateLegacySectionTitleOrder(
            persistedSectionTitles,
            storedVersion: storedOrderVersion
        )
        sectionTitles = Self.normalizedSectionTitles(migratedSectionTitles)
        markdownEntrySeparatorStyle = MarkdownEntrySeparatorStyle(
            rawValue: defaults.string(forKey: SettingKeys.markdownEntrySeparatorStyle) ?? ""
        ) ?? .horizontalRule
        if storedOrderVersion < Self.currentSectionTitleOrderVersion {
            defaults.set(Self.currentSectionTitleOrderVersion, forKey: SettingKeys.sectionTitlesOrderVersion)
        }
        if let storedPreset = DailyEntryThemePreset(
            rawValue: defaults.string(forKey: SettingKeys.dailyEntryThemePreset) ?? ""
        ) {
            dailyEntryThemePreset = storedPreset
        } else {
            dailyEntryThemePreset = .plainTextTimestamp
            defaults.set(dailyEntryThemePreset.rawValue, forKey: SettingKeys.dailyEntryThemePreset)
        }

        normalizePanelShortcutCollisionsIfNeeded()
    }

    var hasVaultPath: Bool {
        !vaultPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var vaultPathValidationIssue: VaultPathValidationIssue? {
        let trimmedPath = vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return .empty }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: trimmedPath, isDirectory: &isDirectory) else {
            return .doesNotExist
        }

        guard isDirectory.boolValue else {
            return .notDirectory
        }

        guard fileManager.isWritableFile(atPath: trimmedPath) else {
            return .notWritable
        }

        return nil
    }

    var hasValidVaultPath: Bool {
        vaultPathValidationIssue == nil
    }

    var appTheme: TraceTheme {
        appThemePreset.theme
    }

    func savedPanelFrame() -> NSRect? {
        guard defaults.object(forKey: SettingKeys.panelOriginX) != nil,
              defaults.object(forKey: SettingKeys.panelOriginY) != nil,
              defaults.object(forKey: SettingKeys.panelWidth) != nil,
              defaults.object(forKey: SettingKeys.panelHeight) != nil else {
            return nil
        }

        let x = defaults.double(forKey: SettingKeys.panelOriginX)
        let y = defaults.double(forKey: SettingKeys.panelOriginY)
        let width = defaults.double(forKey: SettingKeys.panelWidth)
        let height = defaults.double(forKey: SettingKeys.panelHeight)

        return NSRect(x: x, y: y, width: width, height: height)
    }

    func savePanelFrame(_ frame: NSRect) {
        defaults.set(frame.origin.x, forKey: SettingKeys.panelOriginX)
        defaults.set(frame.origin.y, forKey: SettingKeys.panelOriginY)
        defaults.set(frame.size.width, forKey: SettingKeys.panelWidth)
        defaults.set(frame.size.height, forKey: SettingKeys.panelHeight)
    }

    func title(for section: NoteSection) -> String {
        let index = max(0, min(section.rawValue - 1, sectionTitles.count - 1))
        return sectionTitles[index]
    }

    func header(for section: NoteSection) -> String {
        "# \(title(for: section))"
    }

    func setTitle(_ title: String, for section: NoteSection) {
        let index = section.rawValue - 1
        guard sectionTitles.indices.contains(index) else { return }
        var updated = sectionTitles
        updated[index] = title
        sectionTitles = updated
    }

    func resetSectionTitlesToDefault() {
        sectionTitles = Self.defaultSectionTitles
    }

    func resetShortcutSettingsToDefault() {
        hotKeyCode = Self.defaultGlobalHotKeyCode
        hotKeyModifiers = Self.defaultGlobalHotKeyModifiers
        sendNoteKeyCode = Self.defaultSendNoteKeyCode
        sendNoteModifiers = Self.defaultSendNoteModifiers
        appendNoteKeyCode = Self.defaultAppendNoteKeyCode
        appendNoteModifiers = Self.defaultAppendNoteModifiers
        modeToggleKeyCode = Self.defaultModeToggleKeyCode
        modeToggleModifiers = Self.defaultModeToggleModifiers
    }

    private func normalizePanelShortcutCollisionsIfNeeded() {
        guard sendNoteKeyCode == appendNoteKeyCode,
              sendNoteModifiers == appendNoteModifiers else {
            return
        }

        appendNoteKeyCode = Self.defaultAppendNoteKeyCode
        appendNoteModifiers = Self.defaultAppendNoteModifiers
    }

    private static var defaultSectionTitles: [String] {
        NoteSection.allCases.map(\.defaultTitle)
    }

    private static func normalizedSectionTitles(_ titles: [String]) -> [String] {
        NoteSection.allCases.enumerated().map { index, section in
            let candidate = index < titles.count ? titles[index] : ""
            let migrated = migrateLegacySectionTitle(candidate, for: section)
            return normalizedSectionTitle(migrated, fallback: section.defaultTitle)
        }
    }

    private static func migrateLegacySectionTitleOrder(_ titles: [String], storedVersion: Int) -> [String] {
        guard storedVersion < currentSectionTitleOrderVersion else { return titles }
        guard titles.count >= 5 else { return titles }

        var migrated = titles
        migrated.swapAt(3, 4)
        return migrated
    }

    private static func migrateLegacySectionTitle(_ title: String, for section: NoteSection) -> String {
        guard section == .project else { return title }

        let compacted = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        if compacted == "TODO" {
            return NoteSection.project.defaultTitle
        }

        return title
    }

    private static func normalizedSectionTitle(_ rawTitle: String, fallback: String) -> String {
        let singleLine = rawTitle
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        let withoutHeadingMarks = singleLine.replacingOccurrences(
            of: #"^#+\s*"#,
            with: "",
            options: .regularExpression
        )
        let trimmed = withoutHeadingMarks.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func defaultLegacyDefaults(for defaults: UserDefaults) -> UserDefaults? {
        defaults === UserDefaults.standard ? UserDefaults(suiteName: LegacySettingKeys.bundleIdentifier) : nil
    }

    private static func migrateLegacyDefaultsIfNeeded(
        into defaults: UserDefaults,
        legacyDefaults: UserDefaults?
    ) {
        let legacyPairs = [
            (SettingKeys.vaultPath, LegacySettingKeys.vaultPath),
            (SettingKeys.dailyFolderName, LegacySettingKeys.dailyFolderName),
            (SettingKeys.dailyFileDateFormat, LegacySettingKeys.dailyFileDateFormat),
            (SettingKeys.noteWriteMode, LegacySettingKeys.noteWriteMode),
            (SettingKeys.inboxFolderName, LegacySettingKeys.inboxFolderName),
            (SettingKeys.hotKeyCode, LegacySettingKeys.hotKeyCode),
            (SettingKeys.hotKeyModifiers, LegacySettingKeys.hotKeyModifiers),
            (SettingKeys.sendNoteKeyCode, LegacySettingKeys.sendNoteKeyCode),
            (SettingKeys.sendNoteModifiers, LegacySettingKeys.sendNoteModifiers),
            (SettingKeys.appendNoteKeyCode, LegacySettingKeys.appendNoteKeyCode),
            (SettingKeys.appendNoteModifiers, LegacySettingKeys.appendNoteModifiers),
            (SettingKeys.launchAtLogin, LegacySettingKeys.launchAtLogin),
            (SettingKeys.panelOriginX, LegacySettingKeys.panelOriginX),
            (SettingKeys.panelOriginY, LegacySettingKeys.panelOriginY),
            (SettingKeys.panelWidth, LegacySettingKeys.panelWidth),
            (SettingKeys.panelHeight, LegacySettingKeys.panelHeight),
            (SettingKeys.sectionTitles, LegacySettingKeys.sectionTitles),
            (SettingKeys.sectionTitlesOrderVersion, LegacySettingKeys.sectionTitlesOrderVersion),
            (SettingKeys.markdownEntrySeparatorStyle, LegacySettingKeys.markdownEntrySeparatorStyle)
        ]

        for (newKey, oldKey) in legacyPairs {
            migrateLegacyValueIfNeeded(into: defaults, newKey: newKey, oldKey: oldKey, legacyDefaults: legacyDefaults)
        }

        if defaults.object(forKey: SettingKeys.appThemePreset) == nil {
            if let legacyThemeRawValue = legacyString(
                forKey: LegacySettingKeys.appThemePreset,
                in: defaults,
                legacyDefaults: legacyDefaults
            ), let resolvedThemePreset = AppThemePreset.resolved(fromStoredRawValue: legacyThemeRawValue) {
                defaults.set(resolvedThemePreset.rawValue, forKey: SettingKeys.appThemePreset)
            } else if let migratedThemePreset = AppThemePreset.migrated(
                fromLegacyCaptureAppearance: legacyString(
                    forKey: LegacySettingKeys.captureAppearance,
                    in: defaults,
                    legacyDefaults: legacyDefaults
                )
            ) {
                defaults.set(migratedThemePreset.rawValue, forKey: SettingKeys.appThemePreset)
            }
        }

        if defaults.object(forKey: SettingKeys.dailyEntryThemePreset) == nil {
            if let legacyThemeRawValue = legacyString(
                forKey: LegacySettingKeys.dailyEntryThemePreset,
                in: defaults,
                legacyDefaults: legacyDefaults
            ), DailyEntryThemePreset(rawValue: legacyThemeRawValue) != nil {
                defaults.set(legacyThemeRawValue, forKey: SettingKeys.dailyEntryThemePreset)
            } else {
                let legacyContainer = LegacyDailyEntryContainerStyle(
                    rawValue: legacyString(
                        forKey: LegacySettingKeys.dailyEntryContainerStyle,
                        in: defaults,
                        legacyDefaults: legacyDefaults
                    ) ?? ""
                ) ?? .codeBlock
                let legacyCardTheme = LegacyDailyCardTheme(
                    rawValue: legacyString(
                        forKey: LegacySettingKeys.dailyCardTheme,
                        in: defaults,
                        legacyDefaults: legacyDefaults
                    ) ?? ""
                ) ?? .anthropic
                let migratedPreset = DailyEntryThemePreset.migrated(
                    from: legacyContainer,
                    legacyCardTheme: legacyCardTheme
                )
                defaults.set(migratedPreset.rawValue, forKey: SettingKeys.dailyEntryThemePreset)
            }
        }
    }

    private static func migrateLegacyValueIfNeeded(
        into defaults: UserDefaults,
        newKey: String,
        oldKey: String,
        legacyDefaults: UserDefaults?
    ) {
        guard defaults.object(forKey: newKey) == nil else { return }
        guard let legacyValue = legacyObject(forKey: oldKey, in: defaults, legacyDefaults: legacyDefaults) else { return }
        defaults.set(legacyValue, forKey: newKey)
    }

    private static func legacyObject(
        forKey key: String,
        in defaults: UserDefaults,
        legacyDefaults: UserDefaults?
    ) -> Any? {
        defaults.object(forKey: key) ?? legacyDefaults?.object(forKey: key)
    }

    private static func legacyString(
        forKey key: String,
        in defaults: UserDefaults,
        legacyDefaults: UserDefaults?
    ) -> String? {
        legacyObject(forKey: key, in: defaults, legacyDefaults: legacyDefaults) as? String
    }

    private func updateLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }

        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Launch at login update failed: \(error.localizedDescription)")
        }
    }
}

extension AppSettings: DailyNoteSettingsProviding {}
