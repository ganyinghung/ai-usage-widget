import SwiftUI

@main
struct AIUsageWidgetApp: App {
    @StateObject private var model = UsageViewModel()

    var body: some Scene {
        WindowGroup("AI Usage") {
            UsageWidgetView(model: model) {
                model.refresh()
            }
            .task {
                model.start()
            }
        }
        .defaultSize(width: 420, height: 520)
        .windowResizability(.contentSize)
    }
}
