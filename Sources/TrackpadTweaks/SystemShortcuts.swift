import AppKit
import CoreGraphics

private let SystemShortcutsDebug = ProcessInfo.processInfo.environment["TRACKPAD_TWEAKS_DEBUG"] != nil
private func sdbg(_ s: @autoclosure () -> String) {
    if SystemShortcutsDebug { FileHandle.standardError.write(Data("[tweaks] \(s())\n".utf8)) }
}

/// Triggers window-manager actions by posting keyboard shortcuts.
/// Requires Accessibility permission (already needed for media keys).
///
/// Currently wired for OmniWM's bindings (see `combo(for:)`).
/// IMPORTANT: the target actions must actually be bound in
/// OmniWM Settings → Hotkeys — e.g. "Switch to Next/Previous Workspace"
/// are Unassigned by default, and sending an unbound chord just beeps.
/// If you change those bindings, update the combos below to match.
enum SystemShortcuts {
    static func send(_ action: GestureAction) {
        guard let (keyCode, flags) = combo(for: action) else { return }
        sdbg("shortcut send: key=\(keyCode) flags=\(flags.rawValue)")
        post(keyCode: keyCode, flags: flags)
    }

    private static func combo(for action: GestureAction) -> (CGKeyCode, CGEventFlags)? {
        let ctrlOpt: CGEventFlags = [.maskControl, .maskAlternate]
        switch action {
        case .missionControl: return (49, ctrlOpt)  // ^⌥Space
        case .appWindows: return (125, .maskControl) // ^Down Arrow (macOS default)
        case .spaceLeft: return (123, ctrlOpt)       // ^⌥Left Arrow
        case .spaceRight: return (124, ctrlOpt)      // ^⌥Right Arrow
        default: return nil
        }
    }

    // Modifier keycodes (kVK_*): Command 55, Shift 56, Option 58, Control 59.
    private static let modifierKeys: [(CGEventFlags, CGKeyCode)] = [
        (.maskControl, 59),
        (.maskAlternate, 58),
        (.maskShift, 56),
        (.maskCommand, 55),
    ]

    /// Posts explicit modifier key down/up events around the hotkey, instead of
    /// flags-alone. Hotkey listeners (event taps, Carbon hotkeys) track real
    /// modifier state, so flags-only synthesis is silently ignored by some of
    /// them. Short holds between events mimic a physical keypress.
    private static func post(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let tap: CGEventTapLocation = .cghidEventTap
        let mods = modifierKeys.filter { flags.contains($0.0) }

        var active: CGEventFlags = []
        for (flag, code) in mods {
            let ev = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
            ev?.flags = active
            ev?.post(tap: tap)
            active.insert(flag)
        }
        Thread.sleep(forTimeInterval: 0.002)

        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.post(tap: tap)
        Thread.sleep(forTimeInterval: 0.005)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.post(tap: tap)

        for (flag, code) in mods.reversed() {
            active.remove(flag)
            let ev = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
            ev?.flags = active
            ev?.post(tap: tap)
        }
    }
}
