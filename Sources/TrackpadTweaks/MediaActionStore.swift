import Foundation

/// The four media actions a gesture can trigger.
enum MediaAction: String, Codable, CaseIterable {
    case none
    case playPause
    case next
    case previous
    case mute

    var label: String {
        switch self {
        case .none: return "No action"
        case .playPause: return "Play / Pause"
        case .next: return "Next track"
        case .previous: return "Previous track"
        case .mute: return "Mute"
        }
    }
}

/// Persists gesture → media-action bindings to
/// `~/Library/Application Support/TrackpadTweaks/bindings.json`.
final class MediaActionStore {
    var bindings: [String: MediaAction] = [:]
    var enabled: Bool = true
    var lastGesture: Gesture?
    var lastFired: Bool = false

    /// Called on the main thread whenever state changes (for UI refresh).
    var onChange: (() -> Void)?

    static let defaults: [String: MediaAction] = [
        Gesture(direction: .down).id: .playPause,
        Gesture(direction: .left).id: .previous,
        Gesture(direction: .right).id: .next,
        Gesture(direction: .up).id: .mute,
    ]

    private static let supportedIDs = Set(Gesture.all.map(\.id))

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("TrackpadTweaks/bindings.json")
    }

    private struct Saved: Codable {
        var bindings: [String: MediaAction]
        var enabled: Bool
    }

    /// Lenient shape for migrating files written by older versions that
    /// contained actions which no longer exist (volume, system actions).
    private struct LooseSaved: Codable {
        var bindings: [String: String]
        var enabled: Bool
    }

    init() {
        load()
    }

    func action(for gesture: Gesture) -> MediaAction {
        bindings[gesture.id] ?? .none
    }

    func set(_ action: MediaAction, for gesture: Gesture) {
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
                MediaKeys.send(action)
                self.lastFired = true
            }
            self.onChange?()
        }
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            bindings = saved.bindings
            enabled = saved.enabled
        } else if let data = try? Data(contentsOf: fileURL),
                  let loose = try? JSONDecoder().decode(LooseSaved.self, from: data) {
            bindings = loose.bindings.compactMapValues(MediaAction.init(rawValue:))
            enabled = loose.enabled
        } else {
            bindings = Self.defaults
            enabled = true
        }
        // Drop bindings for gestures we no longer support.
        bindings = bindings.filter { Self.supportedIDs.contains($0.key) }
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
