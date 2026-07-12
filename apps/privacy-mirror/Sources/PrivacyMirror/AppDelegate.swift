import AppKit
import PrivacyMirrorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var outputWindow: NSWindow?
    private var mirrorView: MirrorView?
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var privateWorkspacesMenuItem: NSMenuItem?
    private var captureController: CaptureController?
    private var controlServer: ControlServer?
    private lazy var configurationURL = resolveConfigurationURL()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        installStatusItem()
        createWindows()
        reloadConfiguration()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        controlServer?.stop()
        captureController?.stop()
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
                    onStatus: { [weak self] status in self?.updateStatus(status) }
                )
                captureController = controller
                startControlServer(controller: controller)
                controller.start()
            }
            privateWorkspacesMenuItem?.title = "Private workspaces: \(configuration.excludedWorkspaces.joined(separator: ", "))"
        } catch {
            let message = "Configuration error: \(error.localizedDescription)"
            if let captureController {
                captureController.invalidate(reason: message)
            } else {
                mirrorView.showError(message)
                updateStatus(message)
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
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        outputWindow.contentView = mirrorView
        outputWindow.title = "Privacy Mirror Output"
        outputWindow.titleVisibility = .hidden
        outputWindow.titlebarAppearsTransparent = true
        outputWindow.isOpaque = true
        outputWindow.backgroundColor = .black
        outputWindow.ignoresMouseEvents = true
        outputWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        outputWindow.level = .normal
        outputWindow.orderBack(nil)

        self.mirrorView = mirrorView
        self.outputWindow = outputWindow
        parkOutputWindow()
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

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "PM"

        let menu = NSMenu()
        let status = NSMenuItem(title: "Starting Privacy Mirror…", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let privateWorkspaces = NSMenuItem(title: "Private workspaces: loading…", action: nil, keyEquivalent: "")
        privateWorkspaces.isEnabled = false
        menu.addItem(privateWorkspaces)
        menu.addItem(.separator())

        let reload = NSMenuItem(title: "Reload Configuration", action: #selector(reloadConfiguration), keyEquivalent: "r")
        reload.target = self
        menu.addItem(reload)

        let showOutput = NSMenuItem(title: "Show Output Window", action: #selector(showOutputWindow), keyEquivalent: "")
        showOutput.target = self
        menu.addItem(showOutput)

        let parkOutput = NSMenuItem(title: "Park Output Window", action: #selector(parkOutputWindow), keyEquivalent: "")
        parkOutput.target = self
        menu.addItem(parkOutput)
        menu.addItem(.separator())

        menu.addItem(withTitle: "Quit Privacy Mirror", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
        statusMenuItem = status
        privateWorkspacesMenuItem = privateWorkspaces
    }

    @objc private func showOutputWindow() {
        guard let outputWindow, let screen = NSScreen.main else { return }
        outputWindow.level = .normal
        outputWindow.setFrame(screen.frame, display: true)
        outputWindow.orderFrontRegardless()
    }

    @objc private func parkOutputWindow() {
        guard let outputWindow, let screen = NSScreen.main else { return }
        outputWindow.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1
        )
        outputWindow.setFrame(screen.frame, display: true)
        outputWindow.orderBack(nil)
    }

    private func updateStatus(_ status: String) {
        statusMenuItem?.title = status
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
