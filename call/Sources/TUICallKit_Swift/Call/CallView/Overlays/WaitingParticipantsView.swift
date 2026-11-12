import AtomicXCore
import Combine
import SnapKit
import UIKit

final class WaitingParticipantsView: UIView {

    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?

    private let avatarPlaceholder = UIView()
    private let namePlaceholder = UIView()
    private let kickerLabel = UILabel()
    private let othersTitleLabel = UILabel()
    private let othersStack = UIStackView()
    private let othersColumn = UIStackView()
    private var cancellables = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        subscribeParticipants()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func avatarSlotCenter(in target: UIView) -> CGPoint {
        avatarPlaceholder.superview?.convert(avatarPlaceholder.center, to: target) ?? center
    }

    private func setupViews() {
        [kickerLabel, othersTitleLabel].forEach {
            $0.font = .systemFont(ofSize: 13)
            $0.textColor = CallKitTheme.textOnDarkSecondary
        }
        kickerLabel.textAlignment = .center
        othersTitleLabel.text = CallKitResources.text("callkit.incoming.others_title")

        othersStack.spacing = 8
        othersStack.alignment = .center

        othersColumn.addArrangedSubview(othersTitleLabel)
        othersColumn.addArrangedSubview(othersStack)
        othersColumn.axis = .vertical
        othersColumn.spacing = 12
        othersColumn.alignment = .center
        othersColumn.isHidden = true

        let centerColumn = UIStackView(arrangedSubviews: [avatarPlaceholder, namePlaceholder, kickerLabel, othersColumn])
        centerColumn.axis = .vertical
        centerColumn.spacing = 12
        centerColumn.alignment = .center
        centerColumn.setCustomSpacing(14, after: kickerLabel)
        addSubview(centerColumn)
        centerColumn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().multipliedBy(0.84)
            make.leading.greaterThanOrEqualToSuperview().offset(28)
            make.trailing.lessThanOrEqualToSuperview().offset(-28)
        }
        avatarPlaceholder.snp.makeConstraints { make in
            make.size.equalTo(96)
        }
        namePlaceholder.snp.makeConstraints { make in
            make.height.equalTo(24)
            make.width.equalTo(1)
        }

        let isVideo = CallStore.shared.state.value.isVideoCall

        let rejectButton = UIButton(type: .custom)
        rejectButton.backgroundColor = CallKitTheme.callRed
        rejectButton.layer.cornerRadius = 30
        rejectButton.clipsToBounds = true
        let rejectIcon = UIImageView(image: CallKitResources.image(named: "callkit_icon_reject"))
        rejectIcon.contentMode = .scaleAspectFit
        rejectButton.addSubview(rejectIcon)
        rejectIcon.snp.makeConstraints { make in make.edges.equalToSuperview() }
        rejectButton.snp.makeConstraints { make in make.size.equalTo(60) }
        rejectButton.addAction(UIAction { [weak self] _ in self?.onReject?() }, for: .touchUpInside)

        let acceptButton = UIButton(type: .custom)
        acceptButton.backgroundColor = CallKitTheme.callGreen
        acceptButton.layer.cornerRadius = 30
        acceptButton.clipsToBounds = true
        let acceptIcon = UIImageView(image: isVideo
            ? CallKitResources.image(named: "callkit_icon_video_glyph")?.withRenderingMode(.alwaysTemplate)
            : CallKitResources.image(named: "callkit_icon_accept"))
        acceptIcon.contentMode = .scaleAspectFit
        acceptIcon.tintColor = .white
        acceptButton.addSubview(acceptIcon)
        acceptIcon.snp.makeConstraints { make in make.edges.equalToSuperview().inset(isVideo ? 18 : 0) }
        acceptButton.snp.makeConstraints { make in make.size.equalTo(60) }
        acceptButton.addAction(UIAction { [weak self] _ in self?.onAccept?() }, for: .touchUpInside)

        let rejectLabel = makeActionLabel(CallKitResources.text("callkit.incoming.reject"))
        let acceptLabel = makeActionLabel(CallKitResources.text("callkit.incoming.accept"))

        let rejectColumn = UIStackView(arrangedSubviews: [rejectButton, rejectLabel])
        rejectColumn.axis = .vertical
        rejectColumn.spacing = 8
        rejectColumn.alignment = .center
        let acceptColumn = UIStackView(arrangedSubviews: [acceptButton, acceptLabel])
        acceptColumn.axis = .vertical
        acceptColumn.spacing = 8
        acceptColumn.alignment = .center

        addSubview(rejectColumn)
        addSubview(acceptColumn)
        rejectColumn.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(-88)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-28)
        }
        acceptColumn.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(88)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-28)
        }
    }

    private func makeActionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.textColor = CallKitTheme.incomingActionText
        return label
    }

    private func subscribeParticipants() {
        CallStore.shared.state.subscribe(StatePublisherSelector(keyPath: \.allParticipants))
            .map { $0.map(\.id) }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    func reload() {
        let state = CallStore.shared.state.value
        let call = state.activeCall
        let inviterID = call.inviterId
        guard !inviterID.isEmpty else { return }
        let base = CallKitResources.text(call.mediaType == .video ? "callkit.incoming.video" : "callkit.incoming.audio")
        kickerLabel.text = CallKitConfig.shared.enableMuteMode
            ? base + CallKitResources.text("callkit.incoming.muted_suffix")
            : base

        let selfID = state.selfInfo.id
        let others = state.allParticipants.map(\.id).filter { $0 != selfID && $0 != inviterID }
        let isMulti = !call.chatGroupId.isEmpty || call.inviteeIds.count > 1
        let showOthers = isMulti && !others.isEmpty
        kickerLabel.isHidden = showOthers
        othersColumn.isHidden = !showOthers
        if showOthers {
            loadOthers(userIDs: others)
        }
    }

    private func loadOthers(userIDs: [String]) {
        othersStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let placeholder = CallKitResources.image(named: "callkit_default_avatar")
        for userID in userIDs {
            let imageView = UIImageView(image: placeholder)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 10

            let container = UIView()
            container.layer.shadowColor = UIColor.black.cgColor
            container.layer.shadowOffset = CGSize(width: 0, height: 2)
            container.layer.shadowRadius = 5
            container.layer.shadowOpacity = 0.35
            container.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            container.snp.makeConstraints { make in
                make.size.equalTo(36)
            }
            othersStack.addArrangedSubview(container)
        }
        CallKitContactLoader.load(userIDs: userIDs) { [weak self] userID, _, image in
            guard let self, let image else { return }
            guard let index = userIDs.firstIndex(of: userID),
                  index < self.othersStack.arrangedSubviews.count,
                  let imageView = self.othersStack.arrangedSubviews[index].subviews.first as? UIImageView else { return }
            imageView.image = image
        }
    }
}
