//
//  LinkMicAnchorFloatView.swift
//  TUILiveKit
//
//  Created by krabyu on 2023/11/4.
//

import AtomicXCore
import Combine
import RTCCommon
import SnapKit
import UIKit
import AtomicX

class AnchorUserImageCell: UICollectionViewCell {
    var user: LiveUserInfo? {
        didSet {
            avatarView.setContent(.url(user?.avatarURL ?? "", placeholder: UIImage.avatarPlaceholderImage))
        }
    }

    lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("",placeholder: UIImage.avatarPlaceholderImage),
            size: .m,
            shape: .round
        )
        contentView.addSubview(avatar)
        return avatar
    }()

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        isViewReady = true
        contentView.backgroundColor = .clear
        avatarView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setImage(image: UIImage?) {
        avatarView.setContent(.icon(image: image ?? UIImage.placeholderImage))
    }
}

class LinkMicAnchorFloatView: UIView {
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private var cancellableSet = Set<AnyCancellable>()

    private var applyList: [LiveUserInfo] = []
    lazy var tipsLabel: UILabel = {
        let label = UILabel()
        label.textColor = .flowKitWhite
        label.font = .customFont(ofSize: 14)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 40.scale375(), height: 40.scale375())
        layout.minimumLineSpacing = -16.scale375()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.isUserInteractionEnabled = true
        collectionView.contentMode = .scaleToFill
        collectionView.dataSource = self
        collectionView.register(AnchorUserImageCell.self, forCellWithReuseIdentifier: AnchorUserImageCell.cellReuseIdentifier)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        collectionView.addGestureRecognizer(tap)
        return collectionView
    }()

    init(store: AnchorStore, routerManager: AnchorRouterManager) {
        self.store = store
        self.routerManager = routerManager
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        subscribeSeatState()
        isViewReady = true
    }

    private func subscribeSeatState() {
        store.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.applicants))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] applyList in
                guard let self = self else { return }
                self.applyList = applyList
                self.tipsLabel.text = .localizedReplace(.applyLinkMicCount, replace: String(applyList.count))
                self.updateView()
            }
            .store(in: &cancellableSet)
    }

    private func updateView() {
        collectionView.reloadData()
        collectionView.snp.updateConstraints { make in
            switch applyList.count {
            case 1:
                make.width.equalTo(40.scale375())
            case 2:
                make.width.equalTo(64.scale375())
            default:
                make.width.equalTo(88.scale375())
            }
        }
    }
}

// MARK: Layout

extension LinkMicAnchorFloatView {
    func constructViewHierarchy() {
        backgroundColor = .g2
        layer.cornerRadius = 10
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor.flowKitWhite.withAlphaComponent(0.2).cgColor

        addSubview(tipsLabel)
        addSubview(collectionView)
    }

    func activateConstraints() {
        collectionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18.scale375Width())
            make.centerX.equalToSuperview()
            make.height.equalTo(40.scale375())
            make.width.equalTo(56.scale375())
        }

        tipsLabel.snp.makeConstraints { make in
            make.top.equalTo(collectionView.snp.bottom).offset(6.scale375Width())
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(20.scale375())
        }
    }
}

// MARK: - UICollectionViewDataSource

extension LinkMicAnchorFloatView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(applyList.count, 3)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AnchorUserImageCell.cellReuseIdentifier, for: indexPath)
        if let cell = cell as? AnchorUserImageCell {
            if indexPath.row < 2 {
                cell.user = applyList[indexPath.row]
            } else {
                let user = LiveUserInfo()
                cell.user = user
                cell.setImage(image: internalImage("live_more_audience_icon"))
            }
        }
        return cell
    }
}

// MARK: Action

extension LinkMicAnchorFloatView {
    @objc func tapAction() {
        routerManager.router(action: .present(.liveLinkControl))
    }
}

private extension String {
    static var applyLinkMicCount: String {
        internalLocalized("common_seat_application_title")
    }
}
