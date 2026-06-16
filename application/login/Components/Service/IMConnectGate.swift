//
//  IMConnectGate.swift
//  Login
//
//  IM 连接 settled 等待门 — 解决"TUILogin.login 早回调 + 底层 ticket exchange 未完成"竞态
//
//  背景：
//    冷启动后调用 TUILogin.login 时，TUIKit 会基于 V2TIMManager.getLoginUser
//    走 "has login" 短路分支，立即同步触发 success 回调；但此时底层 V2TIM SDK
//    可能还在做 ticket exchange / online，期间 packet 会被 NotifyTicketChange
//    中断（错误码 6222 / 7009）。
//    业务在 success 回调里立即调用 getUsersInfo 容易撞上这个窗口。
//
//  设计：
//    暴露 `waitOnce(timeout:fire:)` 接口，调用后通过以下任一信号触发回调（互斥一次）：
//      ① V2TIMSDKListener.onConnectSuccess  ── 底层网络真正建立完成
//      ② V2TIMSDKListener.onConnectFailed   ── 底层连接失败（让上层 retry 自己判定真假）
//      ③ 超时（默认 1.0s）                  ── 兜底，避免事件未到永久阻塞
//
//  使用方式：
//    1. 在 LoginEntry.initialize() 中调用 IMConnectGate.shared.activate()，
//       确保 V2TIMSDKListener 在 TUILogin.login 之前就装好（避免漏掉 onConnectSuccess）。
//    2. ProfileManager 在 getUsersInfo 失败、且 getLoginStatus != LOGINED 时，
//       调用 waitOnce 等待 settled 后再 retry 一次。
//

import Foundation
import ImSDK_Plus

/// IM 连接 settled 等待门
///
/// 线程模型：所有内部状态访问都在主线程；`fire` 回调通过 main queue 投递。
final class IMConnectGate: NSObject {

    static let shared = IMConnectGate()
    private override init() { super.init() }

    /// 单次等待项 — 内部持有 fired 标志保证三选一互斥
    private final class PendingEntry {
        var fired = false
        let fire: () -> Void
        init(_ fire: @escaping () -> Void) { self.fire = fire }
    }

    private var pending: [PendingEntry] = []

    /// 是否已经把自己加为 V2TIMSDKListener（幂等）
    private var activated: Bool = false

    // MARK: - Public

    /// 激活监听 — 把自己挂到 V2TIMSDKListener，幂等，重复调用无副作用。
    ///
    /// 必须在 TUILogin.login 之前调用，否则可能漏掉首个 onConnectSuccess。
    func activate() {
        guard !activated else { return }
        activated = true
        V2TIMManager.sharedInstance().addIMSDKListener(listener: self)
        LoginLogger.Login.info("IMConnectGate.activate listener installed")
    }

    /// 等待 IM 连接 settled，settled 后或超时后触发 `fire` 一次。
    ///
    /// - Parameters:
    ///   - timeout: 最长等待时间（秒）。建议 1.0s，覆盖弱网下 ticket exchange 的常见延迟。
    ///   - fire: 触发时回调（事件 / 超时三选一，仅触发一次，主线程）。
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

        // 超时兜底
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.fire(entry: entry, reason: "timeout")
        }
    }

    // MARK: - Private

    /// 触发单个 entry（主线程）
    private func fire(entry: PendingEntry, reason: String) {
        guard !entry.fired else { return }
        entry.fired = true
        pending.removeAll { $0 === entry }
        LoginLogger.Login.info("IMConnectGate fire single reason=\(reason)")
        entry.fire()
    }

    /// 触发并清空所有 pending（主线程）
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

    /// 仅作为日志锚点，便于线上验证"短路命中时 onConnecting 是否早于 waitOnce 发出"。
    ///
    /// 不做控制流 gating：要求"waitOnce 之后必须看到 onConnecting 才认 onConnectSuccess"
    /// 会破坏冷启动主路径——activate() 早于 TUILogin.login 装载监听，此时 onConnecting
    /// 可能在 waitOnce 之前就已经 fire，业务侧没法重新观察到。
    /// "是否在连接中"这件事由 V2TIMManager.getLoginStatus() == .STATUS_LOGINING 权威判定，
    /// ProfileManager 在调 waitOnce 之前已经做了这层预检。
    func onConnecting() {
        LoginLogger.Login.info("IMConnectGate.onConnecting (log only)")
    }

    func onConnectSuccess() {
        DispatchQueue.main.async { [weak self] in
            self?.firePending(reason: "onConnectSuccess")
        }
    }

    func onConnectFailed(_ code: Int32, err: String?) {
        // 让上层 retry 自己判定：retry 时若 getUsersInfo 仍失败、getLoginStatus 也非 LOGINED，
        // 那才是真错误。
        DispatchQueue.main.async { [weak self] in
            self?.firePending(reason: "onConnectFailed code=\(code)")
        }
    }
}
