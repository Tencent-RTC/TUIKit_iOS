import UIKit
import SnapKit
import Combine
import AtomicXCore

final class CaptionButton: UIControl, MeetingToolBarPopupItem {

    weak var routerContext: RouterContext?
    var showsTitle = false {
        didSet {
            guard oldValue != showsTitle else { return }
            applyTitleVisibility()
        }
    }
    var onRequestDismiss: (() -> Void)?

    private let roomID: String
    private let container = UIStackView()
    private let iconBox = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private var storeCancellables = Set<AnyCancellable>()
    private var isRunning = false
    private var actionPopup: RoomPopup?
    private var transcriptPopup: RoomPopup?

    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        subscribe()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let box = showsTitle ? Self.menuIconBoxSize : Self.buttonSize
        return CGSize(
            width: box,
            height: showsTitle ? box + Self.titleSpacing + titleLabel.intrinsicContentSize.height : box
        )
    }

    func prepareForReuse() {
        storeCancellables.removeAll()
        actionPopup?.dismiss()
        transcriptPopup?.dismiss()
    }

    func showTranscript(in host: UIView? = nil) {
        transcriptPopup?.dismiss()
        let content = TranscriptListView(roomID: roomID)
        let popup = RoomPopup()
        popup.onDismiss = { [weak popup] _ in
            popup?.removeFromSuperview()
        }
        popup.contentView.addSubview(content)
        content.snp.makeConstraints { $0.edges.equalToSuperview() }
        transcriptPopup = popup
        popup.show(in: host ?? self)
        content.snp.makeConstraints { $0.height.equalTo(UIScreen.main.bounds.height * 0.84) }
    }

    func stopTranscription() {
        AITranscriberStore.create(roomID: roomID).stopTranscription { result in
            if case .failure(let error) = result {
                ErrorLocalized.showError(code: error.code, message: error.message)
            }
        }
    }

    private func setupViews() {
        iconBox.addSubview(iconView)
        container.addArrangedSubview(iconBox)
        container.addArrangedSubview(titleLabel)
        addSubview(container)
        addTarget(self, action: #selector(handleClick), for: .touchUpInside)
    }

    private func setupConstraints() {
        container.snp.makeConstraints { $0.edges.equalToSuperview() }
        iconBox.snp.makeConstraints { $0.size.equalTo(Self.buttonSize) }
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(Self.iconSize)
        }
    }

    private func setupStyles() {
        iconBox.layer.cornerRadius = Self.buttonSize / 2
        iconBox.backgroundColor = .roomKitBgHover
        container.axis = .vertical
        container.alignment = .center
        container.spacing = Self.titleSpacing
        container.isUserInteractionEnabled = false
        iconView.contentMode = .scaleAspectFit
        titleLabel.text = RoomKitResources.localizedString("roomkit_caption_entry")
        titleLabel.font = .systemFont(ofSize: 11)
        titleLabel.textAlignment = .center
        titleLabel.isHidden = !showsTitle
        accessibilityLabel = titleLabel.text
        updateRunningState()
    }

    private func setupBindings() {
    }

    private func subscribe() {
        AITranscriberStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(keyPath: \TranscriberState.isTranscriptionRunning))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                self?.isRunning = running
                self?.updateRunningState()
            }
            .store(in: &storeCancellables)
    }

    private func applyTitleVisibility() {
        titleLabel.isHidden = !showsTitle
        let box = showsTitle ? Self.menuIconBoxSize : Self.buttonSize
        iconBox.snp.remakeConstraints { $0.size.equalTo(box) }
        iconBox.layer.cornerRadius = box / 2
        iconView.snp.remakeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(showsTitle ? Self.menuIconSize : Self.iconSize)
        }
        invalidateIntrinsicContentSize()
    }

    private func updateRunningState() {
        iconView.image = RoomKitResources.image(named: "roomkit_icon_caption")?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = isRunning ? .roomKitAccent : .roomKitFgPrimary
        titleLabel.textColor = isRunning ? .roomKitAccent : .roomKitFgSecondary
        if !isRunning { actionPopup?.dismiss() }
    }

    private func startTranscription() {
        let store = AITranscriberStore.create(roomID: roomID)
        let config = store.state.value.transcriptionConfig
        store.startTranscription(myLanguage: store.state.value.selfLanguage, config: config) { result in
            if case .failure(let error) = result {
                ErrorLocalized.showError(code: error.code, message: error.message)
            }
        }
    }

    private func showActions() {
        onRequestDismiss?()
        actionPopup?.dismiss()
        let popup = RoomPopup()
        popup.panelBackgroundColor = .clear
        popup.panelBorderWidth = 0
        popup.showsHandleBar = false
        let content = makeActionContent()
        popup.onDismiss = { [weak popup, self] _ in
            self.actionPopup = nil
            popup?.removeFromSuperview()
        }
        popup.contentView.addSubview(content)
        content.snp.makeConstraints { $0.edges.equalToSuperview() }
        actionPopup = popup
        popup.show(in: self)
    }

    private func makeActionContent() -> UIView {
        let viewFull = makeActionButton(
            title: RoomKitResources.localizedString("roomkit_caption_view_full"),
            color: .roomKitFgPrimary,
            action: #selector(openFullTranscript)
        )
        let close = makeActionButton(
            title: RoomKitResources.localizedString("roomkit_caption_close"),
            color: .roomKitDanger,
            action: #selector(closeLiveCaptions)
        )
        let divider = UIView()
        divider.backgroundColor = .roomKitBorder
        divider.snp.makeConstraints { $0.height.equalTo(1) }
        let group = UIStackView(arrangedSubviews: [viewFull, divider, close])
        group.axis = .vertical
        group.backgroundColor = .roomKitBgSurface
        group.layer.cornerRadius = 16
        group.clipsToBounds = true

        let cancel = makeActionButton(
            title: RoomKitResources.localizedString("roomkit.common.cancel"),
            color: .roomKitFgPrimary,
            action: #selector(dismissActions)
        )
        cancel.backgroundColor = .roomKitBgSurface
        cancel.layer.cornerRadius = 16

        let root = UIStackView(arrangedSubviews: [group, cancel])
        root.axis = .vertical
        root.spacing = 6
        root.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        root.isLayoutMarginsRelativeArrangement = true
        return root
    }

    private func makeActionButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.snp.makeConstraints { $0.height.equalTo(52) }
        return button
    }

    @objc private func handleClick() {
        onRequestDismiss?()
        isRunning ? showActions() : startTranscription()
    }

    @objc private func openFullTranscript() {
        showTranscript(in: actionPopup)
        actionPopup?.dismiss()
    }

    @objc private func closeLiveCaptions() {
        actionPopup?.dismiss()
        stopTranscription()
    }

    @objc private func dismissActions() {
        actionPopup?.dismiss()
    }
}

private extension CaptionButton {
    static let buttonSize: CGFloat = 44
    static let iconSize: CGFloat = 20
    static let menuIconBoxSize: CGFloat = 46
    static let menuIconSize: CGFloat = 21
    static let titleSpacing: CGFloat = 7
}
