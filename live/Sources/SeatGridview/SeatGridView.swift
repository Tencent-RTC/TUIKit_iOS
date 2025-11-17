//
//  SeatGridView.swift
//  SeatGridView
//
//  Created by krabyu on 2024/10/16.
//

import UIKit
import Combine
import RTCRoomEngine
import RTCCommon
import AtomicXCore

private struct RequestCallback {
    let onAccepted: SGOnRequestAccepted
    let onRejected: SGOnRequestRejected
    let onCancelled: SGOnRequestCancelled
    let onTimeout: SGOnRequestTimeout
    let onError: SGOnRequestError
}

public class SeatGridView: UIView {
    private var isConnection: Bool = false {
        didSet {
            updateLayoutForCurrentMode()
        }
    }

    private lazy var coHostContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()

    private var battleContainerView: UIView?

    private var coHostViews: [UIView] = []

    // MARK: - public property.
    public weak var delegate: SGSeatViewDelegate?
    public weak var sgDelegate: SGHostAndBattleViewDelegate?

    public init() {
        super.init(frame: .zero)
        SGDataReporter.reportEventData(event: .panelShowSeatGridView)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        SGDataReporter.reportEventData(event: .panelHideSeatGridView)
        debugPrint("deinit:\(self)")
    }
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        subscribeState()
        isViewReady = true
    }
    
    // MARK: - Private store property.
    private var observers: SGSeatGridObserverList = SGSeatGridObserverList()
    private var cancellableSet: Set<AnyCancellable> = []
    private var isViewReady = false
    private var liveID = ""
    
    // MARK: - Private calculate property.
    
    private(set) lazy var viewManager = SGViewManager(provider: self)
    
    private lazy var seatContainerView: UICollectionView = {
        let layoutConfig = SGSeatViewLayoutConfig()
        let layout = SeatGridViewLayout(rowSpacing: layoutConfig.rowSpacing, rowConfigs: layoutConfig.rowConfigs)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.register(SGSeatContainerCell.self, forCellWithReuseIdentifier: SGSeatContainerCell.identifier)
        view.delegate = self
        view.dataSource = self
        return view
    }()
    
    private var isSelfOwner: Bool {
        let selfId = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let ownerId = liveListStore.state.value.currentLive.liveOwner.userID
        if selfId.isEmpty || ownerId.isEmpty {
            return false
        }
        return selfId == ownerId
    }
}

// MARK: - public API
extension SeatGridView {
    public func setLiveId(_ liveId: String) {
        self.liveID = liveId
    }
    
    public func setLayoutMode(layoutMode: SGLayoutMode, layoutConfig: SGSeatViewLayoutConfig? = nil) {
        SGDataReporter.reportEventData(event: .methodCallSeatGridViewSetLayoutMode)
        viewManager.setLayoutMode(layoutMode: layoutMode, layoutConfig: layoutConfig)
    }
    
    public func setSeatViewDelegate(_ delegate: SGSeatViewDelegate) {
        SGDataReporter.reportEventData(event: .methodCallSeatGridViewSetSeatViewDelegate)
        self.delegate = delegate
    }
    
    public static func callExperimentalAPI(_ jsonStr: String) {
        do {
            guard let data = jsonStr.data(using: .utf8) else {
                throw NSError(domain: "InvalidJSON", code: -1, userInfo: nil)
            }
            
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            if let api = jsonObject?["api"] as? String, api == "component",
               let component = jsonObject?["component"] as? Int {
                switch component {
                case Constants.DataReport.componentLiveRoom:
                    Constants.component = Constants.DataReport.componentLiveRoom
                case Constants.DataReport.componentVoiceRoom:
                    Constants.component = Constants.DataReport.componentVoiceRoom
                default:
                    Constants.component = Constants.DataReport.componentCoreView
                }
                return
            }
            
            if let api = jsonObject?["api"] as? String, api == "setAvatarPlaceholderImage" {
                SeatGridViewLog.info("API setAvatarPlaceholderImage jsonString:\(jsonStr)")
                guard let paramsDic = jsonObject?["params"] as? [String : Any] else {
                    return
                }
                if let imagePath = paramsDic["imagePath"] as? String {
                    SGResourceConfig.avatarPlaceholderImage = imagePath
                }
                return
            }
            if let api = jsonObject?["api"] as? String, api == "setHttpHeaderField" {
                SeatGridViewLog.info("API setHttpHeaderField jsonString:\(jsonStr)")
                guard let paramsDic = jsonObject?["params"] as? [String : Any] else {
                    return
                }
                if let httpHeaderFieldKey = paramsDic["httpHeaderFieldKey"] as? String {
                    SGResourceConfig.httpHeaderFieldKey = httpHeaderFieldKey
                }
                if let httpHeaderFieldValue = paramsDic["httpHeaderFieldValue"] as? String {
                    SGResourceConfig.httpHeaderFieldValue = httpHeaderFieldValue
                }
                return
            }
        } catch let error {
            VRLog.error("callExperimentalAPI \(error.localizedDescription)")
        }
        TUIRoomEngine.sharedInstance().callExperimentalAPI(jsonStr: jsonStr) { message in
        }
    }
}

// MARK: - public API
extension SeatGridView {
    public func addObserver(observer: SeatGridViewObserver) {
        observers.addObserver(observer)
    }
    
    public func removeObserver(observer: SeatGridViewObserver) {
        observers.removeObserver(observer)
    }
}
extension SeatGridView: SGViewManagerDataProvider {
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

    var coHostStore: CoHostStore {
        return CoHostStore.create(liveID: liveID)
    }

    var battleStore: BattleStore {
        return BattleStore.create(liveID: liveID)
    }

    var seatListCount: Int {
        return seatStore.state.value.seatList.count
    }
}

extension SeatGridView {

    private func subscribeBattleState() {
        battleStore.battleEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }

                switch event {
                    case .onBattleStarted(_, _, _):
                        createBattleContainerView()
                    default:
                        break
                }
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - UICollectionViewDataSource & UICollectionViewDelegate
extension SeatGridView: UICollectionViewDataSource, UICollectionViewDelegate {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return seatStore.state.value.seatList.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SGSeatContainerCell.identifier, for: indexPath)
        if let cell = cell as? SGSeatContainerCell {
            configureSeatView(view: cell, at: indexPath)
            bindSeatViewClosure(view: cell)
            bindSeatViewState(view: cell, at: indexPath)
        }
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? SGSeatContainerCell, let seatView =  cell.contentContainerView.subviews.first else { return }
        let seatInfo = seatStore.state.value.seatList[indexPath.row]
        notifyObserverEvent { observer in
            observer.onSeatViewClicked(seatView: seatView, seatInfo: TUISeatInfo(from: seatInfo))
        }
    }
    
    private func configureSeatView(view: SGSeatContainerCell, at indexPath: IndexPath) {
        let seatInfo = seatStore.state.value.seatList[indexPath.row]
        let tuiSeatInfo =  TUISeatInfo(from: seatInfo)
        let customView = self.delegate?.seatGridView(self, createSeatView: tuiSeatInfo)
        let ownerId = liveListStore.state.value.currentLive.liveOwner.userID
        view.configure(with: SeatContainerCellModel(customView: customView, seatInfo: tuiSeatInfo, ownerId: ownerId))
    }
    
    private func bindSeatViewClosure(view: SGSeatContainerCell) {
        view.volumeClosure = { [weak self] volume, customView in
            guard let self = self else { return }
            self.delegate?.seatGridView(self, updateUserVolume: volume, seatView: customView)
        }
        view.seatInfoClosure = { [weak self] seatInfo, customView in
            guard let self = self else { return }
            self.delegate?.seatGridView(self, updateSeatView: seatInfo, seatView: customView)
        }
    }
    
    private func bindSeatViewState(view: SGSeatContainerCell, at indexPath: IndexPath) {
        let seatInfoPublisher = seatStore.state.subscribe(StatePublisherSelector(keyPath: \LiveSeatState.seatList))
            .compactMap { seatList -> SeatInfo? in
                guard indexPath.row < seatList.count else { return nil }
                let seatInfo = seatList[indexPath.row]
                return seatInfo
            }
            .eraseToAnyPublisher()
        
        seatInfoPublisher
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak view] seatInfo in
                guard let view = view else { return }
                view.seatInfo = TUISeatInfo(from: seatInfo)
            })
            .store(in: &view.cancellableSet)
        seatStore.state.subscribe(StatePublisherSelector(keyPath: \LiveSeatState.speakingUsers))
            .removeDuplicates()
            .combineLatest(seatInfoPublisher)
            .receive(on: RunLoop.main)
            .sink { [weak view] userVolumeMap, seatInfo in
                guard let seatView = view else { return }
                let userId = seatInfo.userInfo.userID
                if !userId.isEmpty {
                    if let volume = userVolumeMap[userId], volume > 25 {
                        seatView.isSpeaking = true
                        seatView.volume = volume
                    } else {
                        seatView.isSpeaking = false
                    }
                }
            }
            .store(in: &view.cancellableSet)

        seatInfoPublisher
            .receive(on: RunLoop.main)
            .sink { [weak view] seatInfo in
                guard let seatView = view else { return }
                let userId = seatInfo.userInfo.userID
                if !userId.isEmpty {
                    seatView.isAudioMuted = (seatInfo.userInfo.microphoneStatus == .off)
                }
            }
            .store(in: &view.cancellableSet)
    }
}

// MARK: - Private func.
private extension SeatGridView {
    
    private func runOnMainThread(_ closure: @escaping () -> Void) {
        DispatchQueue.main.async {
            closure()
        }
    }
    
    private func constructViewHierarchy() {
        addSubview(seatContainerView)
        addSubview(coHostContainerView)
        bringSubviewToFront(coHostContainerView)
    }
    
    private func activateConstraints() {
        seatContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        coHostContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func subscribeState() {
        subscribeViewState()
        subscribeSeatState()
        subscribeBattleState()
    }
    
    private func subscribeViewState() {
        subscribeViewState(StateSelector(projector: {  $0 }))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.updateSeatGridLayout(layoutConfig: state.layoutConfig)
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeSeatState() {
        seatStore.state.subscribe(StatePublisherSelector(keyPath: \LiveSeatState.seatList))
            .map { $0.count }
            .filter { $0 != 0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] seatCount in
                guard let self = self else { return }
                if !self.isConnection {
                    self.viewManager.onSeatCountChanged(seatCount: seatCount)
                    self.seatContainerView.reloadData()
                }
            }
            .store(in: &cancellableSet)

        seatStore.state.subscribe(StatePublisherSelector(keyPath: \LiveSeatState.seatList))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] seatList in
                guard let self = self else { return }

                guard !liveListStore.state.value.currentLive.isEmpty else { return }
                if seatList.contains(where: { $0.userInfo.liveID != self.liveListStore.state.value.currentLive.liveID}) {
                    self.isConnection = true
                    createCoHostView(seatList: seatList)
                }
            }
            .store(in: &cancellableSet)

        coHostStore.state
            .subscribe(StatePublisherSelector(keyPath: \CoHostState.connected))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink{ [weak self] connected in
                guard let self = self else { return }
                guard !liveListStore.state.value.currentLive.isEmpty else { return }
                if connected.contains(where: { $0.liveID == self.liveListStore.state.value.currentLive.liveID}) {
                    self.isConnection = true
                    KickUsersInConnect()
                } else {
                    self.isConnection = false
                }
            }.store(in: &cancellableSet)

    }
    
    private func updateSeatGridLayout(layoutConfig: SGSeatViewLayoutConfig) {
        let layout = SeatGridViewLayout(rowSpacing: layoutConfig.rowSpacing, rowConfigs: layoutConfig.rowConfigs)
        seatContainerView.collectionViewLayout.invalidateLayout()
        seatContainerView.setCollectionViewLayout(layout, animated: true)
    }
    
    private func isAutoOnSeat() -> Bool {
        let selfId = TUIRoomEngine.getSelfInfo().userId
        let liveInfo = liveListStore.state.value.currentLive
        
        return selfId == liveInfo.liveOwner.userID ||
               liveInfo.seatMode == .free
    }

    private func KickUsersInConnect() {
        if !isSelfOwner {
            return
        }
        let seatList = seatStore.state.value.seatList
        let currentLiveID = liveListStore.state.value.currentLive.liveID
        let removeCount = liveListStore.state.value.currentLive.maxSeatCount - KSGConnectMaxSeatCount
        guard let firstConnectIndex = seatList.firstIndex(where: {
            let userLiveID = $0.userInfo.liveID
            return !userLiveID.isEmpty && userLiveID != currentLiveID
        }) else {
            return
        }

        let startIndex = max(0, firstConnectIndex - removeCount)
        let endIndex = firstConnectIndex - 1
        if startIndex > endIndex {
            return
        }
        let targetSeats = Array(seatList[startIndex...endIndex])

        for seatInfo in targetSeats {
            let userID = seatInfo.userInfo.userID
            guard !userID.isEmpty else { continue }
            makeToast(message: .kickOutByConnectTex,duration: 3.5)
            seatStore.kickUserOutOfSeat(userID: seatInfo.userInfo.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                    case .success():
                        break
                    case .failure(let error):
                        let err = InternalError(errorInfo: error)
                        makeToast(message: err.localizedMessage)
                        break
                }
            }
        }
    }

    private func notifyObserverEvent(notifyAction: @escaping (_ observer: SeatGridViewObserver) -> Void) {
        observers.notifyObservers(callback: notifyAction)
    }
    
    private func subscribeViewState<Value>(_ selector: StateSelector<SGViewState, Value>) -> AnyPublisher<Value, Never> {
       return viewManager.observerState.subscribe(selector)
   }
    
}

// MARK: - Connection func
extension SeatGridView {

    private func createCoHostView(seatList: [SeatInfo]) {
        coHostContainerView.subviews.forEach {
            $0.snp.removeConstraints()
            $0.subviews.forEach { $0.snp.removeConstraints() }
            $0.removeFromSuperview()
        }
        coHostViews.removeAll()
        coHostViews.removeAll()

        let viewSize = CGSize(width: 94.scale375(), height: 92.scale375())
        let columnSpacing = 0.scale375()
        let rowSpacing = 0.scale375()
        let columnCount = 4
        let maxViewsPerColumn = 3

        let columns = (0..<columnCount).map { _ in UIView() }
        columns.forEach { coHostContainerView.addSubview($0) }

        let currentOwnerId = liveListStore.state.value.currentLive.liveOwner.userID
        let currentliveID = liveListStore.state.value.currentLive.liveID
        guard let startIndex = seatList.firstIndex(where: { $0.userInfo.userID == currentOwnerId }) else {
            return
        }
        let leftSeats = seatList[startIndex..<min(startIndex + 6, seatList.count)].enumerated()

        guard let rightStartIndex = seatList.firstIndex(where: { $0.userInfo.userID != currentOwnerId && $0.userInfo.liveID != currentliveID}) else {
            return
        }
        let rightSeats = seatList[rightStartIndex..<min(rightStartIndex + 6, seatList.count)].enumerated()

        for (index, seatInfo) in leftSeats {
            guard let cohostView = sgDelegate?.createCoHostView(seatInfo: seatInfo, isInvite: true) else { continue }
            coHostViews.append(cohostView)
            
            let columnIndex = index % 2 == 0 ? 0 : 1
            columns[columnIndex].addSubview(cohostView)
        }

        for (index, seatInfo) in rightSeats {
            guard let cohostView = sgDelegate?.createCoHostView(seatInfo: seatInfo, isInvite: false) else { continue }
            coHostViews.append(cohostView)
            
            let columnIndex = index % 2 == 0 ? 2 : 3
            columns[columnIndex].addSubview(cohostView)
        }

        for (index, column) in columns.enumerated() {
            column.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.width.equalTo(viewSize.width)
                
                if index == 0 {
                    make.leading.equalToSuperview()
                } else {
                    make.leading.equalTo(columns[index-1].snp.trailing).offset(columnSpacing - 0.5)
                }
            }
        }

        for column in columns {
            for (rowIndex, view) in column.subviews.enumerated() {
                view.snp.makeConstraints { make in
                    make.size.equalTo(viewSize)
                    make.centerX.equalToSuperview()
                    
                    if rowIndex == 0 {
                        make.top.equalToSuperview()
                    } else {
                        make.top.equalTo(column.subviews[rowIndex-1].snp.bottom).offset(rowSpacing - 0.5)
                    }
                }
            }
        }

        coHostContainerView.snp.makeConstraints { make in
            make.width.equalTo(372.scale375())
            make.height.equalTo(282.scale375Height())
            make.top.equalToSuperview()
        }
    }

    private func updateLayoutForCurrentMode() {
        seatContainerView.isHidden = isConnection
        coHostContainerView.isHidden = !isConnection
        
        if isConnection {
            layoutcoHostViews()
        } else {
            seatContainerView.reloadData()
        }
    }

    private func layoutcoHostViews() {
        let viewSize = CGSize(width: 94.scale375(), height: 92.scale375())
        let containerSize = CGSize(width: 372.scale375(), height: 282.scale375Height())
        let columnSpacing = 0.scale375()
        let rowSpacing = 0.scale375()

        coHostContainerView.snp.remakeConstraints { make in
            make.size.equalTo(containerSize)
            make.top.equalToSuperview()
        }

        for (columnIndex, column) in coHostContainerView.subviews.enumerated() {
            column.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.width.equalTo(viewSize.width)

                if columnIndex == 0 {
                    make.leading.equalToSuperview()
                } else {
                    make.leading.equalTo(coHostContainerView.subviews[columnIndex-1].snp.trailing).offset(columnSpacing - 0.5)
                }
            }

            for (rowIndex, view) in column.subviews.enumerated() {
                view.snp.remakeConstraints { make in
                    make.size.equalTo(viewSize)
                    make.centerX.equalToSuperview()

                    if rowIndex == 0 {
                        make.top.equalToSuperview()
                    } else {
                        make.top.equalTo(column.subviews[rowIndex-1].snp.bottom).offset(rowSpacing - 0.5)
                    }
                }
            }
        }
    }

}

// MARK: - Battle func
extension SeatGridView {
    private func createBattleContainerView() {
        removeBattleContainerView()
        battleContainerView = sgDelegate?.createBattleContainerView()
        guard let battleContainerView = battleContainerView else { return }
        addSubview(battleContainerView)
        battleContainerView.snp.makeConstraints { make in
            make.edges.equalTo(coHostContainerView)
        }
    }

    private func removeBattleContainerView() {
        guard let battleContainerView = battleContainerView else {return }
        battleContainerView.subviews.forEach { $0.removeFromSuperview() }
        battleContainerView.removeFromSuperview()
        battleContainerView.snp.removeConstraints()
    }
}

fileprivate extension String {
    static let kickOutByConnectTex = internalLocalized("The connection is successful. Users beyond the first 6 seats have been removed.")
}
