import AppKit
import CoreGraphics

/// Triggers macOS system actions by posting their *default* keyboard shortcuts.
/// Requires Accessibility permission (already needed for media keys).
///
/// These send the factory defaults from System Settings → Keyboard → Shortcuts
/// → Mission Control. If you've remapped those shortcuts, update `combo(for:)`
/// below to match.
enum SystemShortcuts {
    static func send(_ action: GestureAction) {
        guard let (keyCode, flags) = combo(for: action) else { return }
        post(keyCode: keyCode, flags: flags)
    }

    private static func combo(for action: GestureAction) -> (CGKeyCode, CGEventFlags)? {
        switch action {
        case .missionControl: return (126, .maskControl) // ^Up Arrow
        case .appWindows: return (125, .maskControl)     // ^Down Arrow
        case .spaceLeft: return (123, .maskControl)      // ^Left Arrow
        case .spaceRight: return (124, .maskControl)     // ^Right Arrow
        default: return nil
        }
    }

    private static func post(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }
}
