import AppKit

/// Zeichnet das Droplime-Symbol: nur die Fruchtsegmente einer Limette, ohne Schale –
/// ein Segment ist herausgezogen, wie das gewählte Feld im Rad.
/// Wird auch von `scripts/make-icon.swift` verwendet und darf daher nichts anderes aus der App benutzen.
enum LimeIcon {
    static let segmentCount = 8
    /// Das herausgezogene Segment (0 = oben, im Uhrzeigersinn).
    static let poppedSegment = 1

    /// Einfarbige Vorlage für die Menüleiste; macOS färbt sie passend zum Hell-/Dunkelmodus.
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let c = NSPoint(x: rect.midX - 0.6, y: rect.midY - 0.6)
            NSColor.black.set()
            for i in 0..<segmentCount {
                let wedge = segment(i, of: segmentCount, center: offset(c, segment: i, by: i == poppedSegment ? 1.6 : 0),
                                    radius: 7, membrane: 1.1, corner: 0.5)
                wedge.fill()
                wedge.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Farbiges App-Icon in der macOS-Form (abgerundetes Quadrat mit Rand, 1024er Raster).
    static func appIcon(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width / 1024
            let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
            let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)

            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.shadowBlurRadius = 20 * s
            shadow.shadowOffset = NSSize(width: 0, height: -8 * s)
            shadow.set()
            NSColor.black.setFill()
            tilePath.fill()
            NSGraphicsContext.restoreGraphicsState()

            NSGradient(starting: NSColor(red: 0.19, green: 0.22, blue: 0.17, alpha: 1),
                       ending: NSColor(red: 0.08, green: 0.1, blue: 0.07, alpha: 1))!
                .draw(in: tilePath, angle: -90)

            drawSegments(center: NSPoint(x: tile.midX - 14 * s, y: tile.midY - 14 * s), radius: 300 * s, scale: s)
            return true
        }
    }

    private static func drawSegments(center c: NSPoint, radius r: CGFloat, scale s: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let membrane = 30 * s, corner = 24 * s

        // Ruhende Segmente: ein gemeinsamer radialer Verlauf, innen heller.
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        NSColor.black.set()
        for i in 0..<segmentCount where i != poppedSegment {
            let wedge = segment(i, of: segmentCount, center: c, radius: r, membrane: membrane, corner: corner)
            wedge.fill()
            wedge.stroke()
        }
        context.setBlendMode(.sourceIn)
        NSGradient(colors: [NSColor(red: 0.8, green: 0.92, blue: 0.45, alpha: 1),
                            NSColor(red: 0.5, green: 0.74, blue: 0.16, alpha: 1)])!
            .draw(fromCenter: c, radius: 0, toCenter: c, radius: r, options: [])
        context.endTransparencyLayer()

        // Herausgezogenes Segment: heller, mit Schatten.
        let poppedCenter = offset(c, segment: poppedSegment, by: 46 * s)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        shadow.shadowBlurRadius = 30 * s
        shadow.shadowOffset = NSSize(width: 0, height: -12 * s)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        NSColor.black.set()
        let wedge = segment(poppedSegment, of: segmentCount, center: poppedCenter, radius: r, membrane: membrane, corner: corner)
        wedge.fill()
        wedge.stroke()
        context.setBlendMode(.sourceIn)
        NSGradient(colors: [NSColor(red: 0.96, green: 1, blue: 0.68, alpha: 1),
                            NSColor(red: 0.72, green: 0.9, blue: 0.24, alpha: 1)])!
            .draw(fromCenter: poppedCenter, radius: 0, toCenter: poppedCenter, radius: r, options: [])
        context.endTransparencyLayer()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Verschiebt einen Punkt in Richtung der Mitte von Segment i.
    private static func offset(_ p: NSPoint, segment i: Int, by distance: CGFloat) -> NSPoint {
        let mid = CGFloat.pi / 2 - CGFloat(i) * 2 * .pi / CGFloat(segmentCount)
        return NSPoint(x: p.x + cos(mid) * distance, y: p.y + sin(mid) * distance)
    }

    /// Ein Fruchtsegment: Keil zwischen zwei nach innen versetzten Radiallinien und dem Außenkreis.
    /// Wird gefüllt und mit runden Ecken umrandet; die Kontur (Breite 2·corner) rundet die Ecken ab.
    private static func segment(_ i: Int, of count: Int, center c: NSPoint, radius: CGFloat,
                                membrane: CGFloat, corner: CGFloat) -> NSBezierPath {
        let half = CGFloat.pi / CGFloat(count)
        let mid = CGFloat.pi / 2 - CGFloat(i) * 2 * half
        let d = membrane / 2 + corner        // Abstand der Kanten von der Radiallinie
        let outer = radius - corner

        func edgePoint(_ edgeAngle: CGFloat, inward: CGFloat) -> NSPoint {
            // Punkt auf der um d nach innen versetzten Kante, im Abstand `outer` von der Mitte.
            let t = sqrt(outer * outer - d * d)
            return NSPoint(x: c.x + cos(edgeAngle) * t + cos(edgeAngle + inward) * d,
                           y: c.y + sin(edgeAngle) * t + sin(edgeAngle + inward) * d)
        }
        let left = edgePoint(mid + half, inward: -.pi / 2)
        let right = edgePoint(mid - half, inward: .pi / 2)
        let apexDistance = d / sin(half)
        let apex = NSPoint(x: c.x + cos(mid) * apexDistance, y: c.y + sin(mid) * apexDistance)

        let path = NSBezierPath()
        path.move(to: apex)
        path.line(to: right)
        path.appendArc(withCenter: c, radius: outer,
                       startAngle: atan2(right.y - c.y, right.x - c.x) * 180 / .pi,
                       endAngle: atan2(left.y - c.y, left.x - c.x) * 180 / .pi)
        path.close()
        path.lineWidth = corner * 2
        path.lineJoinStyle = .round
        return path
    }
}
