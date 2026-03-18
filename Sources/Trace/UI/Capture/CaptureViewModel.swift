import Foundation

final class CaptureViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var selectedSection: NoteSection = .default
    @Published var fileTitle: String = ""
    @Published var pinned: Bool = false

    func resetInput() {
        text = ""
        fileTitle = ""
    }
}
