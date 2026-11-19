import AppKit
import ApplicationServices

enum CenteringError: LocalizedError {
    case permissionRequired
    case noWindow
    case fullScreen
    case cannotMove
    case noDisplay
    case accessibility(AXError)

    var errorDescription: String? {
        switch self {
        case .permissionRequired: "请先允许 Align 使用辅助功能。"
        case .noWindow: "当前应用没有可居中的窗口。"
        case .fullScreen: "请先退出窗口的全屏模式，再执行居中。"
        case .cannotMove: "这个窗口不支持移动，或已最小化。"
        case .noDisplay: "未找到可用的显示器。"
        case .accessibility(let error): "无法操作这个窗口（错误 \(error.rawValue)）。请重试，或切换到其他应用。"
        }
    }
}

@MainActor
enum WindowCenterer {
    static func focusedWindow() throws -> AXUIElement {
        guard AXIsProcessTrusted() else { throw CenteringError.permissionRequired }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw CenteringError.noWindow
        }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 1)
        var value: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &value)
        if result == .noValue || result == .attributeUnsupported {
            result = AXUIElementCopyAttributeValue(application, kAXMainWindowAttribute as CFString, &value)
        }
        if result == .noValue || result == .attributeUnsupported { throw CenteringError.noWindow }
        guard result == .success else { throw CenteringError.accessibility(result) }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { throw CenteringError.noWindow }
        // AXUIElement is a CF object; the type ID check validates this bridge.
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    static func center(_ window: AXUIElement) throws {
        guard AXIsProcessTrusted() else { throw CenteringError.permissionRequired }
        AXUIElementSetMessagingTimeout(window, 1)
        if try boolAttribute("AXFullScreen", of: window) { throw CenteringError.fullScreen }
        if try boolAttribute(kAXMinimizedAttribute, of: window) { throw CenteringError.cannotMove }

        var settable = DarwinBoolean(false)
        let settableResult = AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &settable)
        guard settableResult == .success else { throw CenteringError.accessibility(settableResult) }
        guard settable.boolValue else { throw CenteringError.cannotMove }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(try axValue(kAXPositionAttribute, of: window), .cgPoint, &position),
              AXValueGetValue(try axValue(kAXSizeAttribute, of: window), .cgSize, &size),
              position.x.isFinite, position.y.isFinite,
              size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            throw CenteringError.cannotMove
        }

        let screens = NSScreen.screens
        guard let primary = screens.first else { throw CenteringError.noDisplay }
        let displays = screens.map {
            Display(
                frame: WindowGeometry.accessibilityRect($0.frame, primaryTop: primary.frame.maxY),
                visibleFrame: WindowGeometry.accessibilityRect($0.visibleFrame, primaryTop: primary.frame.maxY)
            )
        }
        guard let display = WindowGeometry.targetDisplay(
            for: CGRect(origin: position, size: size), displays: displays
        ) else { throw CenteringError.noDisplay }
        var origin = WindowGeometry.centeredOrigin(size: size, in: display.visibleFrame)
        guard let value = AXValueCreate(.cgPoint, &origin) else { throw CenteringError.cannotMove }
        // Intentionally write position only. Never set AXSize or toggle zoom/full-screen.
        let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        guard result == .success else { throw CenteringError.accessibility(result) }
    }

    private static func boolAttribute(_ attribute: String, of element: AXUIElement) throws -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        if result == .noValue || result == .attributeUnsupported { return false }
        guard result == .success else { throw CenteringError.accessibility(result) }
        guard let boolean = value as? NSNumber else { throw CenteringError.cannotMove }
        return boolean.boolValue
    }

    private static func axValue(_ attribute: String, of element: AXUIElement) throws -> AXValue {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { throw CenteringError.accessibility(result) }
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { throw CenteringError.cannotMove }
        return unsafeDowncast(value, to: AXValue.self)
    }
}
