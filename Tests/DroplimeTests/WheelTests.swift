import AppKit
import Testing
@testable import Droplime

/// Hit testing of the wheel: segment 0 at the top, then clockwise.
@MainActor
struct WheelTests {
    private func wheel(items: Int, split: Bool) -> WheelView {
        let view = WheelView(frame: .zero)
        view.configure(mode: .convert, items: (0..<items).map { "Item \($0)" }, split: split)
        view.frame = NSRect(x: 0, y: 0, width: view.diameter, height: view.diameter)
        return view
    }

    private func point(in view: WheelView, radius: CGFloat, degrees: CGFloat) -> NSPoint {
        let rad = degrees * .pi / 180
        return NSPoint(x: view.bounds.midX + cos(rad) * radius, y: view.bounds.midY + sin(rad) * radius)
    }

    @Test func centerHitsNothing() {
        let view = wheel(items: 6, split: false)
        #expect(view.hit(at: NSPoint(x: view.bounds.midX, y: view.bounds.midY)) == nil)
    }

    @Test func topIsFirstSegment() {
        let view = wheel(items: 6, split: false)
        #expect(view.hit(at: point(in: view, radius: 100, degrees: 90))?.index == 0)
    }

    @Test func rightIsSegmentTwoOfSix() {
        // 90° clockwise from the top with 60° per segment: (90 + 30) / 60 = 2.
        let view = wheel(items: 6, split: false)
        #expect(view.hit(at: point(in: view, radius: 100, degrees: 0))?.index == 2)
    }

    @Test func splitWheelRings() {
        let view = wheel(items: 5, split: true)
        #expect(view.hit(at: point(in: view, radius: 100, degrees: 90))?.outer == false)
        #expect(view.hit(at: point(in: view, radius: 160, degrees: 90))?.outer == true)
        #expect(view.hit(at: point(in: view, radius: 200, degrees: 90)) == nil)
    }
}
