//
//  BattleMemberInfoView.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/9/4.
//

import AtomicXCore
import Combine
import RTCCommon
import UIKit

class AnchorBattleMemberInfoView: RTCBaseView {
    private let store: AnchorStore
    private var userId: String
    private var cancellableSet: Set<AnyCancellable> = []
    
    private let maxRankingValue = 9
    
    init(store: AnchorStore, userId: String) {
        self.store = store
        self.userId = userId
        super.init(frame: .zero)
    }
    
    private let scoreView: UIView = {
        let view = UIView()
        view.backgroundColor = .g2.withAlphaComponent(0.4)
        view.layer.cornerRadius = 12.scale375Height()
        return view
    }()
    
    private let rankImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = internalImage("live_battle_ranking_\(1)_icon")
        return imageView
    }()
    
    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .customFont(ofSize: 12, weight: .bold)
        label.textAlignment = .left
        label.text = "0"
        return label
    }()
    
    private let connectionView: UIView = {
        let view = UIView()
        view.backgroundColor = .g2.withAlphaComponent(0.4)
        view.layer.cornerRadius = 10.scale375Height()
        return view
    }()
    
    private let connectionStatusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .customFont(ofSize: 12)
        label.textAlignment = .center
        label.text = .connectingText
        label.sizeToFit()
        return label
    }()
    
    override func constructViewHierarchy() {
        addSubview(scoreView)
        addSubview(connectionView)
        scoreView.addSubview(rankImageView)
        scoreView.addSubview(scoreLabel)
        connectionView.addSubview(connectionStatusLabel)
    }
    
    override func activateConstraints() {
        scoreView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8.scale375Height())
            make.leading.equalToSuperview().offset(8.scale375())
            make.height.equalTo(24.scale375Height())
            make.width.equalTo(65.scale375())
        }
        rankImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(4.scale375())
            make.width.height.equalTo(16.scale375())
        }
        scoreLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(rankImageView.snp.trailing).offset(2.scale375())
            make.height.equalTo(14.scale375Height())
        }
       
        connectionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10.scale375Height())
            make.leading.equalToSuperview().offset(8.scale375())
            make.trailing.lessThanOrEqualToSuperview().offset(-8.scale375())
        }

        connectionStatusLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8.scale375())
            make.top.bottom.equalToSuperview().inset(4.scale375Height())
        }
    }
    
    override func bindInteraction() {
        subscribeBattleState()
        
        FloatWindow.shared.subscribeShowingState()
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isShow in
                guard let self = self else { return }
                isHidden = isShow
            }
            .store(in: &cancellableSet)
    }
    
    override var isHidden: Bool {
        didSet {
            if !isHidden && FloatWindow.shared.isShowingFloatWindow() {
                isHidden = true
            }
        }
    }
    
    private func subscribeBattleState() {
        store.battleStore.battleEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onBattleEnded(battleInfo: _, reason: _):
                    onBattleEnd()
                    DispatchQueue.main.asyncAfter(deadline: .now() + anchorBattleEndInfoDuration) { [weak self] in
                        guard let self = self else { return }
                        reset()
                    }
                default: break
                }
            }
            .store(in: &cancellableSet)
        
        store.subscribeState(StatePublisherSelector(keyPath: \BattleState.battleUsers))
            .removeDuplicates()
            .combineLatest(store.subscribeState(StatePublisherSelector(keyPath: \BattleState.battleScore)).removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] battleUsers, battleScore in
                guard let self = self else { return }
                onBattleScoreChanged(battleUsers: battleUsers, score: battleScore)
            }
            .store(in: &cancellableSet)
    }
    
    private func onBattleScoreChanged(battleUsers: [SeatUserInfo], score: [String: UInt]) {
        guard store.coHostState.connected.count > 2 else {
            reset()
            return
        }
        setData(user: battleUsers.filter { $0.userID == userId }.first, scoreMap: score)
    }
    
    private func onBattleResultDisplay(display: Bool) {
        if !display {
            reset()
        }
    }
    
    private func setData(user: SeatUserInfo?, scoreMap: [String: UInt]) {
        isHidden = false
        if let user = user {
            showBattleView(show: true)
            scoreLabel.text = "\(scoreMap[user.userID] ?? 0)"
            let ranking = getRankingFromMap(user: user, scoreMap: scoreMap)
            if ranking > 0, ranking <= maxRankingValue {
                rankImageView.image = internalImage("live_battle_ranking_\(ranking)_icon")
            }
        } else {
            showBattleView(show: false)
        }
    }
    
    private func getRankingFromMap(user: SeatUserInfo, scoreMap: [String: UInt]) -> Int {
        struct TmpUser {
            let userID: String
            let score: UInt
        }
        var list: [TmpUser] = []
        scoreMap.forEach { list.append(TmpUser(userID: $0.key, score: $0.value)) }
        list.sort { lhs, rhs in
            lhs.score > rhs.score
        }
        var rankMap: [String: Int] = [:]
        for (index, tmpUser) in list.enumerated() {
            let rank: Int
            if index > 0 && tmpUser.score == list[index - 1].score {
                // 当前分数和前一个相同，排名与前一个一致
                rank = rankMap[list[index - 1].userID] ?? index
            } else {
                // 分数不同，排名为当前索引+1
                rank = index + 1
            }
            rankMap[tmpUser.userID] = rank
        }
        return rankMap[user.userID] ?? 0
    }

    private func reset() {
        isHidden = true
        scoreView.isHidden = true
        connectionView.isHidden = true
    }
    
    private func showBattleView(show: Bool) {
        isHidden = false
        scoreView.isHidden = !show
        connectionView.isHidden = show
    }
    
    private func onBattleEnd() {
        onBattleScoreChanged(battleUsers: store.battleState.battleUsers, score: store.battleState.battleScore)
    }
}

private extension String {
    static let connectingText = internalLocalized("Connecting")
}
