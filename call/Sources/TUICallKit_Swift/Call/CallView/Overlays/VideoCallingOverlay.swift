import AtomicXCore
import SnapKit
import UIKit

final class VideoCallingOverlay: UIView {

    private let peerColumn = UIStackView()
    private let peerAvatarContainer = UIView()
    private let peerAvatarImageView = UIImageView()
    private let peerNameLabel = UILabel()
    private let callingLabel = UILabel()
    private let selfOffView = UIView()
    private let selfOffGradient = CallKitTheme.makeAudioGradient()
    private let selfOffBackdrop = UIImageView()
    private let selfAvatarRing = UIView()
    private let selfAvatarImageView = UIImageView()
    private var dotCount = 0
    private var dotTimer: Timer?
    private var reloadToken = 0
    private var backdropToken = 0

    override var isHidden: Bool {
        didSet { isHidden ? stopDots() : startDots() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    deinit {
        dotTimer?.invalidate()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        selfOffGradient.frame = selfOffView.bounds
    }

    func reload() {
        reloadToken += 1
        let token = reloadToken
        let state = CallStore.shared.state.value
        let selfID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let peerID = state.primaryPeerID ?? ""
        peerNameLabel.text = peerID
        if !peerID.isEmpty {
            CallKitContactLoader.load(userIDs: [peerID]) { [weak self] _, nickname, image in
                guard let self, self.reloadToken == token else { return }
                if let nickname, !nickname.isEmpty { self.peerNameLabel.text = nickname }
                if let image { self.peerAvatarImageView.image = image }
            }
        }
        if !selfID.isEmpty {
            CallKitContactLoader.load(userIDs: [selfID]) { [weak self] _, _, image in
                guard let self, self.reloadToken == token, let image else { return }
                self.selfAvatarImageView.image = image
                self.updateSelfOffBackdrop(image)
            }
        }
        startDots()
    }

    func setCameraOff(_ off: Bool) {
        selfOffView.isHidden = !off
        peerAvatarContainer.isHidden = off
        peerNameLabel.isHidden = off
    }

    private func setupViews() {
        peerAvatarContainer.layer.shadowColor = UIColor.black.cgColor
        peerAvatarContainer.layer.shadowOpacity = 0.32
        peerAvatarContainer.layer.shadowRadius = 15
        peerAvatarContainer.layer.shadowOffset = CGSize(width: 0, height: 10)
        peerAvatarContainer.snp.makeConstraints { make in
            make.size.equalTo(108)
        }

        peerAvatarImageView.contentMode = .scaleAspectFill
        peerAvatarImageView.clipsToBounds = true
        peerAvatarImageView.layer.cornerRadius = 22
        peerAvatarImageView.image = CallKitResources.image(named: "callkit_default_avatar")
        peerAvatarContainer.addSubview(peerAvatarImageView)
        peerAvatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        peerNameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        peerNameLabel.lineBreakMode = .byTruncatingTail
        callingLabel.font = .systemFont(ofSize: 15)
        [peerNameLabel, callingLabel].forEach {
            $0.textColor = .white
            $0.textAlignment = .center
            $0.shadowColor = UIColor.black.withAlphaComponent(0.45)
            $0.shadowOffset = CGSize(width: 0, height: 1)
        }

        peerColumn.addArrangedSubview(peerAvatarContainer)
        peerColumn.addArrangedSubview(peerNameLabel)
        peerColumn.axis = .vertical
        peerColumn.alignment = .center
        peerColumn.spacing = 12

        selfOffView.isHidden = true
        selfOffView.layer.insertSublayer(selfOffGradient, at: 0)

        selfOffBackdrop.contentMode = .scaleAspectFill
        selfOffBackdrop.clipsToBounds = true

        selfAvatarImageView.contentMode = .scaleAspectFill
        selfAvatarImageView.clipsToBounds = true
        selfAvatarImageView.layer.cornerRadius = 60
        selfAvatarImageView.image = CallKitResources.image(named: "callkit_default_avatar")

        selfAvatarRing.backgroundColor = UIColor.white.withAlphaComponent(0.04)
        selfAvatarRing.layer.cornerRadius = 70

        [selfOffBackdrop, selfAvatarRing].forEach { selfOffView.addSubview($0) }
        selfAvatarRing.addSubview(selfAvatarImageView)
        selfOffBackdrop.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        selfAvatarRing.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(140)
        }
        selfAvatarImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(120)
        }

        [selfOffView, peerColumn, callingLabel].forEach { addSubview($0) }

        selfOffView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        peerColumn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().multipliedBy(0.88)
            make.width.lessThanOrEqualToSuperview().offset(-56)
        }
        callingLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().multipliedBy(569.0 / 426.0)
        }
    }

    private func updateSelfOffBackdrop(_ image: UIImage) {
        backdropToken += 1
        let token = backdropToken
        let targetSize = bounds.isEmpty ? UIScreen.main.bounds.size : bounds.size
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let blurred = CallKitImageBlur.blurred(image, targetSize: targetSize)
            DispatchQueue.main.async {
                guard let self, self.backdropToken == token else { return }
                self.selfOffBackdrop.image = blurred ?? image
            }
        }
    }

    private func startDots() {
        guard dotTimer == nil else { return }
        dotCount = 0
        updateCallingText()
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.dotCount = (self.dotCount + 1) % 4
            self.updateCallingText()
        }
    }

    private func stopDots() {
        dotTimer?.invalidate()
        dotTimer = nil
    }

    private func updateCallingText() {
        callingLabel.text = CallKitResources.text("callkit.call.calling_video") + String(repeating: ".", count: dotCount)
    }
}
