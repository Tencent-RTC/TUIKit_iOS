//
//  BattleInfoView.swift
//  TUILiveKit
//
//  Created by krabyu /on 2024/9/4.
//

import UIKit
import Combine
import RTCCommon
import RTCRoomEngine
import AtomicXCore

public enum VRBattleResultType {
    case draw
    case victory
    case defeat
}

class BattleInfoView: UIView {

    private lazy var durationCountDownPublisher = battleStore.state.subscribe(StatePublisherSelector(keyPath: \BattleState.currentBattleInfo?.config.duration))

    private lazy var battleIdPublisher = battleStore.state.subscribe(StatePublisherSelector(keyPath: \BattleState.currentBattleInfo?.battleID))
    private lazy var battleSocrePublisher = battleStore.state.subscribe(StatePublisherSelector(keyPath: \BattleState.battleScore))
    private lazy var battleUsersPublisher = battleStore.state.subscribe(StatePublisherSelector(keyPath: \BattleState.battleUsers))

    private lazy var startTimePublisher = battleStore.state.subscribe(StatePublisherSelector(keyPath: \BattleState.currentBattleInfo?.startTime))

    private let liveID: String
    private let routerManager: VRRouterManager
    private var cancellableSet: Set<AnyCancellable> = []
    private var timer: Timer?
    private var remainingTime: TimeInterval = 0
    private var duration: Int = 300

    private var ownerId: String {liveListStore.state.value.currentLive.liveOwner.userID}

    init(liveID: String, routerManager: VRRouterManager) {
        self.liveID = liveID
        self.routerManager = routerManager
        super.init(frame: .zero)
        backgroundColor = .clear
        self.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cleanupTimer()
    }

    private lazy var singleBattleScoreView: SingleBattleScoreView = {
        let view = SingleBattleScoreView()
        view.isHidden = false
        return view
    }()
    
    private let battleTimeView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = internalImage("live_battle_time_background_icon")
        imageView.isHidden = false
        return imageView
    }()
    
    private let startBattleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = internalImage("live_battle_start")
        return imageView
    }()
    
    private let battleResultImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = false
        return imageView
    }()

    private lazy var timeLable: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        return label
    }()

    private var isBattleStarted = false

    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        backgroundColor = .clear
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    private func constructViewHierarchy() {
        addSubview(singleBattleScoreView)
        addSubview(battleTimeView)
        addSubview(startBattleImageView)
        addSubview(battleResultImageView)
        battleTimeView.addSubview(timeLable)
    }
    
    private func activateConstraints() {
        singleBattleScoreView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
            make.width.equalTo(376.scale375())
            make.height.equalTo(14.scale375Height())
        }
        battleTimeView.snp.makeConstraints { make in
            make.top.equalTo(singleBattleScoreView.snp.bottom)
            make.centerX.equalToSuperview()
            make.width.equalTo(103.scale375())
            make.height.equalTo(22.scale375Height())
        }
        startBattleImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(217.scale375())
            make.height.equalTo(63.scale375Height())
        }
        battleResultImageView.snp.makeConstraints { make in
            make.center.equalToSuperview() 
            make.width.equalTo(123.scale375())
            make.height.equalTo(142.scale375())
        }
        timeLable.snp.remakeConstraints { make in
            make.centerY.centerX.equalToSuperview()
        }
    }
    
    private func bindInteraction() {
        subscribeBattleState()
    }

    private func subscribeBattleState() {
        durationCountDownPublisher
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] duration in
                guard let self = self ,let duration = duration else { return }
                self.onDurationChnaged(duration: Int(duration))
            }
            .store(in: &cancellableSet)

        startTimePublisher
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] startTime in
                guard let self = self ,let startTime = startTime else { return }
                self.startTimer(startTime: TimeInterval(startTime))
            }
            .store(in: &cancellableSet)

        battleIdPublisher
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink {[weak self] battleId in
                guard let self = self else {return}
                if battleId == nil {
                    onBattleEnd()
                }
            }
            .store(in: &cancellableSet)


        battleUsersPublisher
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink {[weak self] battleUser in
                guard let self = self else {return}
                if battleUser.contains(where: {$0.liveID == self.liveListStore.state.value.currentLive.liveID}) && battleUser.count > 1 {
                    onBattleStart()
                }
            }
            .store(in: &cancellableSet)

        battleSocrePublisher
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink {[weak self] battleScore in
                guard let self = self else {return}
                self.updateBattleScore(battleScore: battleScore)
            }
            .store(in: &cancellableSet)

    }
    
    private func onDurationChnaged(duration: Int) {
        self.duration = duration
    }
    
    private func onBattleScoreChanged() {

    }
        
    private func onBattleStart() {
        timeLable.text = ""
        battleResultImageView.isHidden = true
        self.isHidden = false
        self.startBattleImageView.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.startBattleImageView.isHidden = true
        }
    }

    private func startTimer(startTime: TimeInterval) {
        timer?.invalidate()

        guard let duration = battleStore.state.value.currentBattleInfo?.config.duration else {
            return
        }

        let elapsedTime = Date().timeIntervalSince1970 - startTime
        guard elapsedTime < duration else {
            return
        }

        remainingTime = duration - elapsedTime

        updateTime(Int(remainingTime))

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.remainingTime -= 1
            self.updateTime(Int(self.remainingTime))

            guard self.remainingTime > 0 else {
                self.timer?.invalidate()
                self.timer = nil
                self.onBattleEnd()
                return
            }
        }
    }

    private func cleanupTimer() {
        timer?.invalidate()
        timer = nil
    }

    func onBattleEnd() {
        cleanupTimer()
        showBattleResult(type: .draw)
        timeLable.text = .battleEndText
        timeLable.textAlignment = .center
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isHidden = true
        }
    }
    
    private func updateTime(_ time: Int){
        guard time > 0 else {
            timeLable.text = String.battleEndText
            return
        }
        timeLable.text = .inPKText + String(format: "%d:%02d", time / 60, time % 60)
    }

    private func showBattleResult(type: VRBattleResultType) {
        var imageName = ""
        switch type {
            case .draw:
                imageName = "live_battle_result_draw_icon"
            case .victory:
                imageName = "live_battle_result_win_icon"
            case .defeat:
                imageName = "live_battle_result_lose_icon"
        }
        
        battleResultImageView.isHidden = false
        battleResultImageView.image = internalImage(imageName)
    }
    
    private func stopDisplayBattleResult() {
        isBattleStarted = false
        isHidden = true
        battleResultImageView.isHidden = true
    }

    private func updateBattleScore(battleScore: [String: UInt]) {
        if battleScore.count == 0 { return }
        
        let battleUsers = battleStore.state.value.battleUsers
        guard battleUsers.count == 2 else { return }
        
        let currentLiveID = liveListStore.state.value.currentLive.liveID
        guard let leftUser = battleUsers.first(where: { $0.liveID == currentLiveID }),
              let rightUser = battleUsers.first(where: { $0.liveID != currentLiveID }) else { return }
        
        let leftScore = battleScore[leftUser.userID] ?? 0
        let rightScore = battleScore[rightUser.userID] ?? 0
        singleBattleScoreView.updateScores(leftScore: Int(leftScore), rightScore: Int(rightScore))
    }
}

extension BattleInfoView {
    var liveListStore: LiveListStore {
        return LiveListStore.shared
    }

    var coHostStore: CoHostStore {
        return CoHostStore.create(liveID: liveID)
    }

    var battleStore: BattleStore {
        return BattleStore.create(liveID: liveID)
    }
}

private extension String {
    static let battleEndText = internalLocalized("common_battle_pk_end")
    static let inPKText = internalLocalized("seat_in_pk")
}
