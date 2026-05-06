//
//  AudienceView.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2025/6/11.
//

import AtomicXCore
import AtomicX
import TUICore

public class AudienceView: UIView {
    public weak var delegate: AudienceViewDelegate?
    public weak var dataSource: AudienceViewDataSource?
    public weak var rotateScreenDelegate: RotateScreenDelegate?
    
    public init(roomId: String) {
        self.liveID = roomId
        super.init(frame: .zero)
    }
    
    public init(liveInfo: LiveInfo) {
        self.liveInfo = liveInfo
        self.liveID = liveInfo.liveID
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private weak var coreView: LiveCoreView?
    private var liveID: String
    private var liveInfo: LiveInfo?
    private var ownerId = ""
    private var relayoutCoreViewClosure: () -> Void = {}
    private var cursor = ""
    private var isFirstFetch = true
    private var isFirstRoom = true
    private let fetchCount = 20
    private let routerManager = AudienceRouterManager()
    private lazy var routerCenter: AudienceRouterControlCenter = {
        let routerCenter = AudienceRouterControlCenter(rootViewController: getCurrentViewController() ?? (TUITool.applicationKeywindow().rootViewController ?? UIViewController()), routerManager: routerManager)
        return routerCenter
    }()
    
    private lazy var sliderView: LiveListPagerView = {
        let view = LiveListPagerView()
        view.dataSource = self
        view.delegate = self
        return view
    }()
    
    private var isViewReady = false
    override public func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        subscribeRouter()
        constructViewHierarchy()
        activateConstraints()
    }
    
    deinit {
        AudioEffectStore.shared.reset()
        DeviceStore.shared.reset()
        BaseBeautyStore.shared.reset()
        LiveKitLog.info("\(#file)", "\(#line)", "deinit AudienceView: \(self)")
    }
    
    func leaveLive(onSuccess: (() -> Void)?, onError: ((ErrorInfo) -> Void)?) {
        LiveListStore.shared.leaveLive { result in
            switch result {
            case .success(()):
                onSuccess?()
            case .failure(let err):
                onError?(err)
            }
        }
    }
}

// MARK: - Private

extension AudienceView {
    private func subscribeRouter() {
        routerCenter.subscribeRouter()
    }
    
    private func constructViewHierarchy() {
        addSubview(sliderView)
    }
    
    private func activateConstraints() {
        sliderView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func disableSliding(_ isDisable: Bool) {
        AudienceStore.disableSliding(isDisable)
    }
}

extension AudienceView: LiveListViewDataSource {
    func fetchLiveList(completionHandler: @escaping LiveListCallback) {
        guard cursor != "" || isFirstFetch else { return }
        isFirstFetch = false
        if let dataSource = dataSource {
            dataSource.fetchLiveList(cursor: cursor) { [weak self] cursor, list in
                guard let self = self else { return }
                onFetchLiveListSuccess(cursor: cursor, list: list, completionHandler: completionHandler)
            } onError: { [weak self] code, message in
                guard let self = self else { return }
                onFetchLiveListError(code: code, message: message, completionHandler: completionHandler)
            }
        } else {
            LiveListStore.shared.fetchLiveList(cursor: cursor, count: fetchCount) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(()):
                    onFetchLiveListSuccess(cursor: LiveListStore.shared.state.value.liveListCursor, list: LiveListStore.shared.state.value.liveList, completionHandler: completionHandler)
                case .failure(let err):
                    onFetchLiveListError(code: err.code, message: err.message, completionHandler: completionHandler)
                }
            }
        }
    }
    
    private func onFetchLiveListSuccess(cursor: String, list: [LiveInfo], completionHandler: @escaping LiveListCallback) {
        var resultList: [LiveInfo] = []
        self.cursor = cursor
        if isFirstRoom {
            resultList.append(getFirstLiveInfo())
            isFirstRoom = false
        }
        let filteredList = list.filter { $0.liveID != liveID }
        resultList.append(contentsOf: filteredList)
        completionHandler(resultList)
    }
    
    private func onFetchLiveListError(code: Int, message: String, completionHandler: @escaping LiveListCallback) {
        LiveKitLog.error("\(#file)", "\(#line)", "fetchLiveList:[onError:[code:\(code),message:\(message)]]")
        var resultList: [LiveInfo] = []
        let firstLiveInfo = getFirstLiveInfo()
        resultList.append(firstLiveInfo)
        completionHandler(resultList)
    }
    
    private func getFirstLiveInfo() -> LiveInfo {
        if let liveInfo = liveInfo {
            return liveInfo
        } else {
            var firstLiveInfo = LiveInfo(seatTemplate: .videoDynamicGrid9Seats)
            firstLiveInfo.liveID = liveID
            return firstLiveInfo
        }
    }
}

extension AudienceView: LiveListViewDelegate {
    func onCreateView(liveInfo: LiveInfo) -> UIView {
        let liveView = AudienceLiveView(liveInfo: liveInfo, routerManager: routerManager)
        liveView.delegate = self
        liveView.rotateScreenDelegate = self
        delegate?.audienceView(self, onCreateLiveView: liveView, for: liveInfo)
        liveView.setupLiveID(liveInfo.liveID)
        return liveView
    }
    
    func onViewWillSlideIn(view: UIView) {
        if let view = view as? AudienceLiveView {
            view.onViewWillSlideIn()
        }
    }
    
    func onViewDidSlideIn(view: UIView) {
        if let view = view as? AudienceLiveView {
            view.onViewDidSlideIn()
            delegate?.audienceView(self, liveViewDidAppear: view, for: view.liveInfo)
        }
    }
    
    func onViewSlideInCancelled(view: UIView) {
        if let view = view as? AudienceLiveView {
            view.onViewSlideInCancelled()
        }
    }
    
    func onViewWillSlideOut(view: UIView) {
        if let view = view as? AudienceLiveView {
            view.onViewWillSlideOut()
        }
    }
    
    func onViewDidSlideOut(view: UIView) {
        if let view = view as? AudienceLiveView {
            view.onViewDidSlideOut()
            delegate?.audienceView(self, liveViewDidDisappear: view, for: view.liveInfo)
        }
    }
    
    func onViewSlideOutCancelled(view: UIView) {
        if let view = view as? AudienceLiveView {
            view.onViewSlideOutCancelled()
        }
    }
}

extension AudienceView: AudienceLiveViewDelegate {
    func handleScrollToNewRoom(roomId: String, ownerId: String, manager: AudienceStore,
                               liveView: AudienceLiveView,
                               relayoutCoreViewClosure: @escaping () -> Void)
    {
        routerCenter.handleScrollToNewRoom(manager: manager)
        liveID = roomId
        self.ownerId = ownerId
        self.coreView = liveView.coreView
        self.relayoutCoreViewClosure = relayoutCoreViewClosure
    }
    
    func showFloatWindow() {
        delegate?.onClickFloatWindow()
    }
    
    func showAtomicToast(message: String, toastStyle: ToastStyle) {
        showAtomicToast(text: message, style: toastStyle)
    }
    
    func disableScrolling() {
        sliderView.disableScrolling()
    }
    
    func enableScrolling() {
        sliderView.enableScrolling()
    }
    
    func scrollToNextPage() {
        sliderView.scrollToNextPage()
    }
    
    func onRoomDismissed(roomId: String, avatarUrl: String, userName: String) {
        guard roomId == liveID else { return }
        delegate?.onLiveEnded(roomId: roomId, ownerName: userName, ownerAvatarUrl: avatarUrl)
    }
}

extension AudienceView: FloatWindowProvider {
    public func getRoomId() -> String {
        liveID
    }
    
    public func getOwnerId() -> String {
        ownerId
    }

    public func getCoreView() -> LiveCoreView {
        return coreView ?? LiveCoreView(viewType: .playView)
    }
    
    public func relayoutCoreView() {
        relayoutCoreViewClosure()
    }
    
    public func getIsLinking() -> Bool {
        CoGuestStore.create(liveID: liveID).state.value.connected.isOnSeat()
    }
}

extension AudienceView: RotateScreenDelegate {
    public func rotateScreen(isPortrait: Bool) {
        disableSliding(!isPortrait)
        rotateScreenDelegate?.rotateScreen(isPortrait: isPortrait)
    }
}

public extension AudienceViewDelegate {
    func audienceView(_ audienceView: AudienceView,
                      onCreateLiveView liveView: AudienceLiveView,
                      for liveInfo: LiveInfo) {
        // Default: no per-room UI customization
    }

    func audienceView(_ audienceView: AudienceView,
                      liveViewDidAppear liveView: AudienceLiveView,
                      for liveInfo: LiveInfo) {
        // Default: use built-in videoViewDelegate
    }
    

    func audienceView(_ audienceView: AudienceView,
                      liveViewDidDisappear liveView: AudienceLiveView,
                      for liveInfo: LiveInfo) {
        // Default: use built-in videoViewDelegate
    }
}
