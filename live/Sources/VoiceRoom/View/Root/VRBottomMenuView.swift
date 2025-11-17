//
//  VoiceRoomRootView.swift
//  VoiceRoom
//
//  Created by aby on 2024/3/4.
//

import UIKit
import RTCCommon
import SnapKit
import Combine
import AtomicXCore
import RTCRoomEngine
import AtomicXCore

class VRBottomMenuView: UIView {
    var cancellableSet = Set<AnyCancellable>()
    var songListButtonAction: (() -> Void)?
    
    private let liveID: String
    private let routerManager: VRRouterManager
    private let viewStore: VoiceRoomViewStore
    private let toastService: VRToastService
    private let isOwner: Bool
    
    private let buttonSliceIndex: Int = 1
    
    private let maxMenuButtonNumber = 5
    private let buttonWidth: CGFloat = 36.0
    private let buttonSpacing: CGFloat = 6.0
    private var isPending: Bool = false
    
    var menus = [VRButtonMenuInfo]()
    
    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.distribution = .fillProportionally
        return view
    }()
    private let designConfig: ActionItemDesignConfig = {
        let designConfig = ActionItemDesignConfig(lineWidth: 1, titleColor: .g2)
        designConfig.backgroundColor = .white
        designConfig.lineColor = .g8
        return designConfig
    }()
    
    private var buttons: [UIButton] = []
    
    private lazy var likeButton: LikeButton = {
        let likeButton = LikeButton(roomId: liveID)
        return likeButton
    }()
    
    init(liveID: String,
         routerManager: VRRouterManager,
         viewStore: VoiceRoomViewStore,
         toastService: VRToastService,
         isOwner: Bool) {
        self.liveID = liveID
        self.routerManager = routerManager
        self.viewStore = viewStore
        self.toastService = toastService
        self.isOwner = isOwner
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        debugPrint("deinit \(type(of: self))")
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        setupMenuButtons()
        setupGuestEventListener()
        isViewReady = true
    }
    
    private func constructViewHierarchy() {
        addSubview(stackView)
    }
    
    private func activateConstraints() {
        stackView.snp.makeConstraints { make in
            let maxWidth = buttonWidth * CGFloat(maxMenuButtonNumber) + buttonSpacing * CGFloat(maxMenuButtonNumber - 1)
            make.centerY.equalToSuperview()
            make.trailing.equalTo(-16)
            make.width.lessThanOrEqualTo(maxWidth)
            make.leading.equalToSuperview()
        }
    }
    
    private func setupGuestEventListener() {
        coGuestStore.guestEventPublisher
            .receive(on: RunLoop.main)
             .sink { [weak self] event in
                 guard let self = self else { return }
                 
                 switch event {
                 case .onGuestApplicationResponded(isAccept: let isAccept, hostUser: _):
                     if !isAccept {
                         toastService.showToast(.takeSeatApplicationRejected)
                     }
                 case .onGuestApplicationNoResponse(reason: let reason):
                     if reason == .timeout {
                         toastService.showToast(.takeSeatApplicationTimeout)
                     }
                 default:
                     break
                 }
             }
             .store(in: &cancellableSet)
     }
    
    private func setupViewStyle() {
        stackView.spacing = buttonSpacing
    }
    
    private func setupMenuButtons() {
        menus = generateBottomMenuData()
        
        stackView.subviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.safeRemoveFromSuperview()
        }
        buttons = menus
            .enumerated().map { value -> MenuButton in
                let index = value.offset
                let item = value.element
                let button = self.createButtonFromMenuItem(index: index, item: item)
                stackView.addArrangedSubview(button)
                button.snp.makeConstraints { make in
                    make.height.width.equalTo(32.scale375Height())
                }
                button.addTarget(self, action: #selector(menuTapAction(sender:)), for: .touchUpInside)
                return button
            }
        if !isOwner {
            stackView.addArrangedSubview(likeButton)
            likeButton.snp.makeConstraints { make in
                make.width.equalTo(isOwner ? 34.scale375() : 32.scale375())
                make.height.equalTo(isOwner ? 46.scale375() : 32.scale375())
                make.centerY.equalToSuperview()
            }
            buttons.append(likeButton)
        }
    }
    
    private func createButtonFromMenuItem(index: Int, item: VRButtonMenuInfo) -> MenuButton {
        let button = MenuButton(frame: .zero)
        button.setImage(internalImage(item.normalIcon), for: .normal)
        button.setImage(internalImage(item.selectIcon), for: .selected)
        button.setTitle(item.normalTitle, for: .normal)
        button.setTitle(item.selectTitle, for: .selected)
        button.imageEdgeInsets = .zero
        button.tag = index + 1_000
        item.bindStateClosure?(button, &cancellableSet)
        return button
    }

    private func bindInteraction() {
        coHostStore.state.subscribe(StatePublisherSelector(keyPath: \CoHostState.connected))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self = self else { return }
                let battleUsers = battleStore.state.value.battleUsers
                setupMenuButtons()
            }
            .store(in: &cancellableSet)
    }
}

class MenuButton: UIButton {
    
    let rotateAnimation: CABasicAnimation = {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = Double.pi * 2
        animation.duration = 2
        animation.autoreverses = false
        animation.fillMode = .forwards
        animation.repeatCount = MAXFLOAT
        animation.isRemovedOnCompletion = false
        return animation
    }()
    
    let redDotContentView: UIView = {
        let view = UIView()
        view.backgroundColor = .redDotColor
        view.layer.cornerRadius = 10.scale375Height()
        view.layer.masksToBounds = true
        view.isHidden = true
        return view
    }()
    
    let redDotLabel: UILabel = {
        let redDot = UILabel()
        redDot.textColor = .white
        redDot.textAlignment = .center
        redDot.font = UIFont(name: "PingFangSC-Semibold", size: 12)
        return redDot
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(redDotContentView)
        redDotContentView.addSubview(redDotLabel)
        
        redDotContentView.snp.makeConstraints { make in
            make.centerY.equalTo(snp.top).offset(5.scale375Height())
            make.centerX.equalTo(snp.right).offset(-5.scale375Height())
            make.height.equalTo(20.scale375Height())
            make.width.greaterThanOrEqualTo(20.scale375Height())
        }
        
        redDotLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4.scale375())
            make.trailing.equalToSuperview().offset(-4.scale375())
            make.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateDotCount(count: Int) {
        if count == 0 {
            redDotContentView.isHidden = true
        } else {
            redDotContentView.isHidden = false
            redDotLabel.text = "\(count)"
        }
    }
    
    func startRotate() {
        layer.add(rotateAnimation, forKey: nil)
    }
    
    func endRotate() {
        layer.removeAllAnimations()
    }
}

extension VRBottomMenuView {
    @objc func menuTapAction(sender: MenuButton) {
        let index = sender.tag - 1_000
        let bottomMenu = menus[index]
        bottomMenu.tapAction?(sender)
    }
}

// MARK: MenuDataCreator
extension VRBottomMenuView {
    func generateBottomMenuData() -> [VRButtonMenuInfo] {
        if isOwner {
            return ownerBottomMenu()
        } else {
            return memberBottomMenu()
        }
    }
    
    private func ownerBottomMenu() -> [VRButtonMenuInfo] {
        var menus: [VRButtonMenuInfo] = []

        var connectionControl = VRButtonMenuInfo(normalIcon: "seat_battle")
        connectionControl.tapAction = { [weak self] sender in
            guard let self = self else { return }
            let settingItems = self.generateOwnerSettingModel()
            self.routerManager.router(action: .present(.connectionControl))
        }

        connectionControl.bindStateClosure = { [weak self] button, cancellableSet in
            guard let self = self else { return }
            coHostStore.state.subscribe(StatePublisherSelector(keyPath: \CoHostState.connected))
                .receive(on: RunLoop.main)
                .sink { [weak self] connected in
                    guard let self = self else { return }
                    if !connected.isEmpty {
                        button.setImage(internalImage("seat_in_battle"), for: .normal)
                    } else {
                        button.setImage(internalImage("seat_battle"), for: .normal)
                    }
                }
                .store(in: &cancellableSet)
        }
        menus.append(connectionControl)

        var setting = VRButtonMenuInfo(normalIcon: "live_anchor_setting_icon")
        setting.tapAction = { [weak self] sender in
            guard let self = self else { return }
            let settingItems = self.generateOwnerSettingModel()
            self.routerManager.router(action: .present(.featureSetting(settingItems)))
        }
        menus.append(setting)
#if !RTCube_APPSTORE
        var songListButton = VRButtonMenuInfo(normalIcon: "ktv_songList")
        songListButton.tapAction = { [weak self] sender in
            guard let self = self else { return }
            self.songListButtonAction?()
        }
        if coHostStore.state.value.connected.count == 0 {
            menus.append(songListButton)
        }
#endif

        var linkMic = VRButtonMenuInfo(normalIcon: "live_link_voice_room", normalTitle: "")
        linkMic.tapAction = { [weak self] sender in
            guard let self = self else { return }
            self.routerManager.router(action: .present(.voiceLinkControl))
        }
        
        linkMic.bindStateClosure = { [weak self] button, cancellableSet in
            guard let self = self else { return }
            coGuestStore.state.subscribe(StatePublisherSelector(keyPath: \CoGuestState.applicants))
                .receive(on: RunLoop.main)
                .sink(receiveValue: { list in
                    button.updateDotCount(count: list.count)
                })
                .store(in: &cancellableSet)
        }
        menus.append(linkMic)
        return menus
    }
    
    private func generateOwnerSettingModel() -> VRFeatureClickPanelModel {
        let model = VRFeatureClickPanelModel()
        model.itemSize = CGSize(width: 56.scale375(), height: 76.scale375())
        model.itemDiff = 44.scale375()
        var designConfig = VRFeatureItemDesignConfig()
        designConfig.backgroundColor = .g3
        designConfig.cornerRadius = 10
        designConfig.titleFont = .customFont(ofSize: 12)
        designConfig.type = .imageAboveTitleBottom
        model.items.append(VRFeatureItem(normalTitle: .backgroundText,
                                       normalImage: internalImage("live_setting_background_icon"),
                                       designConfig: designConfig,
                                         actionClosure: { [weak self] _ in
            guard let self = self else { return }
            self.routerManager.router(action: .present(.systemImageSelection(.background,.voice(liveListStore))))
        }))
        model.items.append(VRFeatureItem(normalTitle: .audioEffectsText,
                                       normalImage: internalImage("live_setting_audio_effects"),
                                       designConfig: designConfig,
                                         actionClosure: { [weak self] _ in
            guard let self = self else { return }
            self.routerManager.router(action: .present(.audioEffect))
        }))
        return model
    }
    
    private func memberBottomMenu() -> [VRButtonMenuInfo] {
        var menus: [VRButtonMenuInfo] = []
        var gift = VRButtonMenuInfo(normalIcon: "live_gift_icon", normalTitle: "")
        gift.tapAction = { [weak self] sender in
            guard let self = self else { return }
            self.routerManager.router(action: .present(.giftView))
        }
        menus.append(gift)
        
        var linkMic = VRButtonMenuInfo(normalIcon: "live_voice_room_link_icon", selectIcon: "live_voice_room_linking_icon")
        linkMic.tapAction = { [weak self] sender in
            guard let self = self, !isPending else { return }
            let isApplying = viewStore.state.isApplyingToTakeSeat
            if isApplying {
                isPending = true
                coGuestStore.cancelApplication { [weak self] result in
                    guard let self = self else { return }
                    isPending = false
                    switch result {
                    case .success(()):
                        viewStore.onRespondedTakeSeatRequest()
                    case .failure(let error):
                        let err = InternalError(errorInfo: error)
                        toastService.showToast(err.localizedMessage)
                    }
                }
            } else {
                let isOnSeat = seatStore.state.value.seatList.contains(where: { $0.userInfo.userID == self.selfId })
                if isOnSeat {
                    coGuestStore.disConnect { [weak self] result in
                        guard let self = self else { return }
                        if case .failure(let error) = result {
                            let err = InternalError(errorInfo: error)
                            toastService.showToast(err.localizedMessage)
                        }
                    }
                } else {
                    // request
                    if viewStore.state.isApplyingToTakeSeat {
                        toastService.showToast(.repeatRequest)
                        return
                    }
                    let seatAllToken = seatStore.state.value.seatList.prefix(KSGConnectMaxSeatCount).allSatisfy({ $0.isLocked || $0.userInfo.userID != "" })

                    if seatAllToken && coHostStore.state.value.connected.count != 0 {
                        toastService.showToast(.seatAllTokenCancelText)
                        return
                    }
                    let kTimeoutValue = 60.0
                    viewStore.onSentTakeSeatRequest()
                    
                    coGuestStore.applyForSeat(seatIndex: -1, timeout: kTimeoutValue, extraInfo: nil) { [weak self] result in
                        guard let self = self else { return }
                        handleApplyForSeatResult(result)
                    }
                }
            }
        }
        linkMic.bindStateClosure = { [weak self] button, cancellableSet in
            guard let self = self else { return }
            
            viewStore.subscribeState(StateSelector(keyPath: \VRViewState.isApplyingToTakeSeat))
                .sink { isApplying in
                    DispatchQueue.main.async {
                        button.isSelected = isApplying
                        button.isSelected ? button.startRotate() : button.endRotate()
                    }
                }
                .store(in: &cancellableSet)
            
            seatStore.state.subscribe(StatePublisherSelector(keyPath: \LiveSeatState.seatList))
                .receive(on: RunLoop.main)
                .sink { [weak self] seatInfoList in
                    guard let self = self else { return }
                    let isOnSeat = seatInfoList.contains(where: { $0.userInfo.userID == self.selfId })
                    let imageName = isOnSeat ? "live_linked_icon" : "live_voice_room_link_icon"
                    button.setImage(internalImage(imageName), for: .normal)
                }
                .store(in: &cancellableSet)
        }
        menus.append(linkMic)
#if !RTCube_APPSTORE
        var songListButton = VRButtonMenuInfo(normalIcon: "ktv_songList")
        songListButton.tapAction = { [weak self] sender in
            guard let self = self else { return }
            self.songListButtonAction?()
        }
        if coHostStore.state.value.connected.count == 0 {
            menus.append(songListButton)
        }
#endif
        return menus
    }
    
    private func handleApplyForSeatResult(_ result: Result<Void, ErrorInfo>) {
        switch result {
        case .success():
            viewStore.onRespondedTakeSeatRequest()
        case .failure(let error):
            if error.code != LiveError.requestIdRepeat.rawValue
                && error.code != LiveError.alreadyOnTheSeatQueue.rawValue {
                viewStore.onRespondedTakeSeatRequest()
            }
            let err = InternalError(errorInfo: error)
            toastService.showToast(err.localizedMessage)
        }
    }
}

extension VRBottomMenuView {
    private var selfId: String {
        TUIRoomEngine.getSelfInfo().userId
    }
    
    var deviceStore: DeviceStore {
        return DeviceStore.shared
    }
    
    var liveListStore: LiveListStore {
        return LiveListStore.shared
    }
    
    var coGuestStore: CoGuestStore {
        return CoGuestStore.create(liveID: liveID)
    }
    
    var seatStore: LiveSeatStore {
        return LiveSeatStore.create(liveID: liveID)
    }

    var battleStore: BattleStore {
        return BattleStore.create(liveID: liveID)
    }

    var coHostStore: CoHostStore {
        return CoHostStore.create(liveID: liveID)
    }
}

private extension String {
    static let backgroundText = internalLocalized("Background")
    static let audioEffectsText = internalLocalized("Audio")
    static let songText = internalLocalized("Song")
    static let repeatRequest = internalLocalized("Already on the seat queue")
    static let takeSeatApplicationRejected = internalLocalized("Take seat application has been rejected")
    static let takeSeatApplicationTimeout = internalLocalized("Take seat application timeout")
    static let seatAllTokenCancelText = internalLocalized("The seats are all taken.")
}
