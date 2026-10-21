import AppKit

/// Detects system-wide whether files are being dragged and whether a
/// modifier key gets tapped meanwhile. Watches mouse down/up with a global monitor and
/// polls key and drag pasteboard state only while the button is down,
/// so no Accessibility permission is needed and nothing runs while idle.
@MainActor
final class DragWatcher {
    var onModifierTap: ((WheelMode) -> Void)?
    var onMouseUp: (() -> Void)?

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var baselineChangeCount = 0
    private var isFileDrag = false
    private var lastFlags: NSEvent.ModifierFlags = []
    private var timer: Timer?
    private var monitor: Any?

    func start() {
        // If the button is already down at launch, it counts as up until the next mouse-down.
        baselineChangeCount = dragPasteboard.changeCount
        // Global monitors for mouse events need no permission (unlike key events).
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            let isDown = event.type == .leftMouseDown
            MainActor.assumeIsolated {
                if isDown { self?.mouseDown() } else { self?.mouseUp() }
            }
        }
    }

    private func mouseDown() {
        guard timer == nil else { return }
        baselineChangeCount = dragPasteboard.changeCount
        lastFlags = NSEvent.modifierFlags.intersection([.shift, .command, .control])
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func mouseUp() {
        if let timer {
            timer.invalidate()
            self.timer = nil
            onMouseUp?()
        }
        isFileDrag = false
        baselineChangeCount = dragPasteboard.changeCount
    }

    private func tick() {
        // Fallback in case the mouse-up event was missed.
        guard NSEvent.pressedMouseButtons & 1 != 0 else { mouseUp(); return }

        // A new drag writes to the drag pasteboard and bumps its changeCount.
        if !isFileDrag, dragPasteboard.changeCount != baselineChangeCount {
            isFileDrag = dragPasteboard.types?.contains(.fileURL) ?? false
            baselineChangeCount = dragPasteboard.changeCount
        }

        let flags = NSEvent.modifierFlags.intersection([.shift, .command, .control])
        let newlyPressed = flags.subtracting(lastFlags)
        lastFlags = flags
        if isFileDrag, let mode = WheelMode(pressed: newlyPressed) {
            onModifierTap?(mode)
        }
    }
}
