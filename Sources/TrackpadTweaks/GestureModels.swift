import Foundation

/// Direction of a multi-finger swipe, in trackpad-natural orientation:
/// `.up` means fingers moved toward the top edge of the pad.
enum SwipeDirection: String, Codable, CaseIterable, Hashable {
    case up, down, left, right

    var symbol: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }

    var label: String { rawValue.capitalized }
}

enum GestureKind: String, Codable, Hashable {
    case swipe
    case tap
}

/// A discrete trackpad gesture. `id` is stable and used as the persistence key.
struct Gesture: Codable, Hashable, Identifiable {
    var kind: GestureKind
    var fingers: Int
    var direction: SwipeDirection?

    var id: String {
        switch kind {
        case .swipe: return "swipe-\(fingers)-\(direction?.rawValue ?? "none")"
        case .tap: return "tap-\(fingers)"
        }
    }

    var displayName: String {
        switch kind {
        case .swipe: return "\(fingers)-finger swipe \(direction?.label.lowercased() ?? "")"
        case .tap: return "\(fingers)-finger tap"
        }
    }

    static func swipe(_ fingers: Int, _ direction: SwipeDirection) -> Gesture {
        Gesture(kind: .swipe, fingers: fingers, direction: direction)
    }

    static func tap(_ fingers: Int) -> Gesture {
        Gesture(kind: .tap, fingers: fingers, direction: nil)
    }

    /// 1-2 finger touches are owned by the OS (point, scroll, click) — don't remap.
    /// Only 3- and 4-finger gestures are supported.
    static let all: [Gesture] = {
        var result: [Gesture] = []
        for fingers in 3...4 {
            for dir in SwipeDirection.allCases {
                result.append(.swipe(fingers, dir))
            }
        }
        for fingers in 3...4 {
            result.append(.tap(fingers))
        }
        return result
    }()

    static let swipesOnly: [Gesture] = {
        var result: [Gesture] = []
        for fingers in [4, 3] {
            for dir in SwipeDirection.allCases {
                result.append(.swipe(fingers, dir))
            }
        }
        return result
    }()

    /// macOS reserves these by default (Mission Control / spaces / App Exposé,
    /// 3-finger tap = Look up). Binding them fires alongside the system action
    /// unless disabled in System Settings → Trackpad.
    var conflictsWithSystemDefault: Bool {
        switch kind {
        case .swipe:
            return fingers == 3 || fingers == 4
        case .tap:
            return fingers == 3
        }
    }
}
