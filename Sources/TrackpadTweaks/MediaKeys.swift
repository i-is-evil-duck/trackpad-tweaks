import AppKit

/// Sends system media-key events (play/pause, next, previous, mute).
/// Uses the classic NX_SYSDEFINED subtype-8 aux-control path (same as
/// SPMediaKeyTap). Requires Accessibility permission to post to the HID tap.
enum MediaKeys {
    // From hidsystem/ev_keymap.h
    private static let NX_KEYTYPE_MUTE: Int32 = 7
    private static let NX_KEYTYPE_PLAY: Int32 = 16
    private static let NX_KEYTYPE_NEXT: Int32 = 17
    private static let NX_KEYTYPE_PREVIOUS: Int32 = 18

    static func send(_ action: MediaAction) {
        guard let key = nxKey(for: action) else { return }
        postAuxKey(key)
    }

    private static func nxKey(for action: MediaAction) -> Int32? {
        switch action {
        case .playPause: return NX_KEYTYPE_PLAY
        case .next: return NX_KEYTYPE_NEXT
        case .previous: return NX_KEYTYPE_PREVIOUS
        case .mute: return NX_KEYTYPE_MUTE
        case .none: return nil
        }
    }

    private static func postAuxKey(_ key: Int32) {
        func doKey(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | Int32(down ? 0xa00 : 0xb00))
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            ev?.cgEvent?.post(tap: .cghidEventTap)
        }
        doKey(down: true)
        doKey(down: false)
    }
}
