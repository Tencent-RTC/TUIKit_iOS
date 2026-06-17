import AlbumPickerCore
import Combine
import UIKit

internal protocol WhatsAppBottomBarDelegate: AnyObject {
    func bottomBar(_ bar: WhatsAppBottomBar, didTapSendWithText textMessage: String?)
    func bottomBarDidTapPreview(_ bar: WhatsAppBottomBar)
    func bottomBarDidTapAddMore(_ bar: WhatsAppBottomBar)
    func bottomBar(
        _ bar: WhatsAppBottomBar,
        keyboardHeightChanged height: CGFloat,
        duration: TimeInterval
    )
}

internal class WhatsAppBottomBar: UIView {

    private static let barHeight: CGFloat = 56
    private static let inputHeight: CGFloat = 36
    private static let thumbnailSize: CGFloat = 36
    private static let thumbnailRotationAngle: CGFloat = -.pi / 18
    private static let sendButtonSize: CGFloat = 44
    private static let sendIconSize: CGFloat = 20
    private static let badgeSize: CGFloat = 22
    private static let badgeBorderWidth: CGFloat = 2
    private static let expandAnimationDuration: TimeInterval = 0.2

    internal weak var delegate: WhatsAppBottomBarDelegate?

    private let store: AlbumPickerStore
    private let isPreview: Bool
    private let theme = AlbumPickerCoreTheme.shared

    private var captionInput: UITextField!
    private var sendButton: UIView!
    private var badgeLabel: UILabel?
    private var thumbnailContainer: UIView?
    private var thumbnailFrontView: UIImageView?
    private var thumbnailBackView: UIImageView?
    private var inputRow: UIView!
    private var addMediaButton: UIButton?
    private var addMoreRow: WhatsAppBottomAddMoreRow?

    private var cancellable: AnyCancellable?
    private var isExpanded = false
    private var isAddMoreMode = false
    private var thumbnailWidthConstraint: Constraint?
    private var thumbnailHeightConstraint: Constraint?
    private var inputLeadingConstraint: Constraint?
    private var addButtonWidthConstraint: Constraint?
    private var addButtonLeadingMargin: CGFloat = 0
    private var thumbnailContainerSize: CGFloat = 0

    internal init(store: AlbumPickerStore, isPreview: Bool = false) {
        self.store = store
        self.isPreview = isPreview
        super.init(frame: .zero)
        thumbnailContainerSize = Self.thumbnailSize + AlbumPickerCoreTheme.spacing8
        setupViews()
        setupAddMoreRow()
        startObserving()
        observeKeyboard()
        prewarmKeyboard()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    internal func getTextMessage() -> String? {
        captionInput.text?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty == false ? captionInput.text : nil
    }

    internal func getTextMessageRaw() -> String? {
        captionInput.text
    }

    internal func setTextMessage(_ text: String?) {
        captionInput.text = text
    }

    internal func showSelectedThumbnails(_ medias: [AlbumMediaModel]) {
        guard !isPreview, !medias.isEmpty else { return }
        isAddMoreMode = true
        inputRow.isHidden = true
        addMoreRow?.show(medias: medias)
    }

    internal func hideSelectedThumbnails() {
        guard isAddMoreMode else { return }
        isAddMoreMode = false
        addMoreRow?.hide()
        inputRow.isHidden = false
    }
}

private extension WhatsAppBottomBar {
    func setupViews() {
        let bgColor = isPreview
            ? AlbumPickerCoreTheme.previewBackgroundColor
            : theme.backgroundColor
        backgroundColor = bgColor

        inputRow = createInputRow()
        addSubview(inputRow)
        inputRow.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(Self.barHeight)
        }
    }

    func setupAddMoreRow() {
        guard !isPreview else { return }
        let row = WhatsAppBottomAddMoreRow(store: store)
        row.delegate = self
        addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        addMoreRow = row
    }

    func createInputRow() -> UIView {
        let row = UIView()
        let spacing = AlbumPickerCoreTheme.spacing8

        let leadingView = isPreview
            ? setupPreviewLeadingView(in: row, spacing: spacing)
            : setupThumbnailLeadingView(in: row, spacing: spacing)

        let sendBtn = createSendButton()
        row.addSubview(sendBtn)
        sendBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-spacing)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.sendButtonSize)
        }

        if let leadingView {
            setupCaptionInput()
            row.addSubview(captionInput)
            captionInput.snp.makeConstraints { make in
                inputLeadingConstraint = make.leading.equalTo(
                    leadingView.snp.trailing
                ).offset(spacing).constraint
                make.centerY.equalToSuperview()
                make.trailing.equalTo(sendBtn.snp.leading).offset(
                    -spacing
                )
                make.height.equalTo(Self.inputHeight)
            }
        }

        return row
    }

    func setupPreviewLeadingView(in row: UIView, spacing: CGFloat) -> UIView {
        let addBtn = createAddMediaButton()
        addMediaButton = addBtn
        addButtonLeadingMargin = spacing
        row.addSubview(addBtn)
        addBtn.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(spacing)
            make.centerY.equalToSuperview()
            addButtonWidthConstraint = make.width.equalTo(
                Self.thumbnailSize
            ).constraint
            make.height.equalTo(Self.thumbnailSize)
        }
        return addBtn
    }

    func setupThumbnailLeadingView(in row: UIView, spacing: CGFloat) -> UIView? {
        createThumbnailContainer()
        guard let container = thumbnailContainer else { return nil }
        row.addSubview(container)
        container.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(spacing)
            make.centerY.equalToSuperview()
            thumbnailWidthConstraint = make.width.equalTo(
                thumbnailContainerSize
            ).constraint
            thumbnailHeightConstraint = make.height.equalTo(
                thumbnailContainerSize
            ).constraint
        }
        return container
    }

    func createAddMediaButton() -> UIButton {
        let btn = UIButton(type: .custom)
        let icon = UIImage.albumPickerIcon(
            named: "album_picker_ic_add_media"
        )?.withRenderingMode(.alwaysOriginal)
        btn.setImage(icon, for: .normal)
        btn.imageView?.contentMode = .scaleAspectFit
        btn.addTarget(
            self, action: #selector(handleAddMore),
            for: .touchUpInside
        )
        return btn
    }

    func createThumbnailContainer() {
        let container = UIView()
        container.clipsToBounds = false

        let backView = UIImageView()
        backView.contentMode = .scaleAspectFill
        backView.clipsToBounds = true
        backView.layer.cornerRadius = theme.smallRadius
        backView.backgroundColor = theme.backgroundColorSecondary
        backView.transform = CGAffineTransform(
            rotationAngle: Self.thumbnailRotationAngle
        )
        backView.isHidden = true
        container.addSubview(backView)
        backView.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview()
            make.width.height.equalTo(Self.thumbnailSize)
        }
        thumbnailBackView = backView

        let frontView = UIImageView()
        frontView.contentMode = .scaleAspectFill
        frontView.clipsToBounds = true
        frontView.layer.cornerRadius = theme.smallRadius
        frontView.backgroundColor = theme.backgroundColorSecondary
        container.addSubview(frontView)
        frontView.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview()
            make.width.height.equalTo(Self.thumbnailSize)
        }
        thumbnailFrontView = frontView

        let tap = UITapGestureRecognizer(
            target: self, action: #selector(handlePreview)
        )
        container.addGestureRecognizer(tap)

        thumbnailContainer = container
    }

    func setupCaptionInput() {
        let bgSecondary = isPreview
            ? AlbumPickerCoreTheme.previewBackgroundColorSecondary
            : theme.backgroundColorSecondary
        let txtColor = isPreview ? UIColor.white : theme.textColor
        let txtSecondary = isPreview
            ? AlbumPickerCoreTheme.previewTextColorSecondary
            : theme.textColorSecondary

        let input = UITextField()
        input.font = .systemFont(ofSize: theme.normalFontSize)
        input.textColor = txtColor
        input.attributedPlaceholder = NSAttributedString(
            string: "add_caption".albumPickerLocalized(),
            attributes: [.foregroundColor: txtSecondary]
        )
        input.backgroundColor = bgSecondary
        input.layer.cornerRadius = Self.inputHeight / 2
        input.leftView = UIView(
            frame: CGRect(
                x: 0, y: 0,
                width: AlbumPickerCoreTheme.spacing12, height: 1
            )
        )
        input.leftViewMode = .always
        input.rightView = UIView(
            frame: CGRect(
                x: 0, y: 0,
                width: AlbumPickerCoreTheme.spacing12, height: 1
            )
        )
        input.rightViewMode = .always
        input.delegate = self
        captionInput = input
    }

    func createSendButton() -> UIView {
        let container = UIView()
        container.backgroundColor = theme.currentPrimaryColor
        container.layer.cornerRadius = Self.sendButtonSize / 2
        container.clipsToBounds = false

        let iconView = UIImageView()
        iconView.image = theme.confirmButtonIcon
            ?? UIImage(systemName: "paperplane.fill")
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        container.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Self.sendIconSize)
        }

        let tap = UITapGestureRecognizer(
            target: self, action: #selector(handleSend)
        )
        container.addGestureRecognizer(tap)
        sendButton = container

        setupBadge(on: container)
        return container
    }

    func setupBadge(on container: UIView) {
        let badge = UILabel()
        badge.font = .systemFont(
            ofSize: theme.smallFontSize, weight: .bold
        )
        badge.textColor = theme.backgroundColor
        badge.textAlignment = .center
        badge.backgroundColor = theme.textColor
        badge.layer.cornerRadius = Self.badgeSize / 2
        badge.layer.borderWidth = Self.badgeBorderWidth
        badge.layer.borderColor = theme.backgroundColor.cgColor
        badge.clipsToBounds = true
        badge.isHidden = true
        container.addSubview(badge)
        badge.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(-AlbumPickerCoreTheme.spacing2)
            make.trailing.equalToSuperview().offset(AlbumPickerCoreTheme.spacing2)
            make.width.height.equalTo(Self.badgeSize)
        }
        badgeLabel = badge
    }
}

extension WhatsAppBottomBar: UITextFieldDelegate {
    internal func textFieldDidBeginEditing(_ textField: UITextField) {
        animateThumbnail(expand: true)
    }

    internal func textFieldDidEndEditing(_ textField: UITextField) {
        animateThumbnail(expand: false)
    }

    internal func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private extension WhatsAppBottomBar {
    func animateThumbnail(expand: Bool) {
        guard expand != isExpanded else { return }
        isExpanded = expand

        let targetMargin = expand ? 0 : AlbumPickerCoreTheme.spacing8

        if isPreview {
            animatePreviewThumbnail(
                expand: expand, targetMargin: targetMargin
            )
        } else {
            animateNormalThumbnail(
                expand: expand, targetMargin: targetMargin
            )
        }
    }

    func animatePreviewThumbnail(expand: Bool, targetMargin: CGFloat) {
        let targetWidth = expand ? 0 : Self.thumbnailSize
        UIView.animate(
            withDuration: Self.expandAnimationDuration,
            delay: 0,
            options: .curveEaseOut
        ) { [self] in
            addButtonWidthConstraint?.update(offset: targetWidth)
            inputLeadingConstraint?.update(offset: targetMargin)
            addMediaButton?.alpha = expand ? 0 : 1
            layoutIfNeeded()
        }
    }

    func animateNormalThumbnail(expand: Bool, targetMargin: CGFloat) {
        let targetSize = expand ? 0 : thumbnailContainerSize
        UIView.animate(
            withDuration: Self.expandAnimationDuration,
            delay: 0,
            options: .curveEaseOut
        ) { [self] in
            thumbnailWidthConstraint?.update(offset: targetSize)
            thumbnailHeightConstraint?.update(offset: targetSize)
            inputLeadingConstraint?.update(offset: targetMargin)
            thumbnailContainer?.alpha = expand ? 0 : 1
            layoutIfNeeded()
        }
    }

    func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    func prewarmKeyboard() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let temp = UITextField(frame: .zero)
            addSubview(temp)
            temp.becomeFirstResponder()
            temp.resignFirstResponder()
            temp.removeFromSuperview()
        }
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        guard captionInput.isFirstResponder else { return }
        guard let info = notification.userInfo,
              let frame = info[
                  UIResponder.keyboardFrameEndUserInfoKey
              ] as? CGRect
        else { return }
        let duration = info[
            UIResponder.keyboardAnimationDurationUserInfoKey
        ] as? TimeInterval ?? Self.expandAnimationDuration
        delegate?.bottomBar(
            self, keyboardHeightChanged: frame.height,
            duration: duration
        )
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        let duration = notification.userInfo?[
            UIResponder.keyboardAnimationDurationUserInfoKey
        ] as? TimeInterval ?? Self.expandAnimationDuration
        delegate?.bottomBar(
            self, keyboardHeightChanged: 0, duration: duration
        )
    }
}

private extension WhatsAppBottomBar {
    func startObserving() {
        cancellable = store.state.$selectedMedias
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedMedias in
                guard let self else { return }
                handleSelectedMediasChanged(selectedMedias)
            }
    }

    func handleSelectedMediasChanged(_ selectedMedias: [SelectedMediaItem]) {
        let active = isPreview
            ? selectedMedias.filter { !$0.isPendingRemoval }
            : selectedMedias
        updateState(activeMedias: active)
        if isAddMoreMode {
            addMoreRow?.update(medias: active.map(\.media))
            if active.isEmpty { isAddMoreMode = false; inputRow.isHidden = false }
        }
    }

    func updateState(activeMedias: [SelectedMediaItem]) {
        let count = activeMedias.count
        updateBadge(count: count)
        if !isPreview {
            updateThumbnails(activeMedias: activeMedias)
        }
    }

    func updateBadge(count: Int) {
        if count > 0 {
            badgeLabel?.text = "\(count)"
            badgeLabel?.isHidden = false
        } else {
            badgeLabel?.isHidden = true
        }
    }

    func updateThumbnails(activeMedias: [SelectedMediaItem]) {
        guard let front = activeMedias.first?.media
        else { return }
        loadThumbnail(for: front, into: thumbnailFrontView)

        if activeMedias.count > 1,
           let back = activeMedias.last?.media {
            thumbnailBackView?.isHidden = false
            loadThumbnail(for: back, into: thumbnailBackView)
        } else {
            thumbnailBackView?.isHidden = true
        }
    }

    func loadThumbnail(for media: AlbumMediaModel, into imageView: UIImageView?) {
        store.loadMediaThumbnail(
            for: media
        ) { [weak imageView] image in
            imageView?.image = image
        }
    }
}

private extension WhatsAppBottomBar {
    @objc func handleSend() {
        delegate?.bottomBar(
            self, didTapSendWithText: getTextMessage()
        )
    }

    @objc func handlePreview() {
        delegate?.bottomBarDidTapPreview(self)
    }

    @objc func handleAddMore() {
        delegate?.bottomBarDidTapAddMore(self)
    }
}

extension WhatsAppBottomBar: WhatsAppAddMoreRowDelegate {
    func addMoreRowDidTapConfirm(_ row: WhatsAppBottomAddMoreRow) {
        delegate?.bottomBarDidTapPreview(self)
    }
}
