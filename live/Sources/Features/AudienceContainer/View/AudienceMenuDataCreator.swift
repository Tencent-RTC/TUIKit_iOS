//
//  AudienceMenuDataCreator.swift
//  TUILiveKit
//
//  Created by aby on 2024/5/31.
//

import AtomicXCore
import Combine
import Foundation
import RTCCommon
import TUICore

class AudienceRootMenuDataCreator {
    private weak var coreView: LiveCoreView?
    private let manager: AudienceManager
    private let routerManager: AudienceRouterManager
    private var cancellableSet: Set<AnyCancellable> = []
    private var lastApplyHashValue: Int?

    init(coreView: LiveCoreView, manager: AudienceManager, routerManager: AudienceRouterManager) {
        self.coreView = coreView
        self.manager = manager
        self.routerManager = routerManager
    }
    
    func generateBottomMenuData(isDisableCoGuest: Bool = false) -> [AudienceButtonMenuInfo] {
        return memberBottomMenu(isDisableCoGuest: isDisableCoGuest)
    }
    
    func generateLinkTypeMenuData(seatIndex: Int = -1) -> [LinkMicTypeCellData] {
        var data = [LinkMicTypeCellData]()
        let timeOutValue: TimeInterval = 60
        
        func applyForSeat(seatIndex: Int, openCamera: Bool) {
            manager.willApplying()
            manager.toastSubject.send(.waitToLinkText)
            manager.coGuestStore.applyForSeat(seatIndex: seatIndex, timeout: timeOutValue, extraInfo: nil) { [weak self] result in
                guard let self = self else { return }
                manager.stopApplying()
                switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    manager.toastSubject.send(error.localizedMessage)
                default: break
                }
            }
            
            for item in cancellableSet.filter({ $0.hashValue == lastApplyHashValue }) {
                item.cancel()
                cancellableSet.remove(item)
            }
            
            let cancelable = manager.coGuestStore.guestEventPublisher
                .receive(on: RunLoop.main)
                .sink { [weak self] event in
                    guard let self = self else { return }
                    switch event {
                    case .onGuestApplicationResponded(isAccept: let isAccept, hostUser: _):
                        manager.stopApplying()
                        guard isAccept else { break }
                        if openCamera {
                            manager.deviceStore.openLocalCamera(isFront: manager.deviceState.isFrontCamera, completion: nil)
                        }
                        manager.deviceStore.openLocalMicrophone(completion: nil)
                    case .onGuestApplicationNoResponse(reason: _):
                        manager.stopApplying()
                    default: break
                    }
                }
            cancelable.store(in: &cancellableSet)
            lastApplyHashValue = cancelable.hashValue
        }
        
        data.append(LinkMicTypeCellData(image: internalImage("live_link_video"), text: .videoLinkRequestText, action: { [weak self] in
            guard let self = self else { return }
            applyForSeat(seatIndex: seatIndex, openCamera: true)
            routerManager.router(action: .dismiss())
        }))
        
        data.append(LinkMicTypeCellData(image: internalImage("live_link_audio"), text: .audioLinkRequestText, action: { [weak self] in
            guard let self = self else { return }
            applyForSeat(seatIndex: seatIndex, openCamera: false)
            routerManager.router(action: .dismiss())
        }))
        return data
    }
    
    deinit {
        print("deinit \(type(of: self))")
    }
}

extension AudienceRootMenuDataCreator {
    func memberBottomMenu(isDisableCoGuest: Bool = false) -> [AudienceButtonMenuInfo] {
        var menus: [AudienceButtonMenuInfo] = []
        var gift = AudienceButtonMenuInfo(normalIcon: "live_gift_icon", normalTitle: "")
        gift.tapAction = { [weak self] _ in
            guard let self = self else { return }
            routerManager.router(action: .present(.giftView))
        }
        menus.append(gift)
        if !isDisableCoGuest {
            var linkMic = AudienceButtonMenuInfo(normalIcon: "live_link_icon", selectIcon: "live_linking_icon")
            linkMic.tapAction = { [weak self] sender in
                guard let self = self else { return }
                if !manager.coHostState.connected.isEmpty {
                    return
                }
                if sender.isSelected {
                    let designConfig = ActionItemDesignConfig(lineWidth: 7, titleColor: .warningTextColor)
                    designConfig.backgroundColor = .bgOperateColor
                    designConfig.lineColor = .g3.withAlphaComponent(0.3)
                    let item = ActionItem(title: .cancelLinkMicRequestText, designConfig: designConfig) { [weak self] _ in
                        guard let self = self else { return }
                        routerManager.router(action: .dismiss())
                        manager.stopApplying()
                        manager.coGuestStore.cancelApplication { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case .failure(let err):
                                let error = InternalError(code: err.code, message: err.message)
                                manager.toastSubject.send(error.localizedMessage)
                            default: break
                            }
                        }
                    }
                    routerManager.router(action: .present(.listMenu(ActionPanelData(items: [item], cancelText: .cancelText, cancelColor: .bgOperateColor, cancelTitleColor: .defaultTextColor), .stickToBottom)))
                } else {
                    if manager.coGuestState.connected.isOnSeat() {
                        confirmToTerminateCoGuest()
                    } else {
                        let data = generateLinkTypeMenuData()
                        routerManager.router(action: .present(.linkType(data)))
                    }
                }
            }
            linkMic.bindStateClosure = { [weak self] button, cancellableSet in
                guard let self = self else { return }
                manager.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.connected))
                    .removeDuplicates()
                    .combineLatest(manager.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected)).removeDuplicates(),
                                   manager.subscribeState(StateSelector(keyPath: \AudienceState.isApplying)).removeDuplicates())
                    .receive(on: RunLoop.main)
                    .sink { [weak self] connected, users, isApplying in
                        guard let self = self else { return }
                        onCoGuestStatusChanged(button: button, enable: users.isEmpty, isOnSeat: connected.isOnSeat(), isApplying: isApplying)
                    }
                    .store(in: &cancellableSet)
            }
            menus.append(linkMic)
        }
        return menus
    }
    
    private func onCoGuestStatusChanged(button: UIButton, enable: Bool, isOnSeat: Bool, isApplying: Bool) {
        let imageName: String
        let isSelected: Bool
        if enable {
            isSelected = isApplying
            imageName = isOnSeat ? "live_linked_icon" : "live_link_icon"
        } else {
            isSelected = false
            imageName = "live_link_disable_icon"
        }
        button.isSelected = isSelected
        button.setImage(internalImage(imageName), for: .normal)
    }
    
    private func confirmToTerminateCoGuest() {
        var items: [ActionItem] = []
        let designConfig = ActionItemDesignConfig(lineWidth: 7, titleColor: .warningTextColor)
        designConfig.backgroundColor = .bgOperateColor
        designConfig.lineColor = .g3.withAlphaComponent(0.3)

        let terminateGoGuestItem = ActionItem(title: .confirmTerminateCoGuestText, designConfig: designConfig, actionClosure: { [weak self] _ in
            guard let self = self else { return }
            manager.coGuestStore.disConnect { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    manager.deviceStore.closeLocalCamera()
                    manager.deviceStore.closeLocalMicrophone()
                default: break
                }
            }
            routerManager.router(action: .routeTo(.audience))
        })
        items.append(terminateGoGuestItem)
        routerManager.router(action: .present(.listMenu(ActionPanelData(items: items, cancelText: .cancelText, cancelColor: .bgOperateColor, cancelTitleColor: .defaultTextColor), .stickToBottom)))
    }
}

private extension String {
    static let videoLinkRequestText = internalLocalized("Apply for video link")
    static var audioLinkRequestText = internalLocalized("Apply for audio link")
    static let waitToLinkText = internalLocalized("You have submitted a link mic request, please wait for the author approval")
    static let beautyText = internalLocalized("Beauty")
    static let audioEffectsText = internalLocalized("Audio")
    static let flipText = internalLocalized("Flip")
    static let mirrorText = internalLocalized("Mirror")
    
    static let cancelLinkMicRequestText = internalLocalized("Cancel application for link mic")
    static let confirmTerminateCoGuestText = internalLocalized("End Link")
    static let coGuestText = internalLocalized("Guest")
    static let cancelText = internalLocalized("Cancel")
}
