//
//  BattleInfoView.swift
//  TUILiveKit
//
//  Created by krabyu /on 2024/9/4.
//

import AtomicXCore
import Combine
import RTCCommon
import RTCRoomEngine
import UIKit

public enum AnchorBattleResultType {
    case draw
    case victory
    case defeat
}

class AnchorBattleInfoView: RTCBaseView {
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private var cancellableSet: Set<AnyCancellable> = []
    private var timer: DispatchSourceTimer?

    init(store: AnchorStore, routerManager: AnchorRouterManager) {
        self.store = store
        self.routerManager = routerManager
        super.init(frame: .zero)
        backgroundColor = .clear
        self.isUserInteractionEnabled = false
    }
    
    private lazy var singleBattleScoreView: AnchorSingleBattleScoreView = {
        let view = AnchorSingleBattleScoreView()
        view.isHidden = true
        return view
    }()
    
    private let battleTimeView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = internalImage("live_battle_time_background_icon")
        imageView.isHidden = true
        return imageView
    }()
    
    private let startBattleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = internalImage("live_battle_start")
        imageView.isHidden = true
        return imageView
    }()
    
    private let battleResultImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    private lazy var battleClockButton: UIButton = {
        let button = UIButton()
        button.setImage(internalImage("live_battle_clock_icon"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.setTitle("0:00", for: .normal)
        return button
    }()
    
    private var isBattleStarted = false
    
    override func constructViewHierarchy() {
        addSubview(singleBattleScoreView)
        addSubview(battleTimeView)
        addSubview(startBattleImageView)
        addSubview(battleResultImageView)
        battleTimeView.addSubview(battleClockButton)
    }
    
    override func activateConstraints() {
        singleBattleScoreView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(18.scale375Height())
        }
        battleTimeView.snp.makeConstraints { make in
            make.top.equalTo(singleBattleScoreView.snp.bottom)
            make.centerX.equalToSuperview()
            make.width.equalTo(72.scale375())
            make.height.equalTo(22.scale375Height())
        }
        startBattleImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(240.scale375())
            make.height.equalTo(120.scale375Height())
        }
        battleResultImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(234.scale375())
        }
        battleClockButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(157.scale375())
            make.height.equalTo(156.scale375Height())
        }
    }
    
    override var isHidden: Bool {
        didSet {
            if !isHidden && FloatWindow.shared.isShowingFloatWindow() {
                isHidden = true
            }
        }
    }
    
    override func bindInteraction() {
        subscribeBattleState()
        
        FloatWindow.shared.subscribeShowingState()
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isShow in
                guard let self = self else { return }
                guard isBattleStarted else { return }
                isHidden = isShow
            }
            .store(in: &cancellableSet)
    }

    private func subscribeBattleState() {
        store.subscribeState(StatePublisherSelector(keyPath: \BattleState.currentBattleInfo))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] currentBattleInfo in
                guard let self = self else { return }
                if let battleInfo = currentBattleInfo {
                    store.updateBattleDurationCountDown(Int(battleInfo.config.duration + Double(battleInfo.startTime) - Date().timeIntervalSince1970))
                    startCountDown()
                    onBattleStart()
                }
            }
            .store(in: &cancellableSet)
        
        store.battleStore.battleEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onBattleEnded(battleInfo: _, reason: _):
                    onBattleEnd()
                    store.updateBattleDurationCountDown(0)
                    timer?.cancel()
                    timer = nil
                    onResultDisplay(display: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + audienceBattleEndInfoDuration) { [weak self] in
                        guard let self = self else { return }
                        onResultDisplay(display: false)
                    }
                default: break
                }
            }
            .store(in: &cancellableSet)
        
        store.subscribeState(StatePublisherSelector(keyPath: \BattleState.battleScore))
            .removeDuplicates()
            .combineLatest(store.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected)).removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] battleScore, battleUsers in
                guard let self = self else { return }
                onBattleScoreChanged(battleUsers: battleUsers, score: battleScore)
            }
            .store(in: &cancellableSet)
        
        store.subscribeState(StateSelector(keyPath: \AnchorBattleState.durationCountDown))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] duration in
                guard let self = self else { return }
                onDurationCountDown(duration: duration)
            }
            .store(in: &cancellableSet)
    }
    
    private func startCountDown() {
        if let timer = timer {
            timer.cancel()
        }
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer?.schedule(deadline: .now() + 1, repeating: 1)
        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let t = store.anchorBattleState.durationCountDown
            if t > 0 {
                store.updateBattleDurationCountDown(t - 1)
            } else {
                timer?.cancel()
                timer = nil
            }
        }
        timer?.resume()
    }
    
    private func onDurationCountDown(duration: Int) {
        updateTime(duration)
    }
    
    private func onResultDisplay(display: Bool) {
        if display {
            store.startShowBattleResult()
            showBattleResult(type: singleBattleScoreView.getResult())
        } else {
            store.stopShowBattleResult()
            stopDisplayBattleResult()
        }
    }
    
    private func onBattleScoreChanged(battleUsers: [SeatUserInfo], score: [String: UInt]) {
        guard battleUsers.count == 2 else { return }
        
        let currentLiveID = store.liveID
        guard let leftUser = battleUsers.filter({ $0.liveID == currentLiveID }).first,
              let rightUser = battleUsers.filter({ $0.liveID != currentLiveID }).first else { return }
        let leftScore = score[leftUser.userID] ?? 0
        let rightScore = score[rightUser.userID] ?? 0
        singleBattleScoreView.isHidden = false
        singleBattleScoreView.updateScores(leftScore: Int(leftScore), rightScore: Int(rightScore))
    }
    
    private func onBattleStart() {
        isBattleStarted = true
        isHidden = false
        battleTimeView.isHidden = false
        startBattleImageView.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.startBattleImageView.isHidden = true
        }
    }
    
    private func onBattleEnd() {
        isHidden = false
        battleClockButton.setTitle(.battleEndText, for: .normal)
    }
    
    private func updateTime(_ time: Int) {
        let title = time == 0 ? String.battleEndText : String(format: "%d:%02d", time / 60, time % 60)
        battleClockButton.setTitle(title, for: .normal)
    }
    
    private func showBattleResult(type: AnchorBattleResultType) {
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
}

private extension String {
    static let battleEndText = internalLocalized("PK End")
}
