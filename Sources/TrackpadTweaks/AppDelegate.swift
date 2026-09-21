import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = MediaActionStore()
    private var statusItem: NSStatusItem!
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "⏯"
            button.target = self
            button.action = #selector(toggleSettings)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(toggleSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Enable", action: #selector(toggleEnabled), keyEquivalent: "e"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = nil // click opens window; right-click menu below via subclass is overkill
        // Keep a menu for right-click: assign and also handle left click.
        // Simplest: show window on click, menu on right-click via delegate is skipped —
        // use menu as primary (lightweight + reliable).
        statusItem.menu = buildMenu()

        MultitouchReader.shared.onGesture = { [weak self] gesture in
            self?.store.handle(gesture)
        }
        MultitouchReader.shared.start()
        Permissions.promptForAccessibility()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Settings…", action: #selector(toggleSettings), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let toggle = NSMenuItem(title: "Pause", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.tag = 99
        menu.addItem(toggle)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Trackpad Tweaks", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        menu.delegate = self
        return menu
    }

    @objc private func toggleSettings() {
        if settingsController == nil {
            let controller = SettingsWindowController(store: store)
            controller.onClose = { [weak self] in self?.settingsController = nil }
            settingsController = controller
        }
        settingsController?.show()
    }

    @objc private func toggleEnabled() {
        store.setEnabled(!store.enabled)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let item = menu.item(withTag: 99) {
            item.title = store.enabled ? "Pause" : "Resume"
        }
    }
}
