//
//  AppAssembly.swift
//  AppAssembly
//

import UIKit

// MARK: - AppTarget

public enum AppTarget {
    case domestic
    case overseas
    case lab
}

// MARK: - PrivacyAction

public enum PrivacyAction {
    case showAntifraudReminder
    case checkRealNameAuth(userId: String, token: String, completion: (Bool, String) -> Void)
    case showFaceIdTokenVerify(userId: String, token: String, completion: (Bool, String) -> Void)
    case showLiveTimeLimitAlert
    case showLiveRemainingOneMinToast
    case showHighRiskIPAlert
    case showLiveTimeOutAlert(onDismiss: () -> Void)
}

// MARK: - AnalyticEvent

public enum AnalyticEvent {
    case liveEvent(name: AnalyticName, params: [String: Any])
    case voiceRoomEvent(name: AnalyticName, params: [String: Any])
    case aiConversationEvent(name: AnalyticName, params: [String: Any])
    case interpretationEvent(name: AnalyticName, params: [String: Any])

    //
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

public final class AppAssembly {
    public static let shared = AppAssembly()
    private init() {}

    public var privacyActionHandler: ((PrivacyAction) -> Void)?

    public var analyticEventHandler: ((AnalyticEvent) -> Void)?

    // MARK: - Public API

    public func allModuleProviders(target: AppTarget) -> [ModuleProvider] {
        var providers: [ModuleProvider] = []

        switch target {
        case .overseas:
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

    public func registerLifecycleHandlers() {
        // AppLifecycleRegistry.shared.register(LicenceLifecycleHandler.shared)
        //
        // AppLifecycleRegistry.shared.register(NotificationLifecycleHandler.shared)
        //
        // AppLifecycleRegistry.shared.register(SensorsLifecycleHandler.shared)

        debugPrint("[AppAssembly] registerLifecycleHandlers - 阶段 5 完成后启用实际 handler 注册")
    }
}
