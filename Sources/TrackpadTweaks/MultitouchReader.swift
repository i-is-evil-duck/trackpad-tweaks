import Foundation
import AppKit
import CMultitouch

private let debugEnabled = ProcessInfo.processInfo.environment["TRACKPAD_TWEAKS_DEBUG"] != nil
private func dbg(_ s: @autoclosure () -> String) {
    if debugEnabled { FileHandle.standardError.write(Data("[tweaks] \(s())\n".utf8)) }
}

/// Owns MultitouchSupport devices and feeds frames into a `GestureRecognizer`.
/// The `@convention(c)` callback can't capture context, so it routes through `shared`.
/// Reading frames needs no permission; only media-key *output* needs Accessibility.
final class MultitouchReader {
    static let shared = MultitouchReader()

    let recognizer = GestureRecognizer()
    private var devices: [MTDeviceRef] = []
    private(set) var isRunning = false
    private var observers: [NSObjectProtocol] = []
    private var retryCount = 0
    private let maxRetries = 20
    private let retryDelaySeconds = 0.5

    var onGesture: ((Gesture) -> Void)? {
        get { recognizer.onGesture }
        set { recognizer.onGesture = newValue }
    }

    private init() {}

    func start() {
        installObserversIfNeeded()
        guard !isRunning else { return }

        devices = []
        if let list = MTDeviceCreateList()?.takeRetainedValue() as? [MTDeviceRef] {
            devices = list
        }
        if devices.isEmpty, let def = MTDeviceCreateDefault() {
            devices = [def]
        }
        guard !devices.isEmpty else {
            NSLog("TrackpadTweaks: no multitouch device found")
            return
        }

        recognizer.reset()
        for device in devices {
            MTRegisterContactFrameCallback(device, mtFrameCallback)
            MTDeviceStart(device, 0)
        }
        isRunning = true
        dbg("start: \(devices.count) device(s)")
    }

    func stop() {
        guard isRunning else { return }
        for device in devices {
            MTUnregisterContactFrameCallback(device, mtFrameCallback)
            MTDeviceStop(device)
        }
        isRunning = false
    }

    func restart() {
        stop()
        start()
    }

    private func restartWithRetry() {
        stop()
        start()
        if devices.contains(where: { MTDeviceIsRunning($0) }) {
            retryCount = 0
        } else {
            retryCount += 1
            if retryCount <= maxRetries {
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelaySeconds) { [weak self] in
                    self?.restartWithRetry()
                }
            } else {
                retryCount = 0
            }
        }
    }

    private func installObserversIfNeeded() {
        guard observers.isEmpty else { return }
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.stop()
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.restartWithRetry()
            })
        }
    }

    fileprivate func handleFrame(fingers: UnsafeMutablePointer<Finger>?, count: Int, timestamp: Double) {
        recognizer.ingest(fingers: fingers, count: count, timestamp: timestamp)
    }
}

private let mtFrameCallback: MTContactCallbackFunction = { _, fingers, numFingers, timestamp, _ in
    MultitouchReader.shared.handleFrame(fingers: fingers, count: Int(numFingers), timestamp: timestamp)
    return 0
}
