import AppKit
import CoreGraphics

private let SystemShortcutsDebug = ProcessInfo.processInfo.environment["TRACKPAD_TWEAKS_DEBUG"] != nil
private func sdbg(_ s: @autoclosure () -> String) {
    if SystemShortcutsDebug { FileHandle.standardError.write(Data("[tweaks] \(s())\n".utf8)) }
}

/// Triggers system actions by posting keyboard shortcuts.
/// Requires Accessibility permission (already needed for media keys).
///
/// NOTE: workspace switching intentionally does NOT live here — OmniWM ignores
/// synthetic hotkeys, so Desktop Left/Right go through `OmniWM.switchWorkspace`
/// (omniwmctl IPC) instead. See `combo(for:)` for the remaining bindings; if you
/// change those, update the combos to match.
enum SystemShortcuts {
    static func send(_ action: GestureAction) {
        guard let (keyCode, flags) = combo(for: action) else { return }
        sdbg("shortcut send: key=\(keyCode) flags=\(flags.rawValue)")
        post(keyCode: keyCode, flags: flags)
    }

    private static func combo(for action: GestureAction) -> (CGKeyCode, CGEventFlags)? {
        switch action {
        case .missionControl: return (49, [.maskControl, .maskAlternate]) // ^⌥Space
        case .appWindows: return (125, .maskControl) // ^Down Arrow (macOS default)
        default: return nil // workspace switching uses OmniWM IPC, not keys
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
