import UIKit

final class DebouncedClick {
    private var lastClickTimes: [ObjectIdentifier: TimeInterval] = [:]

    func perform(for control: UIControl, interval: TimeInterval = 1, action: () -> Void) {
        let now = ProcessInfo.processInfo.systemUptime
        let key = ObjectIdentifier(control)
        if let lastClick = lastClickTimes[key], now - lastClick < interval { return }
        lastClickTimes[key] = now
        action()
    }
}
