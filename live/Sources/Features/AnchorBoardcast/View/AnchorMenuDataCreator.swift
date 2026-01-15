//
//  LiveRoomRootMenuDataCreator.swift
//  TUILiveKit
//
//  Created by aby on 2024/5/31.
//

import AtomicXCore
import Combine
import Foundation
import RTCCommon
import TUICore
import AtomicX

class AnchorMenuDataCreator {
    private weak var coreView: LiveCoreView?
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private var cancellableSet: Set<AnyCancellable> = []
    
    private var lastApplyHashValue: Int?
    
    private weak var presentedExitBattleAlertView: AtomicAlertView?
    
    init(coreView: LiveCoreView, store: AnchorStore, routerManager: AnchorRouterManager) {
        self.coreView = coreView
        self.store = store
        self.routerManager = routerManager
        subscribeState()
    }
    
    func generateBottomMenuData(features: [AnchorBottomMenuFeature]) -> [AnchorButtonMenuInfo] {
        ownerBottomMenu(features: features)
    }
    
    deinit {
        print("deinit \(type(of: self))")
    }
    
    private func subscribeState() {
        store.battleStore.battleEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onBattleEnded(battleInfo: _, reason: _):
                    if let alertView = presentedExitBattleAlertView {
                        alertView.dismiss()
                        presentedExitBattleAlertView = nil
                    }
                default: break
                }
            }
            .store(in: &cancellableSet)
    }
}

extension AnchorMenuDataCreator {
    private func ownerBottomMenu(features: [AnchorBottomMenuFeature]) -> [AnchorButtonMenuInfo] {
        var menus: [AnchorButtonMenuInfo] = []
        if features.contains(.coHost) {
            var connection = AnchorButtonMenuInfo(normalIcon: "live_connection_icon", normalTitle: .coHostText)
            let selfUserId = store.selfUserID
            connection.tapAction = { [weak self] _ in
                guard let self = self else { return }
                if store.coGuestState.connected.count > 1 ||
                    store.battleState.battleUsers.contains(where: { $0.userID == selfUserId }) ||
                    store.coGuestState.applicants.count > 0 {
                    return
                } else {
                    routerManager.router(action: .present(.connectionControl))
                }
            }
            
            connection.bindStateClosure = { [weak self] button, cancellableSet in
                guard let self = self else { return }
                let battleUsersPublisher = store.subscribeState(StatePublisherSelector(keyPath: \BattleState.battleUsers)).removeDuplicates()
                let coGuestApplicantPublisher = store.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.applicants)).removeDuplicates()
                store.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.connected))
                    .removeDuplicates()
                    .combineLatest(battleUsersPublisher, coGuestApplicantPublisher)
                    .receive(on: RunLoop.main)
                    .sink { [weak button] seatList, battleUsers, applicants in
                        let isBattle = battleUsers.contains(where: { $0.userID == selfUserId })
                        let isCoGuestConnected = seatList.count > 1
                        let isHandleApplicants = applicants.count > 0
                        let imageName = isBattle || isCoGuestConnected || isHandleApplicants ? "live_connection_disable_icon" : "live_connection_icon"
                        button?.setImage(internalImage(imageName), for: .normal)
                    }
                    .store(in: &cancellableSet)
            }
            menus.append(connection)
        }
        
        if features.contains(.battle) {
            var battle = AnchorButtonMenuInfo(normalIcon: "live_battle_icon", normalTitle: .battleText)
            battle.tapAction = { [weak self] _ in
                guard let self = self else { return }
                let selfUserId = store.selfUserID
                let isSelfInBattle = store.battleState.battleUsers.contains(where: { $0.userID == selfUserId })
                if isSelfInBattle {
                    confirmToExitBattle()
                } else {
                    let isOnDisplayResult = store.anchorBattleState.isOnDisplayResult
                    let isSelfInConnection = store.coHostState.connected.isOnSeat()
                    guard !isOnDisplayResult, isSelfInConnection else {
                        return
                    }
                    
                    var config = BattleConfig()
                    config.duration = anchorBattleDuration
                    config.needResponse = true
                    config.extensionInfo = ""
                    store.willApplyingBattle()
                    store.battleStore.requestBattle(config: config, userIDList: store.coHostState.connected.filter { $0.userID != selfUserId }.map { $0.userID }, timeout: anchorBattleRequestTimeout) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success((let battleInfo, _)):
                            store.setRequestBattleID(battleInfo.battleID)
                        case .failure(let err):
                            store.stopApplyingBattle()
                            let err = InternalError(code: err.code, message: err.message)
                            store.onError(err)
                        }
                    }
                    
                    if let value = lastApplyHashValue {
                        for item in cancellableSet.filter({ $0.hashValue == value }) {
                            item.cancel()
                            cancellableSet.remove(item)
                        }
                    }
                    
                    let publisher = store.battleStore.battleEventPublisher
                        .receive(on: RunLoop.main)
                        .sink { [weak self] event in
                            guard let self = self else { return }
                            switch event {
                            case .onBattleRequestAccept(battleID: _, inviter: _, invitee: _),
                                 .onBattleRequestReject(battleID: _, inviter: _, invitee: _),
                                 .onBattleRequestTimeout(battleID: _, inviter: _, invitee: _):
                                store.stopApplyingBattle()
                            default: break
                            }
                        }
                    publisher.store(in: &cancellableSet)
                    lastApplyHashValue = publisher.hashValue
                }
            }
            battle.bindStateClosure = { [weak self] button, cancellableSet in
                guard let self = self else { return }
                let selfUserId = store.selfUserID
                let battleUsersPublisher = store.subscribeState(StatePublisherSelector(keyPath: \BattleState.battleUsers))
                let connectedUsersPublisher = store.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected))
                let displayResultPublisher = store.subscribeState(StateSelector(keyPath: \AnchorBattleState.isOnDisplayResult))
              
                battleUsersPublisher
                    .removeDuplicates()
                    .receive(on: RunLoop.main)
                    .sink { [weak button] battleUsers in
                        let isOnBattle = battleUsers.contains(where: { $0.userID == selfUserId })
                        let imageName = isOnBattle ? "live_battle_exit_icon" : "live_battle_icon"
                        button?.setImage(internalImage(imageName), for: .normal)
                    }
                    .store(in: &cancellableSet)

                displayResultPublisher
                    .removeDuplicates()
                    .receive(on: RunLoop.main)
                    .sink { [weak button] display in
                        let imageName = display ?
                            "live_battle_disable_icon" :
                            "live_battle_icon"
                        button?.setImage(internalImage(imageName), for: .normal)
                    }
                    .store(in: &cancellableSet)
                
                connectedUsersPublisher
                    .removeDuplicates()
                    .combineLatest(battleUsersPublisher)
                    .receive(on: RunLoop.main)
                    .sink { [weak button] connectedUsers, battleUsers in
                        let isSelfInBattle = battleUsers.contains(where: { $0.userID == selfUserId })
                        guard !isSelfInBattle else { return }
                        let isSelfInConnection = connectedUsers.contains(where: { $0.userID == selfUserId })
                        
                        let imageName = isSelfInConnection ?
                            "live_battle_icon" :
                            "live_battle_disable_icon"
                        button?.setImage(internalImage(imageName), for: .normal)
                    }.store(in: &cancellableSet)
            }
            menus.append(battle)
        }
        
        if features.contains(.coGuest) {
            var linkMic = AnchorButtonMenuInfo(normalIcon: "live_link_icon", animateIcon: ["live_link_animate1_icon", "live_link_animate2_icon", "live_link_animate3_icon"], normalTitle: .coGuestText)
            linkMic.tapAction = { [weak self] _ in
                guard let self = self else { return }
                if !store.coHostState.connected.isEmpty {
                    return
                }
                routerManager.router(action: .present(.liveLinkControl))
            }
            linkMic.bindStateClosure = { [weak self] button, cancellableSet in
                guard let self = self else { return }
                store.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected))
                    .map { !$0.isEmpty }
                    .receive(on: RunLoop.main)
                    .removeDuplicates()
                    .sink { [weak button] isConnecting in
                        let imageName = isConnecting ? "live_link_disable_icon" : "live_link_icon"
                        button?.setImage(internalImage(imageName), for: .normal)
                    }
                    .store(in: &cancellableSet)
                
                store.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.connected))
                    .removeDuplicates()
                    .map { $0.count > 1 }
                    .combineLatest(store.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected)).removeDuplicates().map { !$0.isEmpty })
                    .receive(on: RunLoop.main)
                    .sink { [weak button] isGuestLinking, isHostConnecting in
                        if isHostConnecting {
                            return
                        }
                        isGuestLinking ? button?.startAnimating() : button?.stopAnimating()
                    }
                    .store(in: &cancellableSet)
            }
            menus.append(linkMic)
        }
        
        var setting = AnchorButtonMenuInfo(normalIcon: "live_more_btn_icon", normalTitle: .MoreText)
        setting.tapAction = { [weak self] _ in
            guard let self = self else { return }
            let settingModel = generateSettingModel(features: features)
            routerManager.router(action: .present(.featureSetting(settingModel)))
        }
        menus.append(setting)
        return menus
    }
    
    private func confirmToExitBattle() {
        var items: [AlertButtonConfig] = []
        let endBattleItem = AlertButtonConfig(text: .confirmEndBattleText, type: .red) { [weak self] _ in
            guard let self = self else { return }
            let cancelButton = AlertButtonConfig(text: String.cancelText, type: .grey) { [weak self] _ in
                guard let self = self else { return }
                routerManager.router(action: .routeTo(.anchor))
            }
            let confirmButton = AlertButtonConfig(text: String.confirmEndBattleText, type: .red) { [weak self] _ in
                guard let self = self else { return }
                store.battleStore.exitBattle(battleID: store.battleState.currentBattleInfo?.battleID ?? "", completion: nil)
                routerManager.router(action: .routeTo(.anchor))
            }
            let alertConfig = AlertViewConfig(title: String.endBattleAlertText,
                                              cancelButton: cancelButton,
                                              confirmButton: confirmButton)
            routerManager.router(action: .dismiss(.panel, completion: { [weak self] in
                guard let self = self else { return }
                let alertView = AtomicAlertView(config: alertConfig)
                routerManager.present(view: alertView)
                presentedExitBattleAlertView = alertView
            }))
        }
        items.append(endBattleItem)
        
        let cancelItem = AlertButtonConfig(text: .cancelText, type: .primary) { [weak self] _ in
            guard let self = self else { return }
            self.routerManager.dismiss()
        }
        items.append(cancelItem)
        
        let alertConfig = AlertViewConfig(items: items)
        let alertView = AtomicAlertView(config: alertConfig)
        routerManager.present(view: alertView, position: .bottom)
        presentedExitBattleAlertView = alertView
    }
    
    private func generateSettingModel(features: [AnchorBottomMenuFeature]) -> AnchorFeatureClickPanelModel {
        let model = AnchorFeatureClickPanelModel()
        model.itemSize = CGSize(width: 56.scale375(), height: 80.scale375Height())
        model.itemDiff = 12.scale375()
        var designConfig = AnchorFeatureItemDesignConfig()
        designConfig.backgroundColor = .bgEntrycardColor
        designConfig.cornerRadius = 10
        designConfig.titleFont = .customFont(ofSize: 12)
        designConfig.titileColor = .textPrimaryColor
        designConfig.type = .imageAboveTitleBottom
        if features.contains(.beauty) {
            model.items.append(AnchorFeatureItem(normalTitle: .beautyText,
                                                 normalImage: internalImage("live_video_setting_beauty")?.withTintColor(.textPrimaryColor),
                                                 designConfig: designConfig,
                                                 actionClosure: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     routerManager.router(action: .dismiss(.panel, completion: { [weak self] in
                                                         guard let self = self else { return }
                                                         routerManager.router(action: .present(.beauty))
                                                     }))
                                                     let isEffectBeauty = (TUICore.getService(TUICore_TEBeautyService) != nil)
                                                     DataReporter.reportEventData(eventKey: isEffectBeauty ? Constants.DataReport.kDataReportPanelShowLiveRoomBeautyEffect :
                                                         Constants.DataReport.kDataReportPanelShowLiveRoomBeauty)
                                                 }))
        }
        if features.contains(.soundEffect) {
            model.items.append(AnchorFeatureItem(normalTitle: .audioEffectsText,
                                                 normalImage: internalImage("live_setting_audio_effects")?.withTintColor(.textPrimaryColor),
                                                 designConfig: designConfig,
                                                 actionClosure: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     routerManager.router(action: .present(.audioEffect))
                                                 }))
        }
        model.items.append(AnchorFeatureItem(normalTitle: .flipText,
                                             normalImage: internalImage("live_video_setting_flip")?.withTintColor(.textPrimaryColor),
                                             designConfig: designConfig,
                                             actionClosure: { [weak self] _ in
                                                 guard let self = self else { return }
                                                 store.deviceStore.switchCamera(isFront: !store.deviceState.isFrontCamera)
                                                 
                                             }))
        model.items.append(AnchorFeatureItem(normalTitle: .mirrorText,
                                             normalImage: internalImage("live_video_setting_mirror")?.withTintColor(.textPrimaryColor),
                                             designConfig: designConfig,
                                             actionClosure: { [weak self] _ in
                                                 guard let self = self else { return }
                                                 routerManager.router(action: .dismiss(.panel, completion: { [weak self] in
                                                     guard let self = self else { return }
                                                     routerManager.router(action: .present(.mirror))
                                                 }))
                                             }))
        model.items.append(AnchorFeatureItem(normalTitle: .streamDashboardText,
                                             normalImage: internalImage("live_setting_stream_dashboard")?.withTintColor(.textPrimaryColor),
                                             designConfig: designConfig,
                                             actionClosure: { [weak self] _ in
                                                 guard let self = self else { return }
                                                 routerManager.router(action: .dismiss(.panel, completion: { [weak self] in
                                                     guard let self = self else { return }
                                                     routerManager.router(action: .present(.streamDashboard))
                                                 }))
                                             }))
        return model
    }
}

private extension String {
    static let videoLinkRequestText = internalLocalized("common_text_link_mic_video")
    static var audioLinkRequestText = internalLocalized("common_text_link_mic_audio")
    static let waitToLinkText = internalLocalized("common_toast_apply_link_mic")
    static let beautyText = internalLocalized("common_video_settings_item_beauty")
    static let audioEffectsText = internalLocalized("common_audio_effect")
    static let flipText = internalLocalized("common_video_settings_item_flip")
    static let mirrorText = internalLocalized("common_video_settings_item_mirror")
    static let confirmEndBattleText = internalLocalized("common_end_pk")
    static let endBattleAlertText = internalLocalized("common_battle_end_pk_tips")
    static let cancelText = internalLocalized("common_cancel")
    
    static let streamDashboardText = internalLocalized("common_dashboard_title")
    static let cancelLinkMicRequestText = internalLocalized("common_text_cancel_link_mic_apply")
    static let confirmTerminateCoGuestText = internalLocalized("common_text_close_link_mic")
    static let coHostText = internalLocalized("common_link_host")
    static let battleText = internalLocalized("common_anchor_battle")
    static let coGuestText = internalLocalized("common_link_guest")
    static let MoreText = internalLocalized("common_more")
    static let switchToText = internalLocalized("mirror_type_change_to")
}
