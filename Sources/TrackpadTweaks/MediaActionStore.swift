import Foundation

/// Action a gesture can trigger: a media key or a macOS system action.
enum GestureAction: String, Codable, CaseIterable, Identifiable {
    case none
    case playPause
    case next
    case previous
    case volumeUp
    case volumeDown
    case mute
    case missionControl
    case appWindows
    case spaceLeft
    case spaceRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "No action"
        case .playPause: return "Play / Pause"
        case .next: return "Next track"
        case .previous: return "Previous track"
        case .volumeUp: return "Volume up"
        case .volumeDown: return "Volume down"
        case .mute: return "Mute"
        case .missionControl: return "Mission Control"
        case .appWindows: return "App Windows"
        case .spaceLeft: return "Desktop Left"
        case .spaceRight: return "Desktop Right"
        }
    }

    /// Fire the action. Media keys use the aux-control path,
    /// system actions use their default keyboard shortcuts.
    func perform() {
        switch self {
        case .none:
            break
        case .playPause, .next, .previous, .volumeUp, .volumeDown, .mute:
            MediaKeys.send(self)
        case .missionControl, .appWindows, .spaceLeft, .spaceRight:
            SystemShortcuts.send(self)
        }
    }
}

/// Persists gesture → media-action bindings to
/// `~/Library/Application Support/TrackpadTweaks/bindings.json`.
final class MediaActionStore {
    var bindings: [String: GestureAction] = [:]
    var enabled: Bool = true
    var lastGesture: Gesture?
    var lastFired: Bool = false

    /// Called on the main thread whenever state changes (for UI refresh).
    var onChange: (() -> Void)?

    static let defaults: [String: GestureAction] = [
        // Requested preset:
        // 4-finger swipe down → play/pause, left/right → prev/next
        Gesture.swipe(4, .down).id: .playPause,
        Gesture.swipe(4, .left).id: .previous,
        Gesture.swipe(4, .right).id: .next,
        Gesture.swipe(4, .up).id: .mute,
        Gesture.swipe(3, .down).id: .volumeDown,
        Gesture.swipe(3, .up).id: .volumeUp,
        Gesture.swipe(3, .left).id: .previous,
        Gesture.swipe(3, .right).id: .next,
    ]

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("TrackpadTweaks/bindings.json")
    }

    private struct Saved: Codable {
        var bindings: [String: GestureAction]
        var enabled: Bool
    }

    init() {
        load()
    }

    func action(for gesture: Gesture) -> GestureAction {
        bindings[gesture.id] ?? .none
    }

    func set(_ action: GestureAction, for gesture: Gesture) {
        bindings[gesture.id] = action
        save()
        onChange?()
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        save()
        onChange?()
    }

    func handle(_ gesture: Gesture) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastGesture = gesture
            guard self.enabled else {
                self.lastFired = false
                self.onChange?()
                return
            }
            let action = self.action(for: gesture)
            if action == .none {
                self.lastFired = false
            } else {
                action.perform()
                self.lastFired = true
            }
            self.onChange?()
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let saved = try JSONDecoder().decode(Saved.self, from: data)
            bindings = saved.bindings
            enabled = saved.enabled
        } catch {
            bindings = Self.defaults
            enabled = true
        }
        // Drop bindings for gestures we no longer support (5-finger).
        bindings = bindings.filter { !$0.key.hasPrefix("swipe-5") && !$0.key.hasPrefix("tap-5") }
        for (k, v) in Self.defaults where bindings[k] == nil {
            bindings[k] = v
        }
    }

    private func save() {
        do {
            let url = fileURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Saved(bindings: bindings, enabled: enabled))
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("TrackpadTweaks: failed to save bindings: \(error)")
        }
    }
}
