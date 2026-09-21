import AppKit

/// AppKit settings window. No SwiftUI so the app builds with Command Line Tools.
final class SettingsWindowController: NSWindowController {
    private let store: MediaActionStore
    private var popups: [String: NSPopUpButton] = [:]
    private var statusLabel = NSTextField(labelWithString: "Perform a gesture to test…")
    private var enabledCheckbox = NSButton(checkboxWithTitle: "Enabled", target: nil, action: nil)
    private var loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    /// Called when the window closes so the owner can release this controller
    /// and reclaim the window's memory until settings are opened again.
    var onClose: (() -> Void)?

    init(store: MediaActionStore) {
        self.store = store
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Trackpad Tweaks"
        window.center()
        super.init(window: window)
        window.delegate = self
        buildUI()
        refresh()
        store.onChange = { [weak self] in self?.refresh() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])

        let title = NSTextField(labelWithString: "Gestures → media controls")
        title.font = .boldSystemFont(ofSize: 14)
        stack.addArrangedSubview(title)

        if !Permissions.hasAccessibility {
            let banner = NSTextField(wrappingLabelWithString: "Needs Accessibility permission to send media keys. Click Grant, then tick TrackpadTweaks in System Settings → Privacy & Security → Accessibility.")
            banner.textColor = .systemOrange
            stack.addArrangedSubview(banner)
            let row = NSStackView(views: [
                makeButton(title: "Grant…") { Permissions.promptForAccessibility() },
                makeButton(title: "Open Settings") { Permissions.openAccessibilitySettings() },
            ])
            row.orientation = .horizontal
            stack.addArrangedSubview(row)
        }

        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(toggledEnabled(_:))
        stack.addArrangedSubview(enabledCheckbox)

        for section in [(4, "4-finger (recommended)"), (3, "3-finger")] {
            let header = NSTextField(labelWithString: section.1)
            header.font = .boldSystemFont(ofSize: 12)
            stack.addArrangedSubview(header)
            for dir in SwipeDirection.allCases {
                let gesture = Gesture.swipe(section.0, dir)
                stack.addArrangedSubview(row(for: gesture))
            }
        }

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(statusLabel)

        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
        loginCheckbox.target = self
        loginCheckbox.action = #selector(toggledLogin(_:))
        stack.addArrangedSubview(loginCheckbox)

        let hint = NSTextField(wrappingLabelWithString: "If a swipe also triggers a macOS action (Mission Control, spaces), disable it in System Settings → Trackpad.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hint)
    }

    private func row(for gesture: Gesture) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        let label = NSTextField(labelWithString: gestureLabel(for: gesture))
        label.font = .systemFont(ofSize: 12)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: GestureAction.allCases.map(\.label))
        popup.target = self
        popup.action = #selector(changedPopup(_:))
        popup.identifier = NSUserInterfaceItemIdentifier(gesture.id)
        popup.controlSize = .small
        popup.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        popups[gesture.id] = popup

        row.addArrangedSubview(label)
        row.addArrangedSubview(popup)
        return row
    }

    private func gestureLabel(for gesture: Gesture) -> String {
        var s = gesture.displayName
        if gesture.conflictsWithSystemDefault { s += "  ⚠︎" }
        return s
    }

    private func makeButton(title: String, action: @escaping () -> Void) -> NSButton {
        let b = NSButton(title: title, target: nil, action: nil)
        b.bezelStyle = .rounded
        b.controlSize = .small
        // Lightweight closure trampoline via associated object.
        ClosureBox.attach(to: b, action: action)
        return b
    }

    @objc private func changedPopup(_ sender: NSPopUpButton) {
        guard let id = sender.identifier?.rawValue else { return }
        let action = GestureAction.allCases[sender.indexOfSelectedItem]
        let parts = id.split(separator: "-")
        // id format: "swipe-<fingers>-<direction>"
        guard parts.count == 3, let fingers = Int(parts[1]),
              let dir = SwipeDirection(rawValue: String(parts[2])) else { return }
        store.set(action, for: .swipe(fingers, dir))
    }

    @objc private func toggledEnabled(_ sender: NSButton) {
        store.setEnabled(sender.state == .on)
    }

    @objc private func toggledLogin(_ sender: NSButton) {
        LoginItem.setEnabled(sender.state == .on)
    }

    private func refresh() {
        enabledCheckbox.state = store.enabled ? .on : .off
        for (id, popup) in popups {
            let action = store.bindings[id] ?? .none
            if let idx = GestureAction.allCases.firstIndex(of: action) {
                popup.selectItem(at: idx)
            }
        }
        if let g = store.lastGesture {
            statusLabel.stringValue = store.lastFired
                ? "Fired: \(g.displayName) → \(store.action(for: g).label)"
                : "Saw: \(g.displayName) (unbound)"
        } else {
            statusLabel.stringValue = "Perform a gesture to test…"
        }
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        store.onChange = nil
        onClose?()
    }
}

/// Minimal closure target for NSButtons without a nib.
private final class ClosureBox: NSObject {
    var action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func fire(_ sender: Any) { action() }

    private static var key: UInt8 = 0

    static func attach(to button: NSButton, action: @escaping () -> Void) {
        let box = ClosureBox(action)
        objc_setAssociatedObject(button, &key, box, .OBJC_ASSOCIATION_RETAIN)
        button.target = box
        button.action = #selector(ClosureBox.fire(_:))
    }
}
