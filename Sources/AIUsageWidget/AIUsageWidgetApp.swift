import AppKit
import OSLog
import ServiceManagement
import SwiftUI

@main
struct AIUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(BackgroundAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class BackgroundAppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(
        subsystem: "com.yhgan.AIUsageWidget",
        category: "BackgroundLifecycle"
    )
    private let model = UsageViewModel()
    private var statusWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.start()
        registerLoginItemIfInstalled()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "aiusagewidget" }) else { return }
        showStatusWindow()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag { showStatusWindow() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showStatusWindow() {
        if statusWindowController == nil {
            let rootView = UsageWidgetView(
                model: model,
                refresh: { [weak model] in model?.refresh() },
                quit: { NSApp.terminate(nil) }
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "AI Usage"
            window.contentViewController = NSHostingController(rootView: rootView)
            window.isReleasedWhenClosed = false
            window.center()
            statusWindowController = NSWindowController(window: window)
        }

        statusWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func registerLoginItemIfInstalled() {
        let appPath = Bundle.main.bundleURL.standardizedFileURL.path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .path + "/"
        guard appPath.hasPrefix("/Applications/") || appPath.hasPrefix(userApplications) else {
            logger.info("Skipping login-item registration outside an Applications folder")
            return
        }
        switch SMAppService.mainApp.status {
        case .enabled:
            logger.notice("Login item is enabled")
            return
        case .requiresApproval:
            logger.notice("Login item requires approval in System Settings")
            return
        case .notFound:
            logger.info("Login item is not registered yet")
            break
        case .notRegistered:
            break
        @unknown default:
            logger.error("Login item has an unknown status")
            return
        }
        do {
            try SMAppService.mainApp.register()
            logger.notice("Registered the app to launch at login")
        } catch {
            logger.error("Could not register the login item: \(error.localizedDescription, privacy: .public)")
        }
    }
}
