//
//  AudienceStore.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/18.
//

import AtomicXCore
import AtomicX
import Combine
import Foundation
import RTCCommon

class AudienceStore {
    class Context {
        let liveID: String

        let deviceStore: DeviceStore = .shared
        let liveListStore: LiveListStore = .shared
        let loginStore: LoginStore = .shared

        var coGuestStore: CoGuestStore {
            CoGuestStore.create(liveID: liveID)
        }

        var battleStore: BattleStore {
            BattleStore.create(liveID: liveID)
        }

        var coHostStore: CoHostStore {
            CoHostStore.create(liveID: liveID)
        }

        var seatStore: LiveSeatStore {
            LiveSeatStore.create(liveID: liveID)
        }

        var liveAudienceStore: LiveAudienceStore {
            LiveAudienceStore.create(liveID: liveID)
        }

        lazy var audienceMediaManager = AudienceMediaStore(context: self)

        let audienceObservableState = ObservableState(initialState: AudienceState())
        let audienceBattleObservableState = ObservableState(initialState: AudienceBattleState())

        let toastSubject = PassthroughSubject<(String, ToastStyle), Never>()
        let kickedOutSubject = PassthroughSubject<Void, Never>()
        let floatWindowSubject = PassthroughSubject<Void, Never>()

        init(liveID: String) {
            self.liveID = liveID
        }
    }

    private let context: Context

    private static let observerAudienceConfig = ObservableState<AudienceContainerConfig>(initialState: AudienceContainerConfig())
    static var audienceContainerConfig: AudienceContainerConfig {
        observerAudienceConfig.state
    }

    init(liveID: String) {
        context = Context(liveID: liveID)
    }

    func willApplying() {
        context.audienceObservableState.update { state in
            state.isApplying = true
        }
    }

    func stopApplying() {
        context.audienceObservableState.update { state in
            state.isApplying = false
        }
    }

    var liveID: String {
        context.liveID
    }

    var selfUserID: String {
        loginState.loginUserInfo?.userID ?? ""
    }

    var audienceMediaManager: AudienceMediaStore {
        context.audienceMediaManager
    }

    func updateBattleDurationCountDown(_ value: Int) {
        context.audienceBattleObservableState.update { state in
            state.durationCountDown = value
        }
    }
    
    func updateVideoStreamIsLandscape(_ isLandscape: Bool) {
        context.audienceObservableState.update { state in
            state.roomVideoStreamIsLandscape = isLandscape
        }
    }
}

// MARK: - Subject

extension AudienceStore {
    var toastSubject: PassthroughSubject<(String, ToastStyle), Never> {
        context.toastSubject
    }

    var kickedOutSubject: PassthroughSubject<Void, Never> {
        context.kickedOutSubject
    }

    var floatWindowSubject: PassthroughSubject<Void, Never> {
        context.floatWindowSubject
    }
}

// MARK: - Store

extension AudienceStore {
    var coGuestStore: CoGuestStore {
        context.coGuestStore
    }

    var battleStore: BattleStore {
        context.battleStore
    }

    var seatStore: LiveSeatStore {
        context.seatStore
    }

    var deviceStore: DeviceStore {
        context.deviceStore
    }

    var liveListStore: LiveListStore {
        context.liveListStore
    }

    var coHostStore: CoHostStore {
        context.coHostStore
    }

    var loginStore: LoginStore {
        context.loginStore
    }

    var liveAudienceStore: LiveAudienceStore {
        context.liveAudienceStore
    }
}

// MARK: - State and subscribe

extension AudienceStore {
    var audienceState: AudienceState {
        context.audienceState
    }

    var audienceBattleState: AudienceBattleState {
        context.audienceBattleState
    }

    var audienceMediaState: AudienceMediaState {
        context.audienceMediaManager.mediaState
    }

    var seatState: LiveSeatState {
        context.seatState
    }

    var coGuestState: CoGuestState {
        context.coGuestState
    }

    var battleState: BattleState {
        context.battleState
    }

    var deviceState: DeviceState {
        context.deviceState
    }

    var liveListState: LiveListState {
        context.liveListState
    }

    var coHostState: CoHostState {
        context.coHostState
    }

    var loginState: LoginState {
        context.loginState
    }

    func subscribeState<State, Value>(_ selector: StatePublisherSelector<State, Value>) -> AnyPublisher<Value, Never> {
        context.subscribeState(selector)
    }

    func subscribeState<State, Value>(_ selector: StateSelector<State, Value>) -> AnyPublisher<Value, Never> {
        context.subscribeState(selector)
    }
}

extension AudienceStore.Context {
    var audienceState: AudienceState {
        audienceObservableState.state
    }

    var audienceBattleState: AudienceBattleState {
        audienceBattleObservableState.state
    }

    var seatState: LiveSeatState {
        seatStore.state.value
    }

    var coGuestState: CoGuestState {
        coGuestStore.state.value
    }

    var battleState: BattleState {
        battleStore.state.value
    }

    var deviceState: DeviceState {
        deviceStore.state.value
    }

    var liveListState: LiveListState {
        liveListStore.state.value
    }

    var coHostState: CoHostState {
        coHostStore.state.value
    }

    var loginState: LoginState {
        loginStore.state.value
    }

    func subscribeState<State, Value>(_ selector: StatePublisherSelector<State, Value>) -> AnyPublisher<Value, Never> {
        if let sel = selector as? StatePublisherSelector<CoGuestState, Value> {
            return coGuestStore.state.subscribe(sel)
        } else if let sel = selector as? StatePublisherSelector<BattleState, Value> {
            return battleStore.state.subscribe(sel)
        } else if let sel = selector as? StatePublisherSelector<DeviceState, Value> {
            return deviceStore.state.subscribe(sel)
        } else if let sel = selector as? StatePublisherSelector<LiveListState, Value> {
            return liveListStore.state.subscribe(sel)
        } else if let sel = selector as? StatePublisherSelector<CoHostState, Value> {
            return coHostStore.state.subscribe(sel)
        } else if let sel = selector as? StatePublisherSelector<LoginState, Value> {
            return loginStore.state.subscribe(sel)
        } else if let sel = selector as? StatePublisherSelector<LiveSeatState, Value> {
            return seatStore.state.subscribe(sel)
        }
        assertionFailure("Input failed State class")
        return Empty<Value, Never>().eraseToAnyPublisher()
    }

    func subscribeState<State, Value>(_ selector: StateSelector<State, Value>) -> AnyPublisher<Value, Never> {
        if let sel = selector as? StateSelector<AudienceMediaState, Value> {
            return audienceMediaManager.subscribeState(sel)
        } else if let sel = selector as? StateSelector<AudienceState, Value> {
            return audienceObservableState.subscribe(sel)
        } else if let sel = selector as? StateSelector<AudienceBattleState, Value> {
            return audienceBattleObservableState.subscribe(sel)
        }
        assertionFailure("Input failed State class")
        return Empty<Value, Never>().eraseToAnyPublisher()
    }
}

// MARK: - AudienceConfig

extension AudienceStore {
    static func disableFeature(_ feature: AudienceViewFeature, isDisable: Bool) {
        observerAudienceConfig.update { config in
            switch feature {
                case .sliding:
                    config.disableSliding = isDisable
                case .floatWin:
                    config.disableHeaderFloatWin = isDisable
                case .liveData:
                    config.disableHeaderLiveData = isDisable
                case .visitorCnt:
                    config.disableHeaderVisitorCnt = isDisable
                case .coGuest:
                    config.disableFooterCoGuest = isDisable
            }
        }
    }

    static func subscribeAudienceConfig<Value>(_ selector: StateSelector<AudienceContainerConfig, Value>) -> AnyPublisher<Value, Never> {
        return observerAudienceConfig.subscribe(selector)
    }
}

// MARK: - Common

extension AudienceStore {
    func onError(_ error: InternalError) {
        context.toastSubject.send((error.localizedMessage ,.error))
    }
}

private extension String {
    static let takeSeatApplicationRejected = internalLocalized("Take seat application has been rejected")
    static let takeSeatApplicationTimeout = internalLocalized("Take seat application timeout")
}
