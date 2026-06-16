//
//  CallAntifraudHandler.swift
//  Call
//
//  通话反诈提示 — 通话开始时触发反诈提示回调
//
//  职责：
//    - 订阅 CallStore.shared.callEventPublisher
//    - 识别 CallEvent.onCallStarted 事件
//    - 通过 AppAssembly.shared.showAntifraudReminderHandler 回调弹出反诈提示
//

import Combine
import AtomicXCore
import Login

// MARK: - CallAntifraudHandler

/// 通话反诈提示处理器
///
/// 监听通话事件，在通话接通时通过 AppAssembly 的回调触发反诈提示。
/// UI 实现由 privacy 模块提供，壳工程负责将其注入到 AppAssembly。
///
/// 跳过条件（与旧版 PrivacyService.m L101-L120 行为一致）：
///   - 海外版（TencentRTC App）
///   - MOA（企业内部）登录用户
final class CallAntifraudHandler {

    static let shared = CallAntifraudHandler()
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    /// 注册事件监听，由 CallModule 初始化时调用
    func register() {
        // 只订阅 selfInfo.status 字段，避免 mic/camera 状态变化时重复触发反诈弹窗。
        // 旧实现订阅整个 selfInfo 结构体，当用户开关麦克风时 isMicrophoneOpened 变化
        // 导致 removeDuplicates() 无法过滤，每次都重新弹窗。
        CallStore.shared.state
            .subscribe(StatePublisherSelector<CallState, CallParticipantStatus>(keyPath: \.selfInfo.status))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { status in
                if status == .accept {
                    // 海外版（TencentRTC App）跳过
                    guard Bundle.main.bundleIdentifier != "com.tencent.rtc.app" else { return }
                    // MOA（企业内部）登录用户跳过
                    if let user = LoginManager.shared.getCurrentUser(), user.isMoa() { return }

                    AppAssembly.shared.privacyActionHandler?(.showAntifraudReminder)
                }
            }
            .store(in: &cancellables)
    }

}
