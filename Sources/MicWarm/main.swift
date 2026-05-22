import Darwin
import Foundation
import MicWarmCore

// MARK: - Signal handling & main

let keeper = MicKeeper()

func installSignalHandlers() {
    let handler: @convention(c) (Int32) -> Void = { _ in
        signal(SIGTERM, SIG_DFL)
        signal(SIGINT, SIG_DFL)
        keeper.signalShutdown()
        _exit(0)
    }
    signal(SIGTERM, handler)
    signal(SIGINT, handler)
}

installSignalHandlers()
log("mic-warm starting (PID: \(ProcessInfo.processInfo.processIdentifier), version: \(micWarmVersion))")
keeper.start()
dispatchMain()
