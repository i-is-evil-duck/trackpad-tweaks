import Foundation
import CMultitouch

private let recognizerDebug = ProcessInfo.processInfo.environment["TRACKPAD_TWEAKS_DEBUG"] != nil
private func rdbg(_ s: @autoclosure () -> String) {
    if recognizerDebug { FileHandle.standardError.write(Data("[tweaks] \(s())\n".utf8)) }
}

/// Classifies raw multitouch frames into discrete gestures.
///
/// One touch sequence = fingers down → fingers up:
/// - Sequence begins when ≥3 fingers are present.
/// - Motion accumulates as net centroid displacement, but only across frames
///   where finger count is unchanged and the per-frame step is small. This skips
///   the centroid jump when a finger lands/lifts, while real motion accumulates.
/// - Past `swipeThreshold` of net travel → swipe in dominant direction (once).
/// - On lift, if short + nearly stationary → tap using peak finger count.
/// A `cooldown` after any emit debounces a single physical gesture.
final class GestureRecognizer {
    var swipeThreshold: Double = 0.12
    var tapMaxMovement: Double = 0.10
    var tapMaxDuration: Double = 0.4
    var jumpCap: Double = 0.08
    var cooldown: Double = 0.25

    var onGesture: ((Gesture) -> Void)?

    func reset() {
        active = false
        recognized = false
        peakFingers = 0
        netDX = 0
        netDY = 0
        lastCount = 0
        lastEmitTime = -1
    }

    private struct Point { var x: Double; var y: Double }

    private var active = false
    private var recognized = false
    private var startTime: Double = 0
    private var peakFingers = 0
    private var lastEmitTime: Double = -1

    private var lastCount = 0
    private var lastCentroid = Point(x: 0, y: 0)
    private var netDX = 0.0
    private var netDY = 0.0

    func ingest(fingers: UnsafePointer<Finger>?, count: Int, timestamp: Double) {
        if count == 0 {
            if active { endSequence(at: timestamp) }
            return
        }

        let centroid = computeCentroid(fingers: fingers, count: count)

        if !active {
            guard count >= 3 else { return }
            beginSequence(centroid: centroid, count: count, timestamp: timestamp)
            return
        }

        peakFingers = max(peakFingers, count)

        if count == lastCount {
            let dx = centroid.x - lastCentroid.x
            let dy = centroid.y - lastCentroid.y
            if (dx * dx + dy * dy).squareRoot() <= jumpCap {
                netDX += dx
                netDY += dy
            }
        }
        lastCount = count
        lastCentroid = centroid

        guard !recognized, peakFingers >= 3, !inCooldown(timestamp) else { return }

        let distance = (netDX * netDX + netDY * netDY).squareRoot()
        if distance >= swipeThreshold {
            let direction: SwipeDirection
            if abs(netDX) >= abs(netDY) {
                direction = netDX > 0 ? .right : .left
            } else {
                direction = netDY > 0 ? .up : .down
            }
            emit(.swipe(clampFingers(peakFingers), direction), at: timestamp)
            recognized = true
        }
    }

    private func beginSequence(centroid: Point, count: Int, timestamp: Double) {
        active = true
        recognized = false
        startTime = timestamp
        peakFingers = count
        lastCount = count
        lastCentroid = centroid
        netDX = 0
        netDY = 0
        rdbg("seq begin: fingers=\(count)")
    }

    private func endSequence(at timestamp: Double) {
        defer {
            active = false
            recognized = false
            peakFingers = 0
        }
        let duration = timestamp - startTime
        let netDistance = (netDX * netDX + netDY * netDY).squareRoot()
        rdbg(String(format: "seq end: peak=%d dur=%.2f dist=%.3f rec=%@",
                    peakFingers, duration, netDistance, recognized ? "yes" : "no"))

        guard !recognized, peakFingers >= 3, !inCooldown(timestamp) else { return }

        if duration <= tapMaxDuration && netDistance <= tapMaxMovement {
            emit(.tap(clampFingers(peakFingers)), at: timestamp)
        }
    }

    private func emit(_ gesture: Gesture, at timestamp: Double) {
        lastEmitTime = timestamp
        onGesture?(gesture)
    }

    private func inCooldown(_ timestamp: Double) -> Bool {
        lastEmitTime >= 0 && (timestamp - lastEmitTime) < cooldown
    }

    private func clampFingers(_ n: Int) -> Int { min(max(n, 3), 4) }

    private func computeCentroid(fingers: UnsafePointer<Finger>?, count: Int) -> Point {
        guard let fingers, count > 0 else { return Point(x: 0, y: 0) }
        var sx = 0.0, sy = 0.0
        for i in 0..<count {
            let p = fingers[i].normalizedVector.position
            sx += Double(p.x)
            sy += Double(p.y)
        }
        return Point(x: sx / Double(count), y: sy / Double(count))
    }
}
