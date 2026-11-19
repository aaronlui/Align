import AppKit
import ApplicationServices
import Carbon
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var menuWindow: AXUIElement?
    private let launchAtLoginItem = NSMenuItem(title: "开机自启动", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.button?.image = NSImage(systemSymbolName: "rectangle.center.inset.filled", accessibilityDescription: "Align")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self
        let centerItem = command("居中", action: #selector(centerFromMenu), key: "c")
        centerItem.keyEquivalentModifierMask = [.control, .shift]
        menu.addItem(centerItem)
        menu.addItem(command("辅助功能设置…", action: #selector(openAccessibilitySettings)))
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(command("退出", action: #selector(quit), key: "q"))
        item.menu = menu

        if registerHotKey() != noErr {
            centerItem.keyEquivalent = ""
            showError("快捷键 ⌃⇧C 不可用，请使用菜单居中。")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuWindow = try? WindowCenterer.focusedWindow()
        menu.item(at: 1)?.isHidden = AXIsProcessTrusted()
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else if service.status != .requiresApproval {
                try service.register()
            }
        } catch {
            showError("无法更改开机自启动：\(error.localizedDescription)")
        }
        sender.state = service.status == .enabled ? .on : .off
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    @objc private func centerFromMenu() {
        let window = menuWindow
        // Let menu tracking finish without losing the original focused window.
        DispatchQueue.main.async { [weak self] in self?.center(window) }
    }

    private func center(_ window: AXUIElement? = nil) {
        do {
            try WindowCenterer.center(window ?? WindowCenterer.focusedWindow())
        } catch CenteringError.permissionRequired {
            openAccessibilitySettings()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func registerHotKey() -> OSStatus {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // This app registers a single hotkey, and retains its delegate for the process lifetime.
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().center()
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { return status }
        return RegisterEventHotKey(
            UInt32(kVK_ANSI_C), UInt32(controlKey | shiftKey), EventHotKeyID(signature: 0x414C474E, id: 1),
            GetApplicationEventTarget(), 0, &hotKey
        )
    }

    @objc private func openAccessibilitySettings() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
              NSWorkspace.shared.open(url) else {
            showError("请在系统设置的“隐私与安全性 → 辅助功能”中开启 Align。")
            return
        }
    }

    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func command(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
