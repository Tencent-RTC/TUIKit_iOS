//
//  LinkMicAudienceFloatView.swift
//  TUILiveKit
//
//  Created by krabyu on 2023/11/2.
//

import AtomicXCore
import Combine
import RTCCommon
import TUICore
import AtomicX

class AudienceUserImageCell: UICollectionViewCell {
    var user: UserProfile? {
        didSet {
            avatarView.setContent(.url(user?.avatarURL ?? "", placeholder: UIImage.avatarPlaceholderImage))
        }
    }

    private lazy var avatarView: AtomicAvatar = {
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

class LinkMicAudienceFloatView: UIView {
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager

    private var cancellableSet = Set<AnyCancellable>()

    private var dotsTimer: Timer = .init()
    private var isViewReady: Bool = false
    init(manager: AudienceStore, routerManager: AudienceRouterManager) {
        self.manager = manager
        self.routerManager = routerManager
        super.init(frame: .zero)
        updateLabelText()
        subscribeViewState()
    }

    private lazy var audienceStore: LiveAudienceStore = .create(liveID: manager.liveID)

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func subscribeViewState() {
        manager.subscribeState(StateSelector(keyPath: \AudienceState.isApplying))
            .receive(on: RunLoop.main)
            .sink { [weak self] isApplying in
                guard let self = self else { return }
                isHidden = !isApplying
            }
            .store(in: &cancellableSet)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        backgroundColor = .black
        constructViewHierarchy()
        activateConstraints()
        updateView()
        audienceStore.state.subscribe(StatePublisherSelector(keyPath: \LiveAudienceState.audienceList))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateView()
            }
            .store(in: &cancellableSet)
    }

    let tipsLabel: UILabel = {
        let label = UILabel()
        label.textColor = .flowKitWhite
        label.text = .localizedReplace(.toBePassedText, replace: "")
        label.font = .customFont(ofSize: 14)
        label.sizeToFit()
        label.adjustsFontSizeToFitWidth = true
        if TUIGlobalization.getRTLOption() {
            label.textAlignment = .right
        } else {
            label.textAlignment = .left
        }
        return label
    }()

    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 40.scale375(), height: 40.scale375())
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.isUserInteractionEnabled = true
        collectionView.contentMode = .scaleToFill
        collectionView.dataSource = self
        collectionView.register(AudienceUserImageCell.self, forCellWithReuseIdentifier: AudienceUserImageCell.cellReuseIdentifier)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        collectionView.addGestureRecognizer(tap)
        return collectionView
    }()

    private func updateView() {
        collectionView.reloadData()
    }

    private func updateLabelText() {
        var dots = ""
        dotsTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if dots.count == 3 {
                dots.removeAll()
            } else {
                dots.append(".")
            }
            self.tipsLabel.text? = .localizedReplace(.toBePassedText, replace: dots)
        }
        RunLoop.current.add(dotsTimer, forMode: .default)
    }

    deinit {
        dotsTimer.invalidate()
    }
}

// MARK: Layout

extension LinkMicAudienceFloatView {
    func constructViewHierarchy() {
        backgroundColor = .g2.withAlphaComponent(0.4)
        layer.cornerRadius = 10
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor.flowKitWhite.withAlphaComponent(0.2).cgColor

        addSubview(tipsLabel)
        addSubview(collectionView)
    }

    func activateConstraints() {
        collectionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14.scale375Width())
            make.height.width.equalTo(40.scale375())
            make.centerX.equalToSuperview()
        }

        tipsLabel.snp.makeConstraints { make in
            make.top.equalTo(collectionView.snp.bottom).offset(6.scale375Width())
            make.centerX.equalToSuperview()
            make.width.equalTo(55.scale375())
            make.height.equalTo(20.scale375())
        }
    }
}

// MARK: - UICollectionViewDataSource

extension LinkMicAudienceFloatView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AudienceUserImageCell.cellReuseIdentifier, for: indexPath)
        if let cell = cell as? AudienceUserImageCell {
            cell.user = manager.loginState.loginUserInfo
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension LinkMicAudienceFloatView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let width = collectionView.frame.width
        let margin = width * 0.3
        return UIEdgeInsets(top: 10, left: margin / 2, bottom: 10, right: margin / 2)
    }
}

// MARK: Action

extension LinkMicAudienceFloatView {
    @objc func tapAction() {
        showCancelLinkMicPanel()
    }

    private func showCancelLinkMicPanel() {
        let alertConfig = AlertViewConfig(
            items: [
                AlertButtonConfig(text: .cancelLinkMicRequestText, type: .red) { [weak self] _ in
                    guard let self = self else { return }
                    manager.stopApplying()
                    manager.coGuestStore.cancelApplication { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .failure(let err):
                            let error = InternalError(code: err.code, message: err.message)
                            manager.onError(error)
                        default: break
                        }
                    }
                    routerManager.router(action: .dismiss())
                },
                AlertButtonConfig(text: .cancelText, type: .grey) { [weak self] _ in
                    guard let self = self else { return }
                    routerManager.router(action: .dismiss())
                }
            ]
        )
        routerManager.present(view: AtomicAlertView(config: alertConfig), position: .bottom)
    }
}

private extension String {
    static var toBePassedText: String {
        internalLocalized("Waitingxxx")
    }

    static var cancelLinkMicRequestText = internalLocalized("common_text_cancel_link_mic_apply")

    static var cancelText = internalLocalized("common_cancel")
}
