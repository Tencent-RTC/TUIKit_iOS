//
//  WaitingParticipantsView.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import Foundation
import AtomicXCore
import Combine
import SnapKit

private let kItemWidth = 32.scale375Width()
private let kSpacing = 5.scale375Width()

class WaitingParticipantsView: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        subscribeCallListState()
        initUI()
        updateDescribeLabel()
        updateCallerInfo()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Private
    private let callerHeadImageView: UIImageView = {
        let participantHeadImageView = UIImageView(frame: CGRect.zero)
        participantHeadImageView.layer.masksToBounds = true
        participantHeadImageView.layer.cornerRadius = 6.0
        participantHeadImageView.image = CallKitBundle.getBundleImage(name: "default_participant_icon")
        return participantHeadImageView
    }()
    private let callerNameLabel: UILabel = {
        let participantNameLabel = UILabel(frame: CGRect.zero)
        participantNameLabel.textColor = UIColor(hex: "#D5E0F2")
        participantNameLabel.font = UIFont.boldSystemFont(ofSize: 18.0)
        participantNameLabel.backgroundColor = UIColor.clear
        participantNameLabel.textAlignment = .center
        participantNameLabel.text = ""
        return participantNameLabel
    }()

    private let describeLabel: UILabel = {
        let describeLabel = UILabel()
        describeLabel.font = UIFont.systemFont(ofSize: 12.0)
        describeLabel.textColor = UIColor(hex: "#D5E0F2")
        describeLabel.textAlignment = .center
        describeLabel.isUserInteractionEnabled = false
        describeLabel.text = CallKitLocalization.localized("calleeTip")
        return describeLabel
    }()
    private lazy var calleeCollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let calleeCollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        calleeCollectionView.delegate = self
        calleeCollectionView.dataSource = self
        calleeCollectionView.showsVerticalScrollIndicator = false
        calleeCollectionView.showsHorizontalScrollIndicator = false
        calleeCollectionView.backgroundColor = UIColor.clear
        return calleeCollectionView
    }()
    private let dataSource = CurrentValueSubject<[CallParticipantInfo], Never>([])
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: UI Specification Processing
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        isViewReady = true
    }
}

// MARK: Layout
extension WaitingParticipantsView {
    func constructViewHierarchy() {
        addSubview(describeLabel)
        addSubview(calleeCollectionView)
        addSubview(callerHeadImageView)
        addSubview(callerNameLabel)
    }
    
    func activateConstraints() {
        describeLabel.snp.makeConstraints { make in
            make.bottom.equalTo(calleeCollectionView.snp.top).offset(-5.scale375Width())
            make.centerX.equalToSuperview()
            make.width.equalTo(CallConstants.screenWidth)
            make.height.equalTo(20)
        }

        calleeCollectionView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(CallConstants.screenWidth)
            make.height.equalTo(40)
        }

        callerNameLabel.snp.makeConstraints { make in
            make.bottom.equalTo(describeLabel.snp.top).offset(-20.scale375Height())
            make.centerX.equalToSuperview()
            make.height.equalTo(30)
            make.width.lessThanOrEqualToSuperview().multipliedBy(0.8)
        }

        callerHeadImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(callerNameLabel.snp.top).offset(-10.scale375Height())
            make.width.equalTo(100.scale375Width())
            make.height.equalTo(100.scale375Width())
        }
    }
    
    func updateDescribeLabel() {
        let count = dataSource.value.count
        if count >= 1 {
            describeLabel.isHidden = false
        } else {
            describeLabel.isHidden = true
        }
    }
    
    func initUI() {
        let inviterId = CallStore.shared.state.value.activeCall.inviterId
        let selfId = CallStore.shared.state.value.selfInfo.id
        let dataList = CallStore.shared.state.value.allParticipants.filter { $0.id != inviterId && $0.id != selfId }
        dataSource.send(dataList)
    }

    func updateCallerInfo() {
        let inviterId = CallStore.shared.state.value.activeCall.inviterId
        if let caller = CallStore.shared.state.value.allParticipants.first(where: { $0.id == inviterId }) {
            callerHeadImageView.sd_setImage(with: URL(string: caller.avatarURL), placeholderImage: CallKitBundle.getBundleImage(name: "default_participant_icon"))
            callerNameLabel.text = caller.name
        } else {
            callerHeadImageView.image = CallKitBundle.getBundleImage(name: "default_participant_icon")
            callerNameLabel.text = ""
        }
    }
}

// MARK: Action
extension WaitingParticipantsView {
    func bindInteraction() {
        calleeCollectionView.register(WaitingParticipantsViewCell.self, forCellWithReuseIdentifier: "WaitingParticipantsViewCell")
        dataSource
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.calleeCollectionView.reloadData()
                self.calleeCollectionView.layoutIfNeeded()
            }
            .store(in: &cancellables)
    }
}

// MARK: Subscribe
extension WaitingParticipantsView {
    func subscribeCallListState() {
        CallStore.shared.state.subscribe(StatePublisherSelector(keyPath: \.allParticipants))
            .map { participantList in
                let inviterId = CallStore.shared.state.value.activeCall.inviterId
                let selfId = CallStore.shared.state.value.selfInfo.id
                return participantList.filter { $0.id != inviterId && $0.id != selfId }
            }
            .removeDuplicates { oldList, newList in
                let oldIds = oldList.map { $0.id }
                let newIds = newList.map { $0.id }
                return oldIds == newIds
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] filteredParticipants in
                guard let self = self else { return }
                self.dataSource.send(filteredParticipants)
                self.updateDescribeLabel()
                self.updateCallerInfo()
            }
            .store(in: &cancellables)
    }
}

// MARK: UICollectionViewDataSource
extension WaitingParticipantsView {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.value.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WaitingParticipantsViewCell", for: indexPath) as! WaitingParticipantsViewCell
        cell.initCell(participant: dataSource.value[indexPath.row])
        return cell
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension WaitingParticipantsView {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: kItemWidth, height: kItemWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return kSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return kSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let cellCount = collectionView.numberOfItems(inSection: section)
        var inset = (collectionView.bounds.size.width - (CGFloat(cellCount) * kItemWidth) - (CGFloat(cellCount - 1) * kSpacing)) * 0.5
        inset = max(inset, 0.0)
        return UIEdgeInsets(top: 0.0, left: inset, bottom: 0.0, right: 0.0)
    }
}
