import AppKit
import BarsaverCore
import Foundation
import ServiceManagement

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    private let configURL = URL(fileURLWithPath: NSString(string: "~/Library/Application Support/barsaver/barsaver.yaml").expandingTildeInPath)
    private let repoURL = URL(string: "https://github.com/ericcastro/barsaver")!
    private let wikiURL = URL(string: "https://github.com/ericcastro/barsaver/wiki")!

    private var statusItem: NSStatusItem?
    private var runtime: BarsaverRuntime?
    private var configuration: MarqueeConfigurationFile?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
        ensureUserConfigExists()
        loadAndStartRuntime()
        setupStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime?.stop()
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "barsaver"
        statusItem.menu = buildMenu()
        self.statusItem = statusItem
    }

    private func rebuildMenu() {
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)

        let showInItem = NSMenuItem(title: "Show In", action: nil, keyEquivalent: "")
        showInItem.submenu = buildShowInMenu()
        menu.addItem(showInItem)

        menu.addItem(.separator())

        let configureItem = NSMenuItem(title: "Configure Blocks…", action: #selector(openConfig), keyEquivalent: "")
        configureItem.target = self
        menu.addItem(configureItem)

        let reloadItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "")
        reloadItem.target = self
        menu.addItem(reloadItem)

        let helpItem = NSMenuItem(title: "Blocks Help", action: #selector(openWiki), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)

        let aboutItem = NSMenuItem(title: "About", action: #selector(openRepo), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    private func buildShowInMenu() -> NSMenu {
        let submenu = NSMenu()
        let currentSelection = runtime?.selection ?? .all

        submenu.addItem(makeSelectionItem(title: "All Displays", selection: .all, currentSelection: currentSelection))
        submenu.addItem(makeSelectionItem(title: "External Displays", selection: .external, currentSelection: currentSelection))
        submenu.addItem(.separator())

        for display in DisplayManager.currentDisplays() {
            let label = "Screen \(display.index) (\(display.resolutionDescription))"
            submenu.addItem(makeSelectionItem(title: label, selection: .indices([display.index]), currentSelection: currentSelection))
        }

        return submenu
    }

    private func makeSelectionItem(title: String, selection: DisplaySelection, currentSelection: DisplaySelection) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(selectDisplayTarget(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = selection
        item.state = selection == currentSelection ? .on : .off
        return item
    }

    private func ensureUserConfigExists() {
        guard !FileManager.default.fileExists(atPath: configURL.path) else {
            return
        }

        let config = MarqueeConfigurationFile(
            settings: ["hold_to_click_key": "escape", "display_selection": "all"],
            blocks: [
                MarqueeBlockDefinition(type: "static_text", settings: ["value": "barsaver"]),
                MarqueeBlockDefinition(type: "timestamp", settings: ["format": "HH:mm"]),
                MarqueeBlockDefinition(type: "static_text", settings: ["value": "OLED-safe menubar"])
            ]
        )
        try? MarqueeConfiguration.save(config, to: configURL)
    }

    private func loadAndStartRuntime() {
        do {
            let configuration = try MarqueeConfiguration.load(from: configURL.path)
            let selection = try MarqueeConfiguration.displaySelection(from: configuration)
            runtime?.stop()
            runtime = try BarsaverRuntime(configuration: configuration, selection: selection)
            runtime?.start()
            self.configuration = configuration
            rebuildMenu()
        } catch {
            NSLog("barsaver-app failed to start runtime: \(error.localizedDescription)")
        }
    }

    private var isLaunchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc
    private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        guard #available(macOS 13.0, *) else {
            return
        }
        do {
            if isLaunchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            rebuildMenu()
        } catch {
            NSLog("Failed to update login item registration: \(error.localizedDescription)")
        }
    }

    @objc
    private func selectDisplayTarget(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? DisplaySelection else {
            return
        }
        runtime?.selection = selection
        updateStoredSelection(selection)
        rebuildMenu()
    }

    private func updateStoredSelection(_ selection: DisplaySelection) {
        guard var configuration else { return }
        var settings = configuration.settings
        switch selection {
        case .all:
            settings["display_selection"] = "all"
        case .external:
            settings["display_selection"] = "external"
        case .indices(let indices):
            settings["display_selection"] = indices.sorted().map(String.init).joined(separator: ",")
        }
        configuration = MarqueeConfigurationFile(settings: settings, blocks: configuration.blocks)
        self.configuration = configuration
        try? MarqueeConfiguration.save(configuration, to: configURL)
    }

    @objc
    private func openConfig() {
        NSWorkspace.shared.open(configURL)
    }

    @objc
    private func reloadConfig() {
        loadAndStartRuntime()
    }

    @objc
    private func openWiki() {
        NSWorkspace.shared.open(wikiURL)
    }

    @objc
    private func openRepo() {
        NSWorkspace.shared.open(repoURL)
    }
}
