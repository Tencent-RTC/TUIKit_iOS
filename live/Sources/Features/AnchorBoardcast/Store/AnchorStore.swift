//
//  AnchorStore.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/18.
//

import AtomicX
import AtomicXCore
import Combine
import Foundation
import RTCCommon

public typealias InternalErrorBlock = (_ error: InternalError) -> Void

class AnchorStore {
    class Context {
        let liveID: String

        let toastSubject = PassthroughSubject<(String, ToastStyle), Never>()
        let floatWindowSubject = PassthroughSubject<Void, Never>()
        let kickedOutSubject = PassthroughSubject<Bool, Never>() // bool value for room is dismissed
        let onEndLivingSubject = PassthroughSubject<AnchorState, Never>()

        var coGuestStore: CoGuestStore {
            CoGuestStore.create(liveID: liveID)
        }

        var battleStore: BattleStore {
            BattleStore.create(liveID: liveID)
        }

        let deviceStore: DeviceStore = .shared
        let liveListStore: LiveListStore = .shared
        var coHostStore: CoHostStore {
            CoHostStore.create(liveID: liveID)
        }

        let loginStore: LoginStore = .shared
        var seatStore: LiveSeatStore {
            LiveSeatStore.create(liveID: liveID)
        }

        var barrageStore: BarrageStore {
            BarrageStore.create(liveID: liveID)
        }

        var audienceStore: LiveAudienceStore {
            LiveAudienceStore.create(liveID: liveID)
        }

        private(set) lazy var anchorMediaManager = AnchorMediaStore(context: self)
        private(set) lazy var anchorCoHostManager = AnchorCoHostStore(context: self)

        let anchorBattleObservableState = ObservableState(initialState: AnchorBattleState())

        init(liveID: String) {
            self.liveID = liveID
        }

        deinit {}
    }

    private let context: Context
    private var cancellableSet: Set<AnyCancellable> = []

    init(liveID: String) {
        context = Context(liveID: liveID)
    }

    var liveID: String {
        context.liveID
    }

    var selfUserID: String {
        loginState.loginUserInfo?.userID ?? ""
    }

    private(set) var pkTemplateMode: LiveTemplateMode = .verticalGridDynamic

    func prepareLiveInfoBeforeEnterRoom(pkTemplateMode: LiveTemplateMode) {
        self.pkTemplateMode = pkTemplateMode
        context.anchorMediaManager.prepareLiveInfoBeforeEnterRoom()
    }

    func willApplyingHost() {
        context.anchorCoHostManager.observableState.update { state in
            state.isApplying = true
        }
    }

    func stopApplyingHost() {
        context.anchorCoHostManager.observableState.update { state in
            state.isApplying = false
        }
    }

    func willApplyingBattle() {
        context.anchorBattleObservableState.update { state in
            state.isInWaiting = true
        }
    }

    func stopApplyingBattle() {
        context.anchorBattleObservableState.update { state in
            state.isInWaiting = false
            state.requestBattleID = ""
        }
    }

    func startShowBattleResult() {
        context.anchorBattleObservableState.update { state in
            state.isOnDisplayResult = true
        }
    }

    func stopShowBattleResult() {
        context.anchorBattleObservableState.update { state in
            state.isOnDisplayResult = false
        }
    }

    func updateBattleDurationCountDown(_ value: Int) {
        context.anchorBattleObservableState.update { state in
            state.durationCountDown = value
        }
    }

    func setRequestBattleID(_ battleID: String) {
        context.anchorBattleObservableState.update { state in
            state.requestBattleID = battleID
        }
    }
}

// MARK: - Common

extension AnchorStore {
    func onError(_ error: InternalError) {
        toastSubject.send((error.localizedMessage, .error))
    }
}

// MARK: - Subject

extension AnchorStore {
    var toastSubject: PassthroughSubject<(String, ToastStyle), Never> {
        context.toastSubject
    }

    var kickedOutSubject: PassthroughSubject<Bool, Never> {
        context.kickedOutSubject
    }

    var floatWindowSubject: PassthroughSubject<Void, Never> {
        context.floatWindowSubject
    }

    var onEndLivingSubject: PassthroughSubject<AnchorState, Never> {
        context.onEndLivingSubject
    }
}

// MARK: - Store

extension AnchorStore {
    var coGuestStore: CoGuestStore {
        context.coGuestStore
    }

    var barrageStore: BarrageStore {
        context.barrageStore
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

    var audienceStore: LiveAudienceStore {
        context.audienceStore
    }
}

// MARK: - State and subscribe

extension AnchorStore {
    var anchorCoHostState: AnchorCoHostState {
        context.anchorCoHostState
    }

    var anchorBattleState: AnchorBattleState {
        context.anchorBattleState
    }

    var anchorMediaState: AnchorMediaState {
        context.anchorMediaManager.mediaState
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

    var audienceState: LiveAudienceState {
        context.audienceState
    }

    func subscribeState<State, Value>(_ selector: StatePublisherSelector<State, Value>) -> AnyPublisher<Value, Never> {
        context.subscribeState(selector)
    }

    func subscribeState<State, Value>(_ selector: StateSelector<State, Value>) -> AnyPublisher<Value, Never> {
        context.subscribeState(selector)
    }
}

extension AnchorStore.Context {
    var anchorCoHostState: AnchorCoHostState {
        anchorCoHostManager.observableState.state
    }

    var anchorBattleState: AnchorBattleState {
        anchorBattleObservableState.state
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

    var audienceState: LiveAudienceState {
        audienceStore.state.value
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
        } else if let sel = selector as? StatePublisherSelector<LiveAudienceState, Value> {
            return audienceStore.state.subscribe(sel)
        } else if let sel = selector as? StatePublisherSelector<BarrageState, Value> {
            return barrageStore.state.subscribe(sel)
        }
        assertionFailure("Input failed State class")
        return Empty<Value, Never>().eraseToAnyPublisher()
    }

    func subscribeState<State, Value>(_ selector: StateSelector<State, Value>) -> AnyPublisher<Value, Never> {
        if let sel = selector as? StateSelector<AnchorMediaState, Value> {
            return anchorMediaManager.subscribeState(sel)
        } else if let sel = selector as? StateSelector<AnchorBattleState, Value> {
            return anchorBattleObservableState.subscribe(sel)
        } else if let sel = selector as? StateSelector<AnchorCoHostState, Value> {
            return anchorCoHostManager.subscribeCoHostState(sel)
        }
        assertionFailure("Input failed State class")
        return Empty<Value, Never>().eraseToAnyPublisher()
    }
}

private extension String {
    static let takeSeatApplicationRejected = internalLocalized("Take seat application has been rejected")
    static let takeSeatApplicationTimeout = internalLocalized("Take seat application timeout")
    static let kickedOutOfSeat = internalLocalized("Kicked out of seat by room owner")
}
