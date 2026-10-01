import AIUsageCore
import AppKit
import SwiftUI

@main
enum AIUsageWidgetApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = UsageViewModel()
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var refreshObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configurePanel()
        configureStatusItem()
        refreshObserver = NotificationCenter.default.addObserver(
            forName: .usageDidRefresh,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let snapshot = note.object as? UsageSnapshot else { return }
            Task { @MainActor in self?.updateMenuBar(snapshot) }
        }
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let refreshObserver { NotificationCenter.default.removeObserver(refreshObserver) }
    }

    private func configurePanel() {
        let content = UsageWidgetView(model: model) { [weak model] in model?.refresh() }
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 340, height: 390)

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.setFrameOrigin(defaultOrigin(for: panel.frame.size))
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: "AI Usage")
        item.button?.imagePosition = .imageLeading

        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Hide Desktop Widget", action: #selector(togglePanel), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit AI Usage Widget", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    private func updateMenuBar(_ snapshot: UsageSnapshot) {
        let highest = snapshot.providers
            .flatMap(\.windows)
            .map(\.usedPercent)
            .max()
        statusItem?.button?.title = highest.map { " \(Int($0.rounded()))%" } ?? ""
    }

    private func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let frame = NSScreen.main?.visibleFrame else { return NSPoint(x: 40, y: 40) }
        return NSPoint(x: frame.maxX - size.width - 24, y: frame.maxY - size.height - 24)
    }

    @objc private func togglePanel(_ sender: NSMenuItem) {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
            sender.title = "Show Desktop Widget"
        } else {
            panel.orderFrontRegardless()
            sender.title = "Hide Desktop Widget"
        }
    }

    @objc private func refresh() {
        model.refresh()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
