import AppKit
import CoreGraphics

/// Triggers window-manager actions by posting keyboard shortcuts.
/// Requires Accessibility permission (already needed for media keys).
///
/// Currently wired for OmniWM's bindings (see `combo(for:)`).
/// If you change those bindings, update the combos below to match.
enum SystemShortcuts {
    static func send(_ action: GestureAction) {
        guard let (keyCode, flags) = combo(for: action) else { return }
        post(keyCode: keyCode, flags: flags)
    }

    private static func combo(for action: GestureAction) -> (CGKeyCode, CGEventFlags)? {
        let ctrlOpt: CGEventFlags = [.maskControl, .maskAlternate]
        switch action {
        case .missionControl: return (49, ctrlOpt)  // ^⌥Space
        case .appWindows: return (125, .maskControl) // ^Down Arrow (macOS default)
        case .spaceLeft: return (126, ctrlOpt)       // ^⌥Up Arrow
        case .spaceRight: return (125, ctrlOpt)      // ^⌥Down Arrow
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
