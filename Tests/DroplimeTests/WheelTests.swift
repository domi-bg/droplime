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

    /// Promised files can arrive after another wheel was shown; they must still go to the tool that was dropped on,
    /// even when another tool has the same label.
    @Test func pickIsBoundAtDropTime() {
        let tools: [Tool] = [CompressPDFTool(), CompressVideoTool()]
        #expect(tools[0].label == tools[1].label)
        var picked: Tool?
        let view = WheelView(frame: .zero)
        view.configure(mode: .tools, items: tools.map(\.label), split: false)
        view.onPick = { index, _, _ in picked = tools[index] }
        let pick = view.pick(at: WheelView.Hit(index: 1, outer: false))

        let otherTools: [Tool] = [CompressPDFTool()]
        view.configure(mode: .tools, items: otherTools.map(\.label), split: false)
        view.onPick = { index, _, _ in picked = otherTools[index] }
        pick([URL(fileURLWithPath: "/tmp/movie.mov")])

        #expect(picked is CompressVideoTool)
    }

    @Test func receiptCompletesOnceAllFilesArrived() {
        var deliveries: [(urls: [URL], errors: [Error])] = []
        let receipt = WheelView.PromiseReceipt(expected: 2) { deliveries.append(($0, $1)) }
        receipt.add(URL(fileURLWithPath: "/tmp/a.jpg"), error: nil)
        #expect(deliveries.isEmpty)
        receipt.add(URL(fileURLWithPath: "/tmp/b.jpg"), error: nil)
        receipt.timeOut(with: ConversionError(message: "timeout"))
        #expect(deliveries.count == 1)
        #expect(deliveries.first?.urls.count == 2)
        #expect(deliveries.first?.errors.isEmpty == true)
    }

    /// A source that never finishes (e.g. a hanging iCloud download) must not keep the wheel busy.
    @Test func timeoutWinsOverHangingReceive() {
        var deliveries: [(urls: [URL], errors: [Error])] = []
        let receipt = WheelView.PromiseReceipt(expected: 2) { deliveries.append(($0, $1)) }
        receipt.add(URL(fileURLWithPath: "/tmp/a.jpg"), error: nil)
        receipt.timeOut(with: ConversionError(message: "timeout"))
        #expect(receipt.isFinished)
        #expect(deliveries.count == 1)
        #expect(deliveries.first?.urls.count == 1)
        #expect(deliveries.first?.errors.count == 1)
        // The late file is ignored.
        receipt.add(URL(fileURLWithPath: "/tmp/b.jpg"), error: nil)
        #expect(deliveries.count == 1)
    }
}
