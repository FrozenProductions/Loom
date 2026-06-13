import AppKit
import CoreGraphics

@MainActor
final class ControlKeyMonitor {
    private let onChange: @MainActor (Bool) -> Void
    private var timer: Timer?
    private var isControlPressed = false

    init(onChange: @escaping @MainActor (Bool) -> Void) {
        self.onChange = onChange
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        timer?.tolerance = 0.01
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        updateControlState(false)
    }

    private func poll() {
        let isPressed = CGEventSource.flagsState(.hidSystemState).contains(.maskControl)
        updateControlState(isPressed)
    }

    private func updateControlState(_ newValue: Bool) {
        guard newValue != isControlPressed else { return }
        isControlPressed = newValue
        onChange(newValue)
    }
}
