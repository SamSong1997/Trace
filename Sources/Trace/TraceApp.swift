import SwiftUI

@main
struct TraceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: appDelegate.settings)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    appDelegate.showCapturePanel()
                }
                .keyboardShortcut("n")
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
