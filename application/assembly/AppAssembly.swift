//
//  AppAssembly.swift
//  AppAssembly
//
//  业务模块装配层 — 统一入口
//
//  职责：
//    1. 创建所有业务模块 Provider
//    2. 对外提供 allModuleProviders()，EntranceViewController 通过此函数获取首页模块列表
//    3. 处理生命周期 Handler 注册
//
//  EntranceViewController 不再需要 EntranceViewController+Module.swift，
//  直接调用 AppAssembly.shared.allModuleProviders() 即可。
//

import UIKit

// MARK: - AppTarget

/// App 构建目标枚举
///
/// 对应 3 个 Xcode target，用于运行时区分当前环境。
public enum AppTarget {
    /// 国内版（RTCube）
    case domestic
    /// 海外版（TencentRTC）
    case overseas
    /// 开发测试版（RTCubeLab）
    case lab
}

// MARK: - PrivacyAction

/// 隐私模块动作枚举
///
/// 将反诈提醒、屏幕共享反诈、实名认证、人脸核身等操作统一为枚举，
/// 由 main 模块通过 `privacyActionHandler` 进行 switch 分发。
public enum PrivacyAction {
    /// 通话反诈提醒（红色横幅 + 温馨提示弹窗）
    case showAntifraudReminder
    /// 实名认证检查，completion: (是否已认证, 消息)
    case checkRealNameAuth(userId: String, token: String, completion: (Bool, String) -> Void)
    /// 人脸核身 Token 获取，completion: (是否成功, faceToken)
    case showFaceIdTokenVerify(userId: String, token: String, completion: (Bool, String) -> Void)
    /// 开播10分钟体验时长提示弹窗（系统 Alert，需用户点击确认）
    case showLiveTimeLimitAlert
    /// 体验时长剩余1分钟 Toast（居中蓝灰色背景，5秒自动消失）
    case showLiveRemainingOneMinToast
    /// 房间内高风险 IP 用户提示（UIAlertController + 5秒倒计时按钮）
    case showHighRiskIPAlert
    /// 直播/通话超时关闭提示（UIAlertController，内容"已自动解散房间"）
    case showLiveTimeOutAlert(onDismiss: () -> Void)
}

// MARK: - AnalyticEvent

/// 埋点事件密封枚举
///
/// 由各业务模块通过 `AppAssembly.shared.analyticEventHandler` 派发，
/// 壳工程在首页注入实际的 `AppAnalytics.trackModuleEvent(...)` 逻辑。
public enum AnalyticEvent {
    case liveEvent(name: AnalyticName, params: [String: Any])
    case voiceRoomEvent(name: AnalyticName, params: [String: Any])
    case aiConversationEvent(name: AnalyticName, params: [String: Any])
    case interpretationEvent(name: AnalyticName, params: [String: Any])

    // MARK: - Convenience constructors (params 默认空 map)

    //
    // Swift enum 关联值不支持默认值，这里用同名静态方法做语法糖：
    // 调用方在没有附加参数时可省略 params，直接 `.liveEvent(name: ...)`。
    public static func liveEvent(name: AnalyticName) -> AnalyticEvent {
        .liveEvent(name: name, params: [:])
    }

    public static func voiceRoomEvent(name: AnalyticName) -> AnalyticEvent {
        .voiceRoomEvent(name: name, params: [:])
    }

    public static func aiConversationEvent(name: AnalyticName) -> AnalyticEvent {
        .aiConversationEvent(name: name, params: [:])
    }

    public static func interpretationEvent(name: AnalyticName) -> AnalyticEvent {
        .interpretationEvent(name: name, params: [:])
    }
}

// MARK: - AppAssembly

/// 业务模块装配中心
///
/// 将所有业务模块的创建与注册集中在此，
/// 首页仅需调用 `allModuleProviders()` 即可获得完整的模块列表。
public final class AppAssembly {
    public static let shared = AppAssembly()
    private init() {}

    /// 隐私模块统一动作回调
    ///
    /// 由壳工程 / main 模块设置，根据 `PrivacyAction` 枚举分发到
    /// `AntifraudAlertManager` 的不同方法。
    public var privacyActionHandler: ((PrivacyAction) -> Void)?

    /// 埋点事件统一回调
    ///
    /// 由壳工程 / main 模块设置，根据 `AnalyticEvent` 枚举分发到
    /// `AppAnalytics.trackModuleEvent(...)` 逻辑。
    public var analyticEventHandler: ((AnalyticEvent) -> Void)?

    // MARK: - Public API

    /// 获取所有场景模块
    ///
    /// 返回按首页展示顺序排列的全部 `ModuleProvider`。
    /// - Parameter target: 当前构建目标，由壳工程通过编译宏判断后传入。
    public func allModuleProviders(target: AppTarget) -> [ModuleProvider] {
        var providers: [ModuleProvider] = []

        switch target {
        case .overseas:
            // —— 海外版模块顺序（Products: Call→AI→Interpretation→Live→Chat→Beauty, Discovery: Player→UGSV）——
            providers.append(CallModule.standard(target: target))
            #if APPASSEMBLY_FULL
            providers.append(AIConversationModule.standard)
            providers.append(InterpretationModule.standard)
            #endif
            providers.append(RoomModule.standard)
            providers.append(LiveModule.standard(target: target))
            #if APPASSEMBLY_FULL
            providers.append(ChatModule.standard)
            providers.append(BeautyModule.standard)
            providers.append(PlayerModule.standard)
            #endif
        case .domestic, .lab:
            // —— 国内版 / Lab 版业务模块 ——
            providers.append(CallModule.standard(target: target))
            providers.append(LiveModule.standard(target: target))
            providers.append(RoomModule.standard)
            #if APPASSEMBLY_FULL
            providers.append(ChatModule.standard)
            providers.append(AIConversationModule.standard)
            providers.append(InterpretationModule.standard)
            #endif
            providers.append(VoiceRoomModule.standard)
            #if APPASSEMBLY_FULL
            providers.append(BeautyModule.standard)
            providers.append(PlayerModule.standard)
            providers.append(UGSVModule.standard)
            #endif
            providers.append(ScenesApplicationModule.standard)
        }

        return providers
    }

    /// 注册需要 App 生命周期回调的 handler
    ///
    /// 某些模块需要监听 didFinishLaunching、handleOpenURL 等回调，
    /// 在此处统一注册到 AppLifecycleRegistry。
    /// 注意：LoginEntry 内部的 IOAAuthManager 已自行注册，无需在此重复注册。
    ///
    /// TODO: 阶段 5 完成全局生命周期迁移后，取消注释
    public func registerLifecycleHandlers() {
        // // 示例：全局 Licence 设置（didFinishLaunching 时执行）
        // AppLifecycleRegistry.shared.register(LicenceLifecycleHandler.shared)
        //
        // // 示例：推送通知清理（willEnterForeground 时执行）
        // AppLifecycleRegistry.shared.register(NotificationLifecycleHandler.shared)
        //
        // // 示例：神策 SDK URL 处理（handleOpenURL 时执行）
        // AppLifecycleRegistry.shared.register(SensorsLifecycleHandler.shared)

        debugPrint("[AppAssembly] registerLifecycleHandlers - 阶段 5 完成后启用实际 handler 注册")
    }
}
