import Foundation
import XCTest
@testable import Trace

final class DailyNoteWriterTests: XCTestCase {
    func testSaveThrowsWhenVaultPathMissing() {
        let settings = TestSettings(vaultPath: "", dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        let writer = DailyNoteWriter(settings: settings)

        XCTAssertThrowsError(try writer.save(text: "hello", to: .note)) { error in
            XCTAssertEqual(error as? DailyNoteWriterError, .invalidVaultPath)
        }
    }

    func testSaveCreatesDailyFileOnlyForTargetSectionAndInsertsEntry() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fixedDate = makeDate(year: 2026, month: 2, day: 27, hour: 22, minute: 35)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .codeBlockClassic
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "first note", to: .clip, now: fixedDate)

        let fileURL = try writer.dailyNoteFileURL(for: fixedDate)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(content.contains("# Clip"))
        XCTAssertFalse(content.contains("# Note"))
        XCTAssertFalse(content.contains("# Link"))
        XCTAssertFalse(content.contains("# Project"))
        XCTAssertFalse(content.contains("# Task"))
        XCTAssertTrue(content.contains("# Clip\n\n```"))

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let expectedTimestamp = formatter.string(from: fixedDate)
        XCTAssertTrue(content.contains("```\nfirst note\n\(expectedTimestamp)\n```"))
    }

    func testFileModeCreatesStandaloneMarkdownDocumentInInboxFolderWhenTitleIsEmpty() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fixedDate = makeDate(year: 2026, month: 3, day: 5, hour: 10, minute: 34)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.noteWriteMode = .file
        settings.inboxFolderName = "inbox"
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "快速记录一条想法", to: .project, documentTitle: "", now: fixedDate)

        let inboxURL = tempDir.appendingPathComponent("inbox", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].pathExtension, "md")
        XCTAssertTrue(
            files[0].lastPathComponent.range(
                of: #"^\d{4}-\d{2}-\d{2}-\d{6}\.md$"#,
                options: .regularExpression
            ) != nil
        )

        let content = try String(contentsOf: files[0], encoding: .utf8)
        XCTAssertFalse(content.contains("section:"))
        XCTAssertTrue(content.contains("created: \"\(timestamp(from: fixedDate))\""))
        XCTAssertTrue(content.contains("快速记录一条想法"))
    }

    func testFileModeUsesTitleAsFileNameAndAddsSequenceOnCollision() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fixedDate = makeDate(year: 2026, month: 3, day: 5, hour: 10, minute: 34)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.noteWriteMode = .file
        settings.inboxFolderName = "inbox"
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "文档 A", to: .note, documentTitle: "项目复盘", now: fixedDate)
        try writer.save(text: "文档 B", to: .note, documentTitle: "项目复盘", now: fixedDate)

        let inboxURL = tempDir.appendingPathComponent("inbox", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 2)

        let names = files.map(\.lastPathComponent).sorted()
        XCTAssertEqual(names, ["项目复盘-2.md", "项目复盘.md"])
    }

    func testFileModeRespectsCustomRelativeTargetFolder() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fixedDate = makeDate(year: 2026, month: 3, day: 5, hour: 10, minute: 34)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.noteWriteMode = .file
        settings.inboxFolderName = "inbox"
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(
            text: "route check",
            to: .note,
            documentTitle: "routing",
            fileTargetFolder: "projects/trace",
            now: fixedDate
        )

        let targetURL = tempDir
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent("trace", isDirectory: true)
            .appendingPathComponent("routing.md", isDirectory: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path))
    }

    func testFileModeRejectsPathTraversalInTargetFolder() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fixedDate = makeDate(year: 2026, month: 3, day: 5, hour: 10, minute: 34)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.noteWriteMode = .file
        settings.inboxFolderName = "inbox"
        let writer = DailyNoteWriter(settings: settings)

        XCTAssertThrowsError(
            try writer.save(
                text: "route check",
                to: .note,
                documentTitle: "routing",
                fileTargetFolder: "../outside",
                now: fixedDate
            )
        ) { error in
            XCTAssertEqual(error as? DailyNoteWriterError, .invalidTargetFolderPath)
        }
    }

    func testSaveRepairsMissingSectionThenInserts() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fixedDate = makeDate(year: 2026, month: 2, day: 27, hour: 12, minute: 0)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .codeBlockClassic
        let writer = DailyNoteWriter(settings: settings)

        let fileURL = try writer.dailyNoteFileURL(for: fixedDate)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "# Note\n\n# Clip\n".write(to: fileURL, atomically: true, encoding: .utf8)

        try writer.save(text: "project idea", to: .project, now: fixedDate)

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("# Project"))
        XCTAssertTrue(content.contains("# Project\n\n```"))
        XCTAssertTrue(content.contains("project idea"))
    }

    func testAppendToLatestEntryKeepsSingleCodeBlock() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let firstDate = makeDate(year: 2026, month: 3, day: 2, hour: 11, minute: 34)
        let secondDate = makeDate(year: 2026, month: 3, day: 2, hour: 11, minute: 48)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .codeBlockClassic
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "first thought", to: .note, now: firstDate)
        try writer.save(text: "second thought", to: .note, mode: .appendToLatestEntry, now: secondDate)

        let fileURL = try writer.dailyNoteFileURL(for: firstDate)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        let firstTimestamp = timestamp(from: firstDate)
        let secondTimestamp = timestamp(from: secondDate)
        XCTAssertTrue(content.contains("first thought\n\(firstTimestamp)\n---\nsecond thought\n\(secondTimestamp)\n```"))
        XCTAssertEqual(countOccurrences(of: "```", in: content), 2)
    }

    func testAppendToLatestFallsBackToCreateEntryWhenSectionHasNoCodeBlock() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let date = makeDate(year: 2026, month: 3, day: 2, hour: 12, minute: 0)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .codeBlockClassic
        let writer = DailyNoteWriter(settings: settings)

        let fileURL = try writer.dailyNoteFileURL(for: date)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "# Note\nmanual text only\n\n# Clip\n".write(to: fileURL, atomically: true, encoding: .utf8)

        try writer.save(text: "append fallback", to: .note, mode: .appendToLatestEntry, now: date)

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("```\nappend fallback\n\(timestamp(from: date))\n```"))
    }

    func testCalloutCardWritesTimestampAtBottomInMutedStyle() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let date = makeDate(year: 2026, month: 3, day: 3, hour: 21, minute: 30)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .anthropic
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "visual focus first", to: .note, now: date)

        let fileURL = try writer.dailyNoteFileURL(for: date)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let expectedTimestamp = timestamp(from: date)

        XCTAssertTrue(content.contains("> [!warning|trace-anthropic]"))
        XCTAssertTrue(content.contains("trace-marker"))
        XCTAssertTrue(content.contains("> visual focus first"))
        XCTAssertTrue(content.contains("> <span class=\"trace-time\" style=\"color: var(--text-muted); font-size: 0.86em;\">\(expectedTimestamp)</span>"))
        XCTAssertFalse(content.contains("```\n"))
    }

    func testAppendInCalloutModeAppendsIntoLatestCard() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let firstDate = makeDate(year: 2026, month: 3, day: 3, hour: 21, minute: 40)
        let secondDate = makeDate(year: 2026, month: 3, day: 3, hour: 21, minute: 45)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .obsidian
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "card 1", to: .note, now: firstDate)
        try writer.save(text: "card 2", to: .note, mode: .appendToLatestEntry, now: secondDate)

        let fileURL = try writer.dailyNoteFileURL(for: firstDate)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertEqual(countOccurrences(of: "> [!example|trace-obsidian]", in: content), 1)
        XCTAssertTrue(content.contains("> ---\n> card 2\n>\n> <span class=\"trace-time\""))
        XCTAssertFalse(content.contains("```"))
    }

    func testAppendInCalloutModeTargetsLatestCardWhenSectionHasMultipleCards() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let firstDate = makeDate(year: 2026, month: 3, day: 3, hour: 22, minute: 1)
        let secondDate = makeDate(year: 2026, month: 3, day: 3, hour: 22, minute: 2)
        let appendDate = makeDate(year: 2026, month: 3, day: 3, hour: 22, minute: 3)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .notion
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "card A", to: .note, now: firstDate)
        try writer.save(text: "card B", to: .note, now: secondDate)
        try writer.save(text: "card C", to: .note, mode: .appendToLatestEntry, now: appendDate)

        let fileURL = try writer.dailyNoteFileURL(for: firstDate)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        guard let newestHeaderRange = content.range(of: "> [!quote|trace-notion]") else {
            return XCTFail("Missing newest callout header")
        }

        guard let olderHeaderRange = content[newestHeaderRange.upperBound...].range(of: "> [!quote|trace-notion]") else {
            return XCTFail("Missing older callout header")
        }

        guard let appendedRange = content.range(of: "> ---\n> card C\n>", options: .backwards) else {
            return XCTFail("Missing appended chunk")
        }

        XCTAssertTrue(appendedRange.lowerBound > newestHeaderRange.lowerBound)
        XCTAssertTrue(appendedRange.lowerBound < olderHeaderRange.lowerBound)
        XCTAssertNotEqual(olderHeaderRange.lowerBound, content.startIndex)
        let characterBeforeOlderHeader = content[content.index(before: olderHeaderRange.lowerBound)]
        XCTAssertEqual(
            characterBeforeOlderHeader,
            "\n",
            "Next callout header should start on a new line after appended chunk."
        )
    }

    func testMarkdownQuoteWritesPlainTimestampWithoutInlineCSS() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let date = makeDate(year: 2026, month: 3, day: 3, hour: 23, minute: 25)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .markdownQuote
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "quote body", to: .note, now: date)

        let fileURL = try writer.dailyNoteFileURL(for: date)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let expectedTimestamp = timestamp(from: date)

        XCTAssertTrue(content.contains("> quote body"))
        XCTAssertTrue(content.contains("> \(expectedTimestamp)"))
        XCTAssertFalse(content.contains("trace-time"))
        XCTAssertFalse(content.contains("[!"))
    }

    func testPlainTextTimestampWritesTextAndTimestampWithoutWrapper() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let date = makeDate(year: 2026, month: 3, day: 4, hour: 9, minute: 40)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .plainTextTimestamp
        settings.markdownEntrySeparatorStyle = .horizontalRule
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "plain body", to: .note, now: date)

        let fileURL = try writer.dailyNoteFileURL(for: date)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(content.contains("plain body\n\(timestamp(from: date))"))
        XCTAssertTrue(content.contains("\n---\n"))
        XCTAssertFalse(content.contains("```"))
        XCTAssertFalse(content.contains("> "))
        XCTAssertFalse(content.contains("[!"))
    }

    func testAppendInPlainTextTimestampModeAppendsUnderLatestTimestamp() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let firstDate = makeDate(year: 2026, month: 3, day: 4, hour: 9, minute: 41)
        let secondDate = makeDate(year: 2026, month: 3, day: 4, hour: 9, minute: 42)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .plainTextTimestamp
        settings.markdownEntrySeparatorStyle = .none
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "entry A", to: .note, now: firstDate)
        try writer.save(text: "entry B", to: .note, mode: .appendToLatestEntry, now: secondDate)

        let fileURL = try writer.dailyNoteFileURL(for: firstDate)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(content.contains("entry A\n\(timestamp(from: firstDate))\n---\nentry B\n\(timestamp(from: secondDate))"))
        XCTAssertFalse(content.contains("```"))
        XCTAssertFalse(content.contains("[!"))
    }

    func testAppendInMarkdownQuoteModeTargetsLatestQuoteBlock() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let firstDate = makeDate(year: 2026, month: 3, day: 3, hour: 23, minute: 26)
        let secondDate = makeDate(year: 2026, month: 3, day: 3, hour: 23, minute: 27)
        let appendDate = makeDate(year: 2026, month: 3, day: 3, hour: 23, minute: 28)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .markdownQuote
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "quote A", to: .note, now: firstDate)
        try writer.save(text: "quote B", to: .note, now: secondDate)
        try writer.save(text: "quote C", to: .note, mode: .appendToLatestEntry, now: appendDate)

        let fileURL = try writer.dailyNoteFileURL(for: firstDate)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        guard let newestQuoteRange = content.range(of: "> quote B") else {
            return XCTFail("Missing newest quote block")
        }

        guard let olderQuoteRange = content.range(of: "> quote A") else {
            return XCTFail("Missing older quote block")
        }

        guard let appendedRange = content.range(of: "> ---\n> quote C\n>", options: .backwards) else {
            return XCTFail("Missing appended quote chunk")
        }

        XCTAssertTrue(appendedRange.lowerBound > newestQuoteRange.lowerBound)
        XCTAssertTrue(appendedRange.lowerBound < olderQuoteRange.lowerBound)
    }

    func testMarkdownSeparatorStyleHorizontalRuleIsRenderedForCodeBlock() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let date = makeDate(year: 2026, month: 3, day: 3, hour: 23, minute: 31)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .codeBlockClassic
        settings.markdownEntrySeparatorStyle = .horizontalRule
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "separator test", to: .note, now: date)

        let fileURL = try writer.dailyNoteFileURL(for: date)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("```\nseparator test\n\(timestamp(from: date))\n```\n\n---"))
    }

    func testMarkdownSeparatorStyleNoneSkipsDividerForMarkdownQuote() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let date = makeDate(year: 2026, month: 3, day: 3, hour: 23, minute: 32)
        var settings = TestSettings(vaultPath: tempDir.path, dailyFolderName: "Daily", dailyFileDateFormat: "yyyy-MM-dd")
        settings.dailyEntryThemePreset = .markdownQuote
        settings.markdownEntrySeparatorStyle = .none
        let writer = DailyNoteWriter(settings: settings)

        try writer.save(text: "no separator", to: .note, now: date)

        let fileURL = try writer.dailyNoteFileURL(for: date)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(content.contains("\n---\n"))
        XCTAssertFalse(content.contains("\n***\n"))
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return components.date!
    }

    private func timestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func countOccurrences(of token: String, in content: String) -> Int {
        content.components(separatedBy: token).count - 1
    }
}

private struct TestSettings: DailyNoteSettingsProviding {
    let vaultPath: String
    let dailyFolderName: String
    let dailyFileDateFormat: String
    var noteWriteMode: NoteWriteMode = .dimension
    var inboxFolderName: String = "inbox"
    var dailyEntryThemePreset: DailyEntryThemePreset = .plainTextTimestamp
    var markdownEntrySeparatorStyle: MarkdownEntrySeparatorStyle = .horizontalRule

    func title(for section: NoteSection) -> String {
        section.defaultTitle
    }

    func header(for section: NoteSection) -> String {
        "# \(title(for: section))"
    }
}
