import Foundation

/// Direction of a 4-finger swipe, in trackpad-natural orientation:
/// `.up` means fingers moved toward the top edge of the pad.
enum SwipeDirection: String, CaseIterable, Hashable {
    case up, down, left, right
}

/// A 4-finger swipe. `id` is stable and is the persistence key in bindings.json.
struct Gesture: Hashable {
    var direction: SwipeDirection

    var id: String { "swipe-4-\(direction.rawValue)" }

    var displayName: String { "4-finger swipe \(direction.rawValue)" }

    static let all: [Gesture] = SwipeDirection.allCases.map { Gesture(direction: $0) }
}
