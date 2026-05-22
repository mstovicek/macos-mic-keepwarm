import AppKit
import MicWarmCore

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private let keeper = MicKeeper(pidPath: "/tmp/mic-warm-app.pid")
    private var statusItem: NSStatusItem!
    private let defaults = UserDefaults.standard
    private let warmKey = "micWarmEnabled"
    private var isStartingFromUserAction = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Left click = toggle. Right click = menu (handled in sendEvent override below).
        statusItem.button?.action = #selector(handleClick)
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // onStateChange is always called on the main queue by MicKeeper.
        // Only write defaults when confirming a user-initiated start — internal device-switch
        // restarts also fire onStateChange and must not overwrite the persisted preference.
        keeper.onStateChange = { [weak self] isWarm in
            guard let self else { return }
            if isWarm && self.isStartingFromUserAction {
                self.defaults.set(true, forKey: self.warmKey)
                self.isStartingFromUserAction = false
            }
            self.updateIcon(isWarm: isWarm)
        }

        let shouldStart = defaults.object(forKey: warmKey) as? Bool ?? true
        if shouldStart {
            log("mic-warm-app starting (PID: \(ProcessInfo.processInfo.processIdentifier), version: \(micWarmVersion))")
            keeper.start()
        } else {
            log("mic-warm-app starting cold (PID: \(ProcessInfo.processInfo.processIdentifier), version: \(micWarmVersion))")
            updateIcon(isWarm: false)  // onStateChange not fired when keeper never starts
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleWarm()
        }
    }

    private func updateIcon(isWarm: Bool) {
        let iconName = isWarm ? "mic.fill" : "mic.slash.fill"
        let iconDesc = isWarm ? "Mic Warm" : "Mic Cold"
        statusItem.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: iconDesc)
        statusItem.button?.image?.isTemplate = true
    }

    private func showMenu() {
        let isWarm = keeper.isWarm
        let menu = NSMenu()

        let statusLabel = NSMenuItem(title: isWarm ? "Mic is warm 🔥" : "Mic is cold", action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: isWarm ? "Turn Off" : "Turn On", action: #selector(toggleWarm), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleWarm() {
        if keeper.isWarm {
            keeper.stop()
            defaults.set(false, forKey: warmKey)  // stop() is synchronous — safe to write here
        } else {
            isStartingFromUserAction = true        // next onStateChange?(true) is user-requested
            keeper.start()
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
