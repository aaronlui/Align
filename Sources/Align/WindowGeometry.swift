import CoreGraphics

struct Display {
    let frame: CGRect
    let visibleFrame: CGRect
}

enum WindowGeometry {
    /// AppKit uses a bottom-left origin; Accessibility uses the primary screen's top-left.
    static func accessibilityRect(_ rect: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height)
    }

    static func targetDisplay(for window: CGRect, displays: [Display]) -> Display? {
        let center = CGPoint(x: window.midX, y: window.midY)
        func score(_ display: Display) -> (CGFloat, CGFloat) {
            let intersection = window.intersection(display.frame)
            let area = intersection.isNull ? 0 : intersection.width * intersection.height
            let dx = max(display.frame.minX - center.x, 0, center.x - display.frame.maxX)
            let dy = max(display.frame.minY - center.y, 0, center.y - display.frame.maxY)
            return (-area, dx * dx + dy * dy)
        }
        return displays.min { score($0) < score($1) }
    }

    static func centeredOrigin(size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: (visibleFrame.midX - size.width / 2).rounded(),
            y: (visibleFrame.midY - size.height / 2).rounded()
        )
    }
}
