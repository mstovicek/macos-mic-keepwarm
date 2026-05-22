import AppKit
import MicWarmCore

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private let keeper = MicKeeper()
    private var statusItem: NSStatusItem!
    private let defaults = UserDefaults.standard
    private let warmKey = "micWarmEnabled"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        keeper.onStateChange = { [weak self] isWarm in
            DispatchQueue.main.async { self?.updateMenu(isWarm: isWarm) }
        }

        let shouldStart = defaults.object(forKey: warmKey) as? Bool ?? true
        if shouldStart {
            log("mic-warm-app starting (PID: \(ProcessInfo.processInfo.processIdentifier), version: 0.9.3)")
            keeper.start()
        } else {
            log("mic-warm-app starting cold (PID: \(ProcessInfo.processInfo.processIdentifier), version: 0.9.3)")
            updateMenu(isWarm: false)
        }
    }

    private func updateMenu(isWarm: Bool) {
        let button = statusItem.button
        let iconName = isWarm ? "mic.fill" : "mic.slash.fill"
        let iconDesc = isWarm ? "Mic Warm" : "Mic Cold"
        button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: iconDesc)
        button?.image?.isTemplate = true

        let menu = NSMenu()

        let statusLabel = NSMenuItem(title: isWarm ? "Mic is warm 🔥" : "Mic is cold", action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: isWarm ? "Turn Off" : "Turn On", action: #selector(toggleWarm), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusItem.menu = menu
    }

    @objc private func toggleWarm() {
        if keeper.isWarm {
            keeper.stop()
            defaults.set(false, forKey: warmKey)
        } else {
            keeper.start()
            defaults.set(true, forKey: warmKey)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        keeper.shutdown()
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
