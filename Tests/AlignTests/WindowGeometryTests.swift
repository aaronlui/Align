import CoreGraphics
import Testing
@testable import Align

struct WindowGeometryTests {
    let main = Display(
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 825)
    )
    let right = Display(
        frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1000)
    )

    @Test func centersInUsableArea() {
        let size = CGSize(width: 800, height: 600)
        let origin = WindowGeometry.centeredOrigin(size: size, in: main.visibleFrame)
        #expect(origin == CGPoint(x: 320, y: 138))
    }

    @Test func convertsScreensAboveAndBelowPrimary() {
        #expect(WindowGeometry.accessibilityRect(
            CGRect(x: -1200, y: 900, width: 1200, height: 800), primaryTop: 900
        ) == CGRect(x: -1200, y: -800, width: 1200, height: 800))
        #expect(WindowGeometry.accessibilityRect(
            CGRect(x: 0, y: -800, width: 1200, height: 800), primaryTop: 900
        ) == CGRect(x: 0, y: 900, width: 1200, height: 800))
    }

    @Test func choosesScreenWithLargestOverlap() {
        let display = WindowGeometry.targetDisplay(
            for: CGRect(x: 1300, y: 100, width: 800, height: 600), displays: [main, right]
        )
        #expect(display?.frame == right.frame)
    }

    @Test func centersOnScreenLeftOfPrimary() {
        let visible = CGRect(x: -1920, y: -300, width: 1920, height: 1000)
        #expect(WindowGeometry.centeredOrigin(size: CGSize(width: 800, height: 600), in: visible)
            == CGPoint(x: -1360, y: -100))
    }

    @Test func recoversOffscreenWindowToNearestDisplay() {
        #expect(WindowGeometry.targetDisplay(
            for: CGRect(x: 4000, y: 100, width: 500, height: 500), displays: [main, right]
        )?.frame == right.frame)
    }

    @Test func oversizedWindowIsCenteredWithoutShrinking() {
        let size = CGSize(width: 1800, height: 1000)
        #expect(WindowGeometry.centeredOrigin(size: size, in: main.visibleFrame)
            == CGPoint(x: -180, y: -63))
    }

    @Test func roundsFractionalCoordinates() {
        #expect(WindowGeometry.centeredOrigin(
            size: CGSize(width: 801, height: 601), in: CGRect(x: 0, y: 0, width: 1440, height: 900)
        ) == CGPoint(x: 320, y: 150))
    }

    @Test func emptyScreensReturnNil() {
        #expect(WindowGeometry.targetDisplay(for: .zero, displays: []) == nil)
    }

    @Test func overlapTieIsStable() {
        let right = Display(
            frame: CGRect(x: 1440, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 1440, y: 25, width: 1440, height: 825)
        )
        #expect(WindowGeometry.targetDisplay(
            for: CGRect(x: 1040, y: 100, width: 800, height: 600), displays: [main, right]
        )?.frame == main.frame)
    }
}
