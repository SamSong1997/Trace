import Foundation

enum NoteSection: Int, CaseIterable, Identifiable, Codable {
    case note = 1
    case clip = 2
    case link = 3
    case task = 4
    case project = 5

    var id: Int { rawValue }

    var defaultTitle: String {
        switch self {
        case .note:
            return "Note"
        case .clip:
            return "Clip"
        case .link:
            return "Link"
        case .task:
            return "Task"
        case .project:
            return "Project"
        }
    }

    var title: String {
        defaultTitle
    }

    var header: String {
        "# \(defaultTitle)"
    }

    var shortcutLabel: String {
        "⌘\(rawValue)"
    }

    static var `default`: NoteSection {
        .note
    }
}
