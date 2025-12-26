//
//  JoinCallView.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import UIKit
import TUICore
import RTCRoomEngine
import AtomicXCore

let kJoinGroupCallViewDefaultHeight: CGFloat = 52.0
let kJoinGroupCallViewExpandHeight: CGFloat = 225.0
let kJoinGroupCallItemWidth: CGFloat = 50.0
let kJoinGroupCallSpacing: CGFloat = 12.0

protocol JoinCallViewDelegate: AnyObject {
    func updatePageContent(isExpand: Bool)
    func joinCall()
}

class JoinCallView: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    weak var delegate: JoinCallViewDelegate?
    private var participants: [CallParticipantInfo] = []
    
    let bottomContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = TUICoreDefineConvert.getTUICallKitDynamicColor(colorKey: "callkit_join_group_bottom_container_bg_color",
                                                                              defaultHex: "#FFFFFF")
        view.layer.cornerRadius = 6.0
        view.layer.masksToBounds = true
        return view
    }()
    
    let titleIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = CallKitBundle.getBundleImage(name: "icon_join_group")
        return imageView
    }()
    
    let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 12.0)
        label.textColor = TUICoreDefineConvert.getTUICallKitDynamicColor(colorKey: "callkit_join_group_title_color", defaultHex: "#999999")
        label.textAlignment = .left
        return label
    }()
    
    let expandButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(CallKitBundle.getBundleImage(name: "icon_join_group_expand"), for: .normal)
        button.setImage(CallKitBundle.getBundleImage(name: "icon_join_group_zoom"), for: .selected)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    let expandView: UIView = {
        let view = UIView()
        view.backgroundColor = TUICoreDefineConvert.getTUICallKitDynamicColor(colorKey: "callkit_join_group_expand_bg_color", defaultHex: "#EEF0F2")
        view.isHidden = true
        view.layer.cornerRadius = 6.0
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        return collectionView
    }()
    
    let lineView: UIView = {
        let view = UIView()
        view.alpha = 0.1
        view.backgroundColor = TUICoreDefineConvert.getTUICallKitDynamicColor(colorKey: "callkit_join_group_line_color", defaultHex: "#707070")
        return view
    }()
    
    let joinButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont(name: "PingFangSC-Semibold", size: 14.0)
        button.setTitleColor(TUICoreDefineConvert.getTUICallKitDynamicColor(colorKey: "callkit_join_group_button_color", defaultHex: "#333333"),
                             for: .normal)
        button.setTitle(TUICallKitLocalize(key: "TUICallKit.JoinGroupView.join"), for: .normal)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = TUICoreDefineConvert.getTUICallKitDynamicColor(colorKey: "callkit_join_group_bg_color", defaultHex: "#ECF0F5")
        self.frame = CGRect(x: 0, y: 0, width: Screen_Width, height: kJoinGroupCallViewDefaultHeight)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if isViewReady { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        isViewReady = true
    }
    
    private func constructViewHierarchy() {
        addSubview(bottomContainerView)
        bottomContainerView.addSubview(titleIcon)
        bottomContainerView.addSubview(titleLabel)
        bottomContainerView.addSubview(expandButton)
        bottomContainerView.addSubview(expandView)
        expandView.addSubview(collectionView)
        expandView.addSubview(lineView)
        expandView.addSubview(joinButton)
    }
    
    func activateConstraints() {
        bottomContainerView.translatesAutoresizingMaskIntoConstraints = false
        titleIcon.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        expandView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        lineView.translatesAutoresizingMaskIntoConstraints = false
        joinButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            bottomContainerView.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            bottomContainerView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            bottomContainerView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            bottomContainerView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8)
        ])

        NSLayoutConstraint.activate([
            titleIcon.topAnchor.constraint(equalTo: bottomContainerView.topAnchor, constant: 8),
            titleIcon.leadingAnchor.constraint(equalTo: bottomContainerView.leadingAnchor, constant: 16),
            titleIcon.widthAnchor.constraint(equalToConstant: 20),
            titleIcon.heightAnchor.constraint(equalToConstant: 20)
        ])

        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: titleIcon.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleIcon.trailingAnchor, constant: 10),
        ])

        NSLayoutConstraint.activate([
            expandButton.centerYAnchor.constraint(equalTo: titleIcon.centerYAnchor),
            expandButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10),
            expandButton.trailingAnchor.constraint(equalTo: bottomContainerView.trailingAnchor, constant: -16),
            expandButton.widthAnchor.constraint(equalToConstant: 30),
            expandButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        NSLayoutConstraint.activate([
            expandView.topAnchor.constraint(equalTo: bottomContainerView.topAnchor, constant: 36),
            expandView.leadingAnchor.constraint(equalTo: bottomContainerView.leadingAnchor, constant: 16),
            expandView.trailingAnchor.constraint(equalTo: bottomContainerView.trailingAnchor, constant: -16),
            expandView.heightAnchor.constraint(equalToConstant: 157)
        ])

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: expandView.topAnchor, constant: 37),
            collectionView.leadingAnchor.constraint(equalTo: expandView.leadingAnchor, constant: 10),
            collectionView.trailingAnchor.constraint(equalTo: expandView.trailingAnchor, constant: -10),
            collectionView.heightAnchor.constraint(equalToConstant: kJoinGroupCallItemWidth)
        ])

        NSLayoutConstraint.activate([
            lineView.topAnchor.constraint(equalTo: expandView.topAnchor, constant: 117),
            lineView.leadingAnchor.constraint(equalTo: expandView.leadingAnchor),
            lineView.trailingAnchor.constraint(equalTo: expandView.trailingAnchor),
            lineView.heightAnchor.constraint(equalToConstant: 1)
        ])

        NSLayoutConstraint.activate([
            joinButton.topAnchor.constraint(equalTo: lineView.bottomAnchor),
            joinButton.leadingAnchor.constraint(equalTo: expandView.leadingAnchor),
            joinButton.trailingAnchor.constraint(equalTo: expandView.trailingAnchor),
            joinButton.bottomAnchor.constraint(equalTo: expandView.bottomAnchor)
        ])
    }
    
    func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(expandButtonClick(sender:)))
        bottomContainerView.addGestureRecognizer(tap)
        
        expandButton.addTarget(self, action: #selector(expandButtonClick(sender:)), for: .touchUpInside)
        joinButton.addTarget(self, action: #selector(joinButtonClick(sender:)), for: .touchUpInside)
        
        collectionView.register(JoinCallUserCell.self, forCellWithReuseIdentifier: String(describing: JoinCallUserCell.self))
    }
    
    @objc func expandButtonClick(sender: UIControl) {
        expandView.isHidden = expandButton.isSelected
        expandButton.isSelected = !expandButton.isSelected
        delegate?.updatePageContent(isExpand: expandButton.isSelected)
    }
    
    @objc func joinButtonClick(sender: UIButton) {
        expandButton.isSelected = false
        delegate?.joinCall()
    }
    
    func updateView(with participants: [CallParticipantInfo], callMediaType: CallMediaType?) {
        self.participants = participants.filter { $0.id != TUILogin.getUserID() }
        
        titleLabel.isHidden = self.participants.isEmpty
        titleLabel.text = String(format: TUICallKitLocalize(key: "TUICallKit.JoinGroupView.title") ?? "", self.participants.count)
        titleLabel.textAlignment = TUICoreDefineConvert.getIsRTL() ? .right : .left
        collectionView.reloadData()
    }
}

// MARK: UICollectionViewDataSource
extension JoinCallView {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return participants.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: JoinCallUserCell.self),
                                                      for: indexPath) as! JoinCallUserCell
        let participant = participants[indexPath.item]
        cell.setModel(participant: participant)
        return cell
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension JoinCallView {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: kJoinGroupCallItemWidth, height: kJoinGroupCallItemWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return kJoinGroupCallSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        guard participants.count > 0 else {
            return .zero
        }
        
        let totalCellWidth = kJoinGroupCallItemWidth * CGFloat(participants.count)
        let totalSpacingWidth = kJoinGroupCallSpacing * CGFloat(participants.count - 1)
        let totalContentWidth = totalCellWidth + totalSpacingWidth
        
        let collectionViewWidth = collectionView.bounds.width
        
        if totalContentWidth < collectionViewWidth {
            let inset = (collectionViewWidth - totalContentWidth) / 2
            return UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        }
        
        return .zero
    }
}
