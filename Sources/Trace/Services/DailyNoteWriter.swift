import Foundation

protocol DailyNoteSettingsProviding {
    var vaultPath: String { get }
    var dailyFolderName: String { get }
    var dailyFileDateFormat: String { get }
    var noteWriteMode: NoteWriteMode { get }
    var inboxFolderName: String { get }
    var dailyEntryThemePreset: DailyEntryThemePreset { get }
    var markdownEntrySeparatorStyle: MarkdownEntrySeparatorStyle { get }
    func title(for section: NoteSection) -> String
    func header(for section: NoteSection) -> String
}

enum DailyNoteSaveMode {
    case createNewEntry
    case appendToLatestEntry
}

enum DailyNoteWriterError: LocalizedError, Equatable {
    case invalidVaultPath
    case invalidTargetFolderPath

    var errorDescription: String? {
        switch self {
        case .invalidVaultPath:
            return "Vault 路径未配置。"
        case .invalidTargetFolderPath:
            return "目标目录必须是 Vault 内的相对路径，且不能包含 .."
        }
    }
}

final class DailyNoteWriter {
    private let settings: DailyNoteSettingsProviding
    private let fileManager: FileManager

    init(settings: DailyNoteSettingsProviding, fileManager: FileManager = .default) {
        self.settings = settings
        self.fileManager = fileManager
    }

    func save(
        text: String,
        to section: NoteSection,
        mode: DailyNoteSaveMode = .createNewEntry,
        documentTitle: String? = nil,
        fileTargetFolder: String? = nil,
        now: Date = Date()
    ) throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        switch settings.noteWriteMode {
        case .dimension:
            try saveToDailyNote(trimmedText, to: section, mode: mode, now: now)
        case .file:
            try saveToInboxFile(
                trimmedText,
                title: documentTitle,
                targetFolder: fileTargetFolder,
                now: now
            )
        }
    }

    private func saveToDailyNote(
        _ text: String,
        to section: NoteSection,
        mode: DailyNoteSaveMode,
        now: Date
    ) throws {
        let dailyNoteURL = try dailyNoteFileURL(for: now)
        try ensureDailyDirectoryExists(at: dailyNoteURL.deletingLastPathComponent())

        let content = try loadOrCreateContent(for: dailyNoteURL)
        let updated: String

        switch mode {
        case .createNewEntry:
            updated = insert(entryForText(text, at: now), into: content, under: section)
        case .appendToLatestEntry:
            if let appended = appendLatestEntry(text, at: now, into: content, under: section) {
                updated = appended
            } else {
                updated = insert(entryForText(text, at: now), into: content, under: section)
            }
        }

        try updated.write(to: dailyNoteURL, atomically: true, encoding: .utf8)
    }

    func dailyNoteFileURL(for date: Date = Date()) throws -> URL {
        let vaultURL = try vaultURL()
        let dailyFolderName = normalizedFolderName(settings.dailyFolderName, fallback: "Daily")
        let dailyDirectoryURL = vaultURL.appendingPathComponent(dailyFolderName, isDirectory: true)
        let fileName = formattedFileName(for: date)

        return dailyDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    private func saveToInboxFile(
        _ text: String,
        title: String?,
        targetFolder: String?,
        now: Date
    ) throws {
        let fileURL = try inboxFileURL(for: now, title: title, targetFolder: targetFolder)
        try ensureDailyDirectoryExists(at: fileURL.deletingLastPathComponent())

        let content = inboxDocumentContent(for: text, title: title, at: now)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func inboxFileURL(for date: Date, title: String?, targetFolder: String?) throws -> URL {
        let vaultURL = try vaultURL()
        let fallbackFolderName = normalizedFolderName(settings.inboxFolderName, fallback: "inbox")
        let folderName = try normalizedRelativeFolderPath(targetFolder, fallback: fallbackFolderName)
        let inboxDirectoryURL = vaultURL.appendingPathComponent(folderName, isDirectory: true)
        let baseName = fileBaseName(for: title, at: date)
        return nextAvailableFileURL(baseName: baseName, in: inboxDirectoryURL)
    }

    private func nextAvailableFileURL(baseName: String, in directoryURL: URL) -> URL {
        var candidate = directoryURL.appendingPathComponent("\(baseName).md", isDirectory: false)
        var sequence = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directoryURL.appendingPathComponent("\(baseName)-\(sequence).md", isDirectory: false)
            sequence += 1
        }

        return candidate
    }

    private func inboxDocumentContent(for text: String, title: String?, at date: Date) -> String {
        let escapedTitle = normalizedDocumentTitle(title)?
            .replacingOccurrences(of: "\"", with: "\\\"")
        var frontmatterLines: [String] = []
        if let escapedTitle {
            frontmatterLines.append("title: \"\(escapedTitle)\"")
        }
        frontmatterLines.append("created: \"\(timestamp(for: date))\"")
        let frontmatterBody = frontmatterLines.joined(separator: "\n")
        return """
        ---
        \(frontmatterBody)
        ---

        \(text)
        """
    }

    private func vaultURL() throws -> URL {
        let trimmedVaultPath = settings.vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVaultPath.isEmpty else {
            throw DailyNoteWriterError.invalidVaultPath
        }
        return URL(fileURLWithPath: trimmedVaultPath, isDirectory: true)
    }

    private func normalizedFolderName(_ folderName: String, fallback: String) -> String {
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func normalizedRelativeFolderPath(_ folderPath: String?, fallback: String) throws -> String {
        let raw = folderPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let selected = raw.isEmpty ? fallback : raw
        let stripped = selected
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let components = stripped
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        if components.isEmpty {
            return fallback
        }

        for component in components {
            if component == "." || component == ".." {
                throw DailyNoteWriterError.invalidTargetFolderPath
            }
        }

        return components.joined(separator: "/")
    }

    private func fileBaseName(for title: String?, at date: Date) -> String {
        if let normalizedTitle = normalizedFileNameSegment(title), !normalizedTitle.isEmpty {
            return normalizedTitle
        }
        return fileNameTimestampWithoutMilliseconds(for: date)
    }

    private func normalizedDocumentTitle(_ title: String?) -> String? {
        guard let title else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedFileNameSegment(_ title: String?) -> String? {
        guard let normalizedTitle = normalizedDocumentTitle(title) else { return nil }

        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let replaced = normalizedTitle
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let collapsed = replaced
            .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
            .replacingOccurrences(of: #"-{2,}"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-. "))
        return collapsed.isEmpty ? nil : collapsed
    }

    private func ensureDailyDirectoryExists(at directoryURL: URL) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func loadOrCreateContent(for fileURL: URL) throws -> String {
        if fileManager.fileExists(atPath: fileURL.path) {
            return try String(contentsOf: fileURL, encoding: .utf8)
        }

        return ""
    }

    private func insert(_ entry: String, into content: String, under section: NoteSection) -> String {
        var mutableContent = content
        let header = settings.header(for: section)

        if let headerRange = mutableContent.range(of: header) {
            let afterHeaderIndex = headerRange.upperBound
            let lineBreakIndex = mutableContent[afterHeaderIndex...].firstIndex(of: "\n") ?? mutableContent.endIndex
            let insertIndex = lineBreakIndex == mutableContent.endIndex
                ? mutableContent.endIndex
                : mutableContent.index(after: lineBreakIndex)
            let prefix: String
            if insertIndex < mutableContent.endIndex {
                prefix = mutableContent[insertIndex] == "\n" ? "" : "\n"
            } else {
                prefix = lineBreakIndex == mutableContent.endIndex ? "\n\n" : "\n"
            }
            mutableContent.insert(contentsOf: "\(prefix)\(entry)", at: insertIndex)
            return mutableContent
        }

        if mutableContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(header)\n\n\(entry)"
        }

        if !mutableContent.hasSuffix("\n") {
            mutableContent.append("\n")
        }

        mutableContent.append("\n\(header)\n\n")
        mutableContent.append(entry)
        return mutableContent
    }

    private func entryForText(_ text: String, at date: Date) -> String {
        switch settings.dailyEntryThemePreset {
        case .plainTextTimestamp:
            return markdownEntry(plainTextBodyForText(text, at: date))
        case .codeBlockClassic:
            let body = "```\n\(text)\n\(timestamp(for: date))\n```"
            return markdownEntry(body)
        case .markdownQuote:
            return markdownEntry(markdownQuoteBodyForText(text, at: date))
        case .linear, .notion, .obsidian, .anthropic, .openAI:
            return calloutEntryForText(text, at: date)
        }
    }

    private func appendLatestEntry(_ text: String, at date: Date, into content: String, under section: NoteSection) -> String? {
        switch settings.dailyEntryThemePreset {
        case .plainTextTimestamp:
            return appendLatestPlainTextEntry(text, at: date, into: content, under: section)
        case .codeBlockClassic:
            return appendLatestCodeBlockEntry(text, at: date, into: content, under: section)
        case .markdownQuote:
            return appendLatestMarkdownQuoteEntry(text, at: date, into: content, under: section)
        case .linear, .notion, .obsidian, .anthropic, .openAI:
            return appendLatestCalloutEntry(text, at: date, into: content, under: section)
        }
    }

    private func appendLatestCodeBlockEntry(_ text: String, at date: Date, into content: String, under section: NoteSection) -> String? {
        guard let sectionBodyRange = sectionBodyRange(in: content, under: section) else {
            return nil
        }

        let sectionBody = content[sectionBodyRange]
        guard let openingFenceRange = sectionBody.range(of: "```") else {
            return nil
        }

        guard let closingFenceRange = sectionBody[openingFenceRange.upperBound...].range(of: "```") else {
            return nil
        }

        let insertionIndex = closingFenceRange.lowerBound
        let prefix = insertionIndex > content.startIndex && content[content.index(before: insertionIndex)] == "\n"
            ? ""
            : "\n"
        let appendedChunk = "\(prefix)---\n\(text)\n\(timestamp(for: date))\n"

        var mutableContent = content
        mutableContent.insert(contentsOf: appendedChunk, at: insertionIndex)
        return mutableContent
    }

    private func calloutEntryForText(_ text: String, at date: Date) -> String {
        guard let themeType = settings.dailyEntryThemePreset.calloutType else {
            return "```\n\(text)\n\(timestamp(for: date))\n```\n\n"
        }
        let marker = "trace-\(settings.dailyEntryThemePreset.rawValue)"
        let header = "> [!\(themeType)|\(marker)]"
        let body = quotedText(from: text)
        let mutedTimestamp = "<span class=\"trace-time\" style=\"color: var(--text-muted); font-size: 0.86em;\">\(timestamp(for: date))</span>"
        return """
        \(header)
        > <span class="trace-marker" style="display:none;">\(marker)</span>
        \(body)
        >
        > \(mutedTimestamp)


        """
    }

    private func quotedText(from text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { line in
                line.isEmpty ? ">" : "> \(line)"
            }
            .joined(separator: "\n")
    }

    private func markdownQuoteBodyForText(_ text: String, at date: Date) -> String {
        let body = quotedText(from: text)
        return """
        \(body)
        >
        > \(timestamp(for: date))
        """
    }

    private func plainTextBodyForText(_ text: String, at date: Date) -> String {
        "\(text)\n\(timestamp(for: date))"
    }

    private func markdownEntry(_ body: String) -> String {
        guard let separator = settings.markdownEntrySeparatorStyle.markdown else {
            return "\(body)\n\n"
        }
        return "\(body)\n\n\(separator)\n\n"
    }

    private func appendLatestPlainTextEntry(_ text: String, at date: Date, into content: String, under section: NoteSection) -> String? {
        guard let sectionBodyRange = sectionBodyRange(in: content, under: section) else {
            return nil
        }

        let sectionBody = content[sectionBodyRange]
        guard let latestTimestampRange = sectionBody.range(
            of: #"(?m)^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let insertionIndex = latestTimestampRange.upperBound
        let appendedChunk = "\n---\n\(text)\n\(timestamp(for: date))"

        var mutableContent = content
        mutableContent.insert(contentsOf: appendedChunk, at: insertionIndex)
        return mutableContent
    }

    private func appendLatestCalloutEntry(_ text: String, at date: Date, into content: String, under section: NoteSection) -> String? {
        guard let sectionBodyRange = sectionBodyRange(in: content, under: section) else {
            return nil
        }

        let sectionBody = content[sectionBodyRange]
        guard let calloutStart = firstCalloutStart(in: sectionBody) else {
            return nil
        }

        let calloutEnd = calloutBlockEnd(in: sectionBody, from: calloutStart)
        let insertionIndex = calloutEnd
        let appendedBody = quotedText(from: text)
        let mutedTimestamp = "<span class=\"trace-time\" style=\"color: var(--text-muted); font-size: 0.86em;\">\(timestamp(for: date))</span>"
        let chunk = "\n> ---\n\(appendedBody)\n>\n> \(mutedTimestamp)\n"

        var mutableContent = content
        mutableContent.insert(contentsOf: chunk, at: insertionIndex)
        return mutableContent
    }

    private func appendLatestMarkdownQuoteEntry(_ text: String, at date: Date, into content: String, under section: NoteSection) -> String? {
        guard let sectionBodyRange = sectionBodyRange(in: content, under: section) else {
            return nil
        }

        let sectionBody = content[sectionBodyRange]
        guard let quoteStart = firstQuoteBlockStart(in: sectionBody) else {
            return nil
        }

        let quoteEnd = calloutBlockEnd(in: sectionBody, from: quoteStart)
        let insertionIndex = quoteEnd
        let appendedBody = quotedText(from: text)
        let chunk = "\n> ---\n\(appendedBody)\n>\n> \(timestamp(for: date))\n"

        var mutableContent = content
        mutableContent.insert(contentsOf: chunk, at: insertionIndex)
        return mutableContent
    }

    private func firstCalloutStart(in sectionBody: Substring) -> String.Index? {
        var firstAny: String.Index?
        var firstTrace: String.Index?
        var searchStart = sectionBody.startIndex

        if sectionBody.hasPrefix("> [!") {
            firstAny = sectionBody.startIndex
            if isTraceCalloutHeaderLine(in: sectionBody, at: sectionBody.startIndex) {
                firstTrace = sectionBody.startIndex
                return firstTrace
            }
        }

        while searchStart < sectionBody.endIndex,
              let prefixed = sectionBody[searchStart...].range(of: "\n> [!") {
            let start = sectionBody.index(after: prefixed.lowerBound)
            if firstAny == nil {
                firstAny = start
            }
            if isTraceCalloutHeaderLine(in: sectionBody, at: start) {
                firstTrace = start
                break
            }
            searchStart = prefixed.upperBound
        }

        return firstTrace ?? firstAny
    }

    private func isTraceCalloutHeaderLine(in sectionBody: Substring, at start: String.Index) -> Bool {
        let lineEnd = sectionBody[start...].firstIndex(of: "\n") ?? sectionBody.endIndex
        return sectionBody[start..<lineEnd].contains("|trace-")
    }

    private func firstQuoteBlockStart(in sectionBody: Substring) -> String.Index? {
        var lineStart = sectionBody.startIndex

        while lineStart < sectionBody.endIndex {
            let lineBreak = sectionBody[lineStart...].firstIndex(of: "\n")
            let lineEnd = lineBreak ?? sectionBody.endIndex
            let line = sectionBody[lineStart..<lineEnd]
            if line.hasPrefix(">") {
                return lineStart
            }

            guard let lineBreak else { break }
            lineStart = sectionBody.index(after: lineBreak)
        }

        return nil
    }

    private func calloutBlockEnd(in sectionBody: Substring, from start: String.Index) -> String.Index {
        var lineStart = start

        while lineStart < sectionBody.endIndex {
            guard let lineBreak = sectionBody[lineStart...].firstIndex(of: "\n") else {
                let line = sectionBody[lineStart..<sectionBody.endIndex]
                return line.hasPrefix(">") ? sectionBody.endIndex : lineStart
            }

            let line = sectionBody[lineStart..<lineBreak]
            if lineStart != start, line.hasPrefix("> [!") {
                return lineStart
            }
            if !line.hasPrefix(">") {
                return lineStart
            }

            lineStart = sectionBody.index(after: lineBreak)
        }

        return sectionBody.endIndex
    }

    private func sectionBodyRange(in content: String, under section: NoteSection) -> Range<String.Index>? {
        let header = settings.header(for: section)
        guard let headerRange = content.range(of: header) else {
            return nil
        }

        let afterHeaderLineBreak = content[headerRange.upperBound...].firstIndex(of: "\n")
        let sectionStart = afterHeaderLineBreak.map { content.index(after: $0) } ?? content.endIndex

        guard sectionStart < content.endIndex else {
            return sectionStart..<sectionStart
        }

        if let nextHeaderRange = content[sectionStart...].range(of: "\n# ") {
            return sectionStart..<nextHeaderRange.lowerBound
        }

        return sectionStart..<content.endIndex
    }

    private func timestamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func formattedFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = settings.dailyFileDateFormat
        return formatter.string(from: date) + ".md"
    }

    private func fileNameTimestampWithoutMilliseconds(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }
}
