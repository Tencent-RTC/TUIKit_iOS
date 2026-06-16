//
//  LoginSubStore.swift
//  login
//
//  所有登录子模块 Store 遵循的协议
//

import Combine

/// 所有登录子模块 Store 遵循的协议
///
/// 要求两件事：
///   1. 能发出登录结果（`resultPublisher`）
///   2. 能在登出时重置自身状态（`resetState()`）
///
/// ### 登出清理机制
///
/// `LoginEntry.performLogout()` 会通过 `LoginSubStore.logoutSubject` 发送信号，
/// 各 Store 在 `init` 中调用 `subscribeLogout()` 即可自动监听并执行 `resetState()`。
/// View 通过已有的 `$state` 订阅感知状态变化，无需全局通知。
protocol LoginSubStore: AnyObject {
    var resultPublisher: AnyPublisher<Result<LoginResult, LoginError>, Never> { get }

    /// 重置 Store 状态到初始值（登出时调用）
    func resetState()
}

extension LoginSubStore {
    /// 登出信号源（由 `LoginEntry.performLogout()` 发送）
    static var logoutSubject: PassthroughSubject<Void, Never> {
        LoginSubStoreLogoutSignal.shared.subject
    }

    /// 在 Store 的 `init` 中调用，自动订阅登出信号并执行 `resetState()`
    ///
    /// 返回的 `AnyCancellable` 需要被 Store 持有（存入 `cancellables` 或作为属性保留），
    /// 否则订阅会立即释放。
    func subscribeLogout() -> AnyCancellable {
        Self.logoutSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.resetState()
            }
    }
}

/// 登出信号的全局单例容器（避免协议静态属性的存储限制）
final class LoginSubStoreLogoutSignal {
    static let shared = LoginSubStoreLogoutSignal()
    let subject = PassthroughSubject<Void, Never>()
    private init() {}
}
