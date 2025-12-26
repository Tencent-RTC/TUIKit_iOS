//
//  VideoLinkConfigPanel.swift
//  TUILiveKit
//
//  Created by krabyu on 2023/10/25.
//

import AtomicXCore
import Combine
import Foundation
import RTCCommon
import TUICore

class VideoLinkSettingPanel: RTCBaseView {
    private weak var coreView: LiveCoreView?
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    private let requestTimeOutValue: TimeInterval = 60
    
    private var cancellableSet = Set<AnyCancellable>()
    private var needCloseCameraWhenViewDisappear: Bool = false
    private var isPortrait: Bool = WindowUtils.isPortrait
    private var lastApplyHashValue: Int?
    
    private let titleLabel: UILabel = {
        let view = UILabel()
        view.text = .videoLinkConfigTitleText
        view.textColor = .g7
        view.font = .customFont(ofSize: 16)
        view.textAlignment = .center
        return view
    }()
    
    private let previewView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16.scale375Width()
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var featureItems: [AudienceFeatureItem] = {
        var items = [AudienceFeatureItem]()
        var designConfig = AudienceFeatureItemDesignConfig()
        designConfig.imageTopInset = 8.scale375Height()
        designConfig.backgroundColor = .g3.withAlphaComponent(0.3)
        designConfig.cornerRadius = 10.scale375Width()
        designConfig.type = .imageAboveTitle
        items.append(AudienceFeatureItem(normalTitle: .beautyText,
                                         normalImage: internalImage("live_video_setting_beauty"),
                                         designConfig: designConfig,
                                         actionClosure: { [weak self] _ in
                                             guard let self = self else { return }
                                             self.routerManager.router(action: .present(.beauty))
                                             let isEffectBeauty = (TUICore.getService(TUICore_TEBeautyService) != nil)
                                             DataReporter.reportEventData(eventKey: isEffectBeauty ? Constants.DataReport.kDataReportPanelShowLiveRoomBeautyEffect :
                                                 Constants.DataReport.kDataReportPanelShowLiveRoomBeauty)
                                         }))
        items.append(AudienceFeatureItem(normalTitle: .flipText,
                                         normalImage: internalImage("live_video_setting_flip"),
                                         designConfig: designConfig,
                                         actionClosure: { [weak self] _ in
                                             guard let self = self else { return }
                                             manager.deviceStore.switchCamera(isFront: !manager.deviceState.isFrontCamera)
                                         }))
        return items
    }()
    
    private lazy var featureClickPanel: AudienceFeatureClickPanel = {
        var model = AudienceFeatureClickPanelModel()
        model.itemSize = CGSize(width: 56.scale375Width(), height: 56.scale375Width())
        model.itemDiff = 12.scale375Width()
        model.items = featureItems
        var featureClickPanel = AudienceFeatureClickPanel(model: model)
        return featureClickPanel
    }()
    
    private lazy var requestLinkMicButton: UIButton = {
        let view = UIButton()
        view.setTitle(.requestText, for: .normal)
        view.setTitleColor(.flowKitWhite, for: .normal)
        view.titleLabel?.font = .customFont(ofSize: 16)
        view.backgroundColor = .brandBlueColor
        view.layer.cornerRadius = 10.scale375Width()
        view.layer.masksToBounds = true
        view.addTarget(self, action: #selector(requestLinkMicButtonClick), for: .touchUpInside)
        return view
    }()
    
    private let tipsLabel: UILabel = {
        let view = UILabel()
        view.text = .videoLinkConfigTipsText
        view.textColor = .greyColor
        view.font = .customFont(ofSize: 12)
        view.textAlignment = .center
        view.numberOfLines = 0
        view.lineBreakMode = .byWordWrapping
        return view
    }()
    
    private var seatIndex: Int
    func updateSeatIndex(_ seatIndex: Int) {
        self.seatIndex = seatIndex
    }
    
    init(manager: AudienceStore, routerManager: AudienceRouterManager, coreView: LiveCoreView, seatIndex: Int) {
        self.manager = manager
        self.routerManager = routerManager
        self.coreView = coreView
        self.seatIndex = seatIndex
        super.init(frame: .zero)
    }
    
    override func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(previewView)
        addSubview(featureClickPanel)
        addSubview(requestLinkMicButton)
        addSubview(tipsLabel)
    }
    
    override func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20.scale375Height())
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(24.scale375Height())
        }
        previewView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(32.scale375Height())
            make.leading.equalToSuperview().offset(24.scale375Width())
            make.trailing.equalToSuperview().offset(-23.scale375Width())
            make.height.equalTo(328.scale375Height())
        }
        featureClickPanel.snp.makeConstraints { make in
            make.top.equalTo(previewView.snp.bottom).offset(24.scale375Height())
            make.centerX.equalToSuperview()
        }
        requestLinkMicButton.snp.makeConstraints { make in
            make.top.equalTo(featureClickPanel.snp.bottom).offset(111.scale375Height())
            make.centerX.equalToSuperview()
            make.width.equalTo(200.scale375Width())
            make.height.equalTo(52.scale375Height())
        }
        tipsLabel.snp.makeConstraints { make in
            make.top.equalTo(requestLinkMicButton.snp.bottom).offset(20.scale375Height())
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(17.scale375Height())
            make.bottom.equalToSuperview()
        }
    }
    
    override func bindInteraction() {
        subscribeCurrentRoute()
    }
    
    override func setupViewStyle() {
        backgroundColor = .g2
        layer.cornerRadius = 20
        layer.masksToBounds = true
    }
}

// MARK: Action

extension VideoLinkSettingPanel {
    @objc func requestLinkMicButtonClick(_ sender: AudienceFeatureItemButton) {
        manager.willApplying()
        manager.toastSubject.send((.waitToLinkText, .info))
        manager.coGuestStore.applyForSeat(seatIndex: seatIndex, timeout: requestTimeOutValue, extraInfo: nil) { [weak self] result in
            guard let self = self else { return }
            manager.stopApplying()
            switch result {
            case .failure(let err):
                let error = InternalError(code: err.code, message: err.message)
                manager.onError(error)
            default: break
            }
        }
        
        clearLastApplyHashValue()
        
        let cancelable = manager.coGuestStore.guestEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onGuestApplicationResponded(isAccept: let isAccept, hostUser: _):
                    guard isAccept else { break }
                    manager.deviceStore.openLocalCamera(isFront: manager.deviceState.isFrontCamera, completion: nil)
                    manager.deviceStore.openLocalMicrophone(completion: nil)
                    clearLastApplyHashValue()
                case .onGuestApplicationNoResponse(reason: _):
                    clearLastApplyHashValue()
                default: break
                }
            }
        cancelable.store(in: &cancellableSet)
        lastApplyHashValue = cancelable.hashValue
        routerManager.router(action: .routeTo(.audience))
    }
    
    private func clearLastApplyHashValue() {
        guard let hashValue = lastApplyHashValue else { return }
        for item in cancellableSet.filter({ $0.hashValue == hashValue }) {
            item.cancel()
            cancellableSet.remove(item)
        }
        lastApplyHashValue = nil
    }
    
    private func subscribeCurrentRoute() {
        routerManager.subscribeRouterState(StateSelector(keyPath: \AudienceRouterState.routeStack))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] routeStack in
                guard let self = self else { return }
                if case .linkSetting = routeStack.last {
                    manager.deviceStore.switchCamera(isFront: true)
                    manager.deviceStore.startCameraTest(cameraView: previewView) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success(()):
                            needCloseCameraWhenViewDisappear = true
                        case .failure(let err):
                            let error = InternalError(code: err.code, message: err.message)
                            manager.onError(error)
                        }
                    }
                } else if !routeStack.contains(where: { if case .linkSetting = $0 { true } else { false } }) {
                    if needCloseCameraWhenViewDisappear {
                        manager.deviceStore.stopCameraTest()
                        needCloseCameraWhenViewDisappear = false
                    }
                }
            }
            .store(in: &cancellableSet)
    }
}

private extension String {
    static let videoLinkConfigTitleText = internalLocalized("Adjust the video link screen")
    static let requestText = internalLocalized("Apply for link mic")
    static let videoLinkConfigTipsText = internalLocalized("The screen effect will automatically take effect after connecting")
    static let beautyText = internalLocalized("Beauty")
    static let videoParametersText = internalLocalized("Video Config")
    static let flipText = internalLocalized("Flip")
    static let waitToLinkText = internalLocalized("You have submitted a link mic request, please wait for the author approval")
}
