import Foundation
import CMultitouch

private let recognizerDebug = ProcessInfo.processInfo.environment["TRACKPAD_TWEAKS_DEBUG"] != nil
private func rdbg(_ s: @autoclosure () -> String) {
    if recognizerDebug { FileHandle.standardError.write(Data("[tweaks] \(s())\n".utf8)) }
}

/// Classifies raw multitouch frames into 4-finger swipes.
///
/// Frames with any other finger count are ignored before any math happens,
/// so normal 1–2 finger scrolling costs a single integer compare per frame.
/// A sequence is fingers-down → all-lifted; motion accumulates as net centroid
/// displacement across consecutive 4-finger frames (per-frame steps above
/// `jumpCap` are finger landings/lifts, not motion). Past `swipeThreshold` of
/// net travel the dominant direction fires once; a `cooldown` debounces repeats.
final class GestureRecognizer {
    var swipeThreshold: Double = 0.12
    var jumpCap: Double = 0.08
    var cooldown: Double = 0.25

    var onGesture: ((Gesture) -> Void)?

    func reset() {
        active = false
        recognized = false
        netDX = 0
        netDY = 0
        hasLast = false
        lastEmitTime = -1
    }

    private struct Point { var x: Double; var y: Double }

    private var active = false
    private var recognized = false
    private var lastEmitTime: Double = -1
    private var lastCentroid = Point(x: 0, y: 0)
    private var hasLast = false
    private var netDX = 0.0
    private var netDY = 0.0

    func ingest(fingers: UnsafePointer<Finger>?, count: Int, timestamp: Double) {
        guard count == 4, let fingers else {
            if count == 0, active { endSequence() }
            return
        }

        var sx = 0.0, sy = 0.0
        for i in 0..<4 {
            let p = fingers[i].normalizedVector.position
            sx += Double(p.x)
            sy += Double(p.y)
        }
        let centroid = Point(x: sx / 4, y: sy / 4)

        if !active {
            active = true
            recognized = false
            netDX = 0
            netDY = 0
            lastCentroid = centroid
            hasLast = true
            rdbg("seq begin")
            return
        }

        if hasLast {
            let dx = centroid.x - lastCentroid.x
            let dy = centroid.y - lastCentroid.y
            if (dx * dx + dy * dy).squareRoot() <= jumpCap {
                netDX += dx
                netDY += dy
            }
        }
        lastCentroid = centroid
        hasLast = true

        guard !recognized, !inCooldown(timestamp) else { return }

        if (netDX * netDX + netDY * netDY).squareRoot() >= swipeThreshold {
            let direction: SwipeDirection
            if abs(netDX) >= abs(netDY) {
                direction = netDX > 0 ? .right : .left
            } else {
                direction = netDY > 0 ? .up : .down
            }
            lastEmitTime = timestamp
            recognized = true
            onGesture?(Gesture(direction: direction))
        }
    }

    private func endSequence() {
        active = false
        recognized = false
        hasLast = false
        netDX = 0
        netDY = 0
    }

    private func inCooldown(_ timestamp: Double) -> Bool {
        lastEmitTime >= 0 && (timestamp - lastEmitTime) < cooldown
    }
}
