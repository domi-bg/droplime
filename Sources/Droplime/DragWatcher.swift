import AppKit

/// Erkennt systemweit, ob gerade Dateien gezogen werden und ob dabei eine
/// Modifier-Taste gedrückt wird. Pollt Maus-, Tasten- und Drag-Pasteboard-Zustand,
/// dafür ist keine Bedienungshilfen-Berechtigung nötig.
@MainActor
final class DragWatcher {
    var onModifierTap: ((WheelMode) -> Void)?
    var onMouseUp: (() -> Void)?

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var baselineChangeCount = 0
    private var mouseWasDown = false
    private var isFileDrag = false
    private var lastFlags: NSEvent.ModifierFlags = []
    private var timer: Timer?

    func start() {
        baselineChangeCount = dragPasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        let mouseDown = NSEvent.pressedMouseButtons & 1 != 0

        if mouseDown {
            // Ein neuer Drag schreibt ins Drag-Pasteboard und erhöht dessen changeCount.
            if !isFileDrag, dragPasteboard.changeCount != baselineChangeCount {
                isFileDrag = dragPasteboard.types?.contains(.fileURL) ?? false
                baselineChangeCount = dragPasteboard.changeCount
            }
        } else {
            if mouseWasDown { onMouseUp?() }
            isFileDrag = false
            baselineChangeCount = dragPasteboard.changeCount
        }
        mouseWasDown = mouseDown

        let flags = NSEvent.modifierFlags.intersection([.shift, .command, .control])
        let newlyPressed = flags.subtracting(lastFlags)
        lastFlags = flags
        if isFileDrag, let mode = WheelMode(pressed: newlyPressed) {
            onModifierTap?(mode)
        }
    }
}
