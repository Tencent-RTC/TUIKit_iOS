//
//  AudienceContainerView.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2025/6/11.
//

import AtomicXCore
import RTCCommon
import TUICore
import AtomicX
public enum AudienceViewFeature {
    case sliding
    case floatWin
    case liveData
    case visitorCnt
    case coGuest
}

public class AudienceContainerView: UIView {
    public weak var delegate: AudienceContainerViewDelegate?
    public weak var dataSource: AudienceContainerViewDataSource?
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
        let rootRoute: AudienceRoute = .audience
        let routerCenter = AudienceRouterControlCenter(rootViewController: getCurrentViewController() ?? (TUITool.applicationKeywindow().rootViewController ?? UIViewController()), rootRoute: rootRoute, routerManager: routerManager)
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
        StateCache.shared.clear()
        AudioEffectStore.shared.reset()
        DeviceStore.shared.reset()
        BaseBeautyStore.shared.reset()
        LiveKitLog.info("\(#file)", "\(#line)", "deinit AudienceContainerView: \(self)")
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

// MARK: - Public

public extension AudienceContainerView {
    func disableSliding(_ isDisable: Bool) {
        disableFeature(.sliding, isDisable: isDisable)
    }
    
    func disableHeaderFloatWin(_ isDisable: Bool) {
        disableFeature(.floatWin, isDisable: isDisable)
    }
    
    func disableHeaderLiveData(_ isDisable: Bool) {
        disableFeature(.liveData, isDisable: isDisable)
    }
    
    func disableHeaderVisitorCnt(_ isDisable: Bool) {
        disableFeature(.visitorCnt, isDisable: isDisable)
    }
    
    func disableFooterCoGuest(_ isDisable: Bool) {
        disableFeature(.coGuest, isDisable: isDisable)
    }
}

// ** Only should use for test **
extension AudienceContainerView {
    @objc func disableSlidingForTest(_ isDisable: NSNumber) {
        disableSliding(isDisable.boolValue)
    }
    
    @objc func disableHeaderFloatWinForTest(_ isDisable: NSNumber) {
        disableHeaderFloatWin(isDisable.boolValue)
    }
    
    @objc func disableHeaderLiveDataForTest(_ isDisable: NSNumber) {
        disableHeaderLiveData(isDisable.boolValue)
    }
    
    @objc func disableHeaderVisitorCntForTest(_ isDisable: NSNumber) {
        disableHeaderVisitorCnt(isDisable.boolValue)
    }
    
    @objc func disableFooterCoGuestForTest(_ isDisable: NSNumber) {
        disableFooterCoGuest(isDisable.boolValue)
    }
}

// MARK: - Private

extension AudienceContainerView {
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
    
    private func disableFeature(_ feature: AudienceViewFeature, isDisable: Bool) {
        AudienceStore.disableFeature(feature, isDisable: isDisable)
    }
}

extension AudienceContainerView: LiveListViewDataSource {
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
            var firstLiveInfo = LiveInfo()
            firstLiveInfo.liveID = liveID
            return firstLiveInfo
        }
    }
}

extension AudienceContainerView: LiveListViewDelegate {
    public func onCreateView(liveInfo: LiveInfo) -> UIView {
        let audienceCell = AudienceSliderCell(liveInfo: liveInfo, routerManager: routerManager, routerCenter: routerCenter)
        audienceCell.delegate = self
        audienceCell.rotateScreenDelegate = self
        return audienceCell
    }
    
    public func onViewWillSlideIn(view: UIView) {
        if let view = view as? AudienceSliderCell {
            view.onViewWillSlideIn()
        }
    }
    
    public func onViewDidSlideIn(view: UIView) {
        if let view = view as? AudienceSliderCell {
            view.onViewDidSlideIn()
        }
    }
    
    public func onViewSlideInCancelled(view: UIView) {
        if let view = view as? AudienceSliderCell {
            view.onViewSlideInCancelled()
        }
    }
    
    public func onViewWillSlideOut(view: UIView) {
        if let view = view as? AudienceSliderCell {
            view.onViewWillSlideOut()
        }
    }
    
    public func onViewDidSlideOut(view: UIView) {
        if let view = view as? AudienceSliderCell {
            view.onViewDidSlideOut()
        }
    }
    
    public func onViewSlideOutCancelled(view: UIView) {
        if let view = view as? AudienceSliderCell {
            view.onViewSlideOutCancelled()
        }
    }
}

extension AudienceContainerView: AudienceListCellDelegate {
    func handleScrollToNewRoom(roomId: String, ownerId: String, manager: AudienceStore,
                               coreView: LiveCoreView,
                               relayoutCoreViewClosure: @escaping () -> Void)
    {
        routerCenter.handleScrollToNewRoom(manager: manager, coreView: coreView)
        liveID = roomId
        self.ownerId = ownerId
        self.coreView = coreView
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
        delegate?.onLiveEnded(roomId: roomId, avatarUrl: avatarUrl, userName: userName)
    }
}

extension AudienceContainerView: FloatWindowProvider {
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

extension AudienceContainerView: RotateScreenDelegate {
    public func rotateScreen(isPortrait: Bool) {
        disableSliding(!isPortrait)

        rotateScreenDelegate?.rotateScreen(isPortrait: isPortrait)
    }
}
