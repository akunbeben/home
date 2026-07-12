import AppKit
import PrivacyMirrorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var controlWindow: NSWindow?
    private var outputWindow: NSWindow?
    private var mirrorView: MirrorView?
    private let statusLabel = NSTextField(wrappingLabelWithString: "Starting Privacy Mirror…")
    private var captureController: CaptureController?
    private var controlServer: ControlServer?
    private lazy var configurationURL = resolveConfigurationURL()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        createWindows()
        reloadConfiguration()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        controlServer?.stop()
        captureController?.stop()
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === controlWindow {
            NSApp.terminate(nil)
        }
    }

    @objc private func reloadConfiguration() {
        guard let mirrorView else { return }
        do {
            let configuration = try AppConfiguration.load(from: configurationURL)
            if let captureController {
                captureController.apply(configuration: configuration)
            } else {
                let controller = CaptureController(
                    mirrorView: mirrorView,
                    aeroSpace: try AeroSpaceClient(),
                    configuration: configuration,
                    onStatus: { [weak self] status in self?.statusLabel.stringValue = status }
                )
                captureController = controller
                startControlServer(controller: controller)
                controller.start()
            }
            controlWindow?.title = "Privacy Mirror — private: \(configuration.excludedWorkspaces.joined(separator: ", "))"
        } catch {
            let message = "Configuration error: \(error.localizedDescription)"
            if let captureController {
                captureController.invalidate(reason: message)
            } else {
                mirrorView.showError(message)
                statusLabel.stringValue = message
            }
        }
    }

    private func startControlServer(controller: CaptureController) {
        guard controlServer == nil else { return }
        let server = ControlServer()
        do {
            try server.start { [weak controller] reply in
                DispatchQueue.main.async {
                    guard let controller else {
                        reply(false)
                        return
                    }
                    controller.prepareForWindowMove(completion: reply)
                }
            }
            controlServer = server
        } catch {
            controller.invalidate(reason: error.localizedDescription)
        }
    }

    private func createWindows() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        let mirrorView = MirrorView(frame: NSRect(origin: .zero, size: screenFrame.size))
        let outputWindow = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        outputWindow.contentView = mirrorView
        outputWindow.title = "Privacy Mirror Output"
        outputWindow.isOpaque = true
        outputWindow.backgroundColor = .black
        outputWindow.ignoresMouseEvents = true
        outputWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        outputWindow.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1
        )
        outputWindow.setAccessibilityElement(false)
        outputWindow.orderBack(nil)

        let controlContent = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 150))
        statusLabel.frame = NSRect(x: 24, y: 42, width: 412, height: 72)
        statusLabel.alignment = .center
        statusLabel.font = .systemFont(ofSize: 15)
        controlContent.addSubview(statusLabel)

        let controlWindow = NSWindow(
            contentRect: controlContent.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        controlWindow.contentView = controlContent
        controlWindow.delegate = self
        controlWindow.center()
        controlWindow.makeKeyAndOrderFront(nil)

        self.mirrorView = mirrorView
        self.outputWindow = outputWindow
        self.controlWindow = controlWindow
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        let reloadItem = NSMenuItem(
            title: "Reload Configuration",
            action: #selector(reloadConfiguration),
            keyEquivalent: "r"
        )
        reloadItem.target = self
        appMenu.addItem(reloadItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Privacy Mirror", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func resolveConfigurationURL() -> URL {
        let arguments = CommandLine.arguments
        if let flagIndex = arguments.firstIndex(of: "--config"), arguments.indices.contains(flagIndex + 1) {
            return URL(fileURLWithPath: NSString(string: arguments[flagIndex + 1]).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/privacy-mirror/config.json")
    }
}
