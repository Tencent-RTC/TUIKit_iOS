//
//  IMConnectGate.swift
//  Login
//

import Foundation
import ImSDK_Plus

final class IMConnectGate: NSObject {

    static let shared = IMConnectGate()
    private override init() { super.init() }

    private final class PendingEntry {
        var fired = false
        let fire: () -> Void
        init(_ fire: @escaping () -> Void) { self.fire = fire }
    }

    private var pending: [PendingEntry] = []

    private var activated: Bool = false

    // MARK: - Public

    func activate() {
        guard !activated else { return }
        activated = true
        V2TIMManager.sharedInstance().addIMSDKListener(listener: self)
        LoginLogger.Login.info("IMConnectGate.activate listener installed")
    }

    func waitOnce(timeout: TimeInterval, fire: @escaping () -> Void) {
        let entry = PendingEntry(fire)

        let enqueue: () -> Void = { [weak self] in
            self?.pending.append(entry)
        }
        if Thread.isMainThread {
            enqueue()
        } else {
            DispatchQueue.main.async(execute: enqueue)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.fire(entry: entry, reason: "timeout")
        }
    }

    // MARK: - Private

    private func fire(entry: PendingEntry, reason: String) {
        guard !entry.fired else { return }
        entry.fired = true
        pending.removeAll { $0 === entry }
        LoginLogger.Login.info("IMConnectGate fire single reason=\(reason)")
        entry.fire()
    }

    private func firePending(reason: String) {
        guard !pending.isEmpty else { return }
        let snapshot = pending
        pending.removeAll()
        LoginLogger.Login.info("IMConnectGate firePending reason=\(reason) count=\(snapshot.count)")
        for entry in snapshot where !entry.fired {
            entry.fired = true
            entry.fire()
        }
    }
}

// MARK: - V2TIMSDKListener

extension IMConnectGate: V2TIMSDKListener {

    func onConnecting() {
        LoginLogger.Login.info("IMConnectGate.onConnecting (log only)")
    }

    func onConnectSuccess() {
        DispatchQueue.main.async { [weak self] in
            self?.firePending(reason: "onConnectSuccess")
        }
    }

    func onConnectFailed(_ code: Int32, err: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.firePending(reason: "onConnectFailed code=\(code)")
        }
    }
}
