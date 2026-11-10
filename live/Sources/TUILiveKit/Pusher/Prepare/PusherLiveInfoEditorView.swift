import Kingfisher
import SnapKit
import UIKit

final class PusherLiveInfoEditorView: UIView {
    var onChangeCover: (() -> Void)?
    var onTitleChanged: ((String) -> Void)?

    private let coverButton = UIControl()
    private let coverImageView = UIImageView()
    private let coverHint = LiveText(.metadata, alignment: .center, emphasized: true)
    private let editHint = UIButton(type: .system)
    private var layoutScale: CGFloat = 1
    private static let titleByteLimit = 100
    private let titleInput = LiveTextInputView(
        limit: PusherLiveInfoEditorView.titleByteLimit, unit: .utf8Bytes, maximumLines: 3, minimumHeight: 0)
    private var isImageLoading = false
    private var representedCoverURL = ""
    private var isBindingTitle = false

    var title: String { titleInput.text ?? "" }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        loadCover()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        if bounds.width > 0 { updateLayoutScale(LiveLayoutScale.factor(for: bounds.width)) }
        super.layoutSubviews()
    }

    private func updateLayoutScale(_ scale: CGFloat) {
        guard layoutScale != scale else { return }
        layoutScale = scale
        coverImageView.layer.cornerRadius = 18 * scale
        coverButton.layer.cornerRadius = 18 * scale
        coverImageView.layer.shadowOffset = CGSize(width: 0, height: 6 * scale)
        coverImageView.layer.shadowRadius = 9 * scale
        coverHint.font = LiveInfoEditorStyle.coverHintFont.withSize(12 * scale)
        titleInput.font = LiveInfoEditorStyle.titleFont.withSize(24 * scale)
        editHint.titleLabel?.font = LiveInfoEditorStyle.editHintFont.withSize(14 * scale)
        coverButton.snp.updateConstraints { make in make.size.equalTo(72 * scale) }
        coverHint.snp.updateConstraints { make in make.height.equalTo(22 * scale) }
        titleInput.snp.updateConstraints { make in
            make.leading.trailing.equalToSuperview().inset(32 * scale)
            make.top.equalTo(coverButton.snp.bottom).offset(32 * scale)
            make.height.greaterThanOrEqualTo(34 * scale)
        }
        editHint.snp.updateConstraints { make in
            make.top.equalTo(titleInput.snp.bottom).offset(4 * scale)
            make.height.equalTo(32 * scale)
            make.bottom.equalToSuperview().inset(12 * scale)
        }
        titleInput.invalidateIntrinsicContentSize()
        titleInput.setNeedsLayout()
    }

    func bind(title: String, coverURL: String) {
        if !titleInput.isFirstResponder {
            isBindingTitle = true
            titleInput.setContent(title)
            isBindingTitle = false
        }
        loadCover(coverURL)
    }

    private func configureUI() {
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.backgroundColor = LiveInfoEditorStyle.coverBackground
        coverImageView.layer.cornerRadius = 18
        coverImageView.layer.borderWidth = 1
        coverImageView.layer.borderColor = LiveInfoEditorStyle.coverBorder.cgColor
        coverImageView.layer.shadowColor = UIColor.black.cgColor
        coverImageView.layer.shadowOpacity = 0.4
        coverImageView.layer.shadowOffset = CGSize(width: 0, height: 6)
        coverImageView.layer.shadowRadius = 9
        coverImageView.clipsToBounds = true

        coverHint.text = LiveKitResources.localizedString("tuilivekit.pusher.prepare.change_cover")
        coverHint.font = LiveInfoEditorStyle.coverHintFont
        coverHint.textColor = LiveInfoEditorStyle.hintColor
        coverHint.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        coverHint.adjustsFontSizeToFitWidth = true
        coverHint.minimumScaleFactor = 0.7

        coverButton.layer.cornerRadius = 18
        coverButton.clipsToBounds = true
        coverButton.accessibilityLabel = coverHint.text
        coverButton.addTarget(self, action: #selector(changeCover), for: .touchUpInside)
        coverButton.addSubview(coverImageView)
        coverButton.addSubview(coverHint)
        addSubview(coverButton)

        titleInput.setContent(LiveKitResources.localizedString("tuilivekit.pusher.default_title"))
        titleInput.textColor = .white
        titleInput.font = LiveInfoEditorStyle.titleFont
        titleInput.textAlignment = .center
        titleInput.returnKeyType = .done
        titleInput.onSubmit = { [weak self] in self?.titleInput.resignFirstResponder() }
        titleInput.onTextChanged = { [weak self] in
            guard let self, !isBindingTitle else { return }
            onTitleChanged?(title)
        }
        titleInput.onLimitExceeded = { [weak self] in
            guard let self, self.window != nil else { return }
            LiveToast.show(
                LiveKitResources.localizedFormat("tuilivekit.pusher.prepare.topic_byte_limit", Self.titleByteLimit))
        }
        addSubview(titleInput)

        editHint.setTitle(LiveKitResources.localizedString("tuilivekit.pusher.prepare.edit_topic"), for: .normal)
        editHint.setTitleColor(LiveInfoEditorStyle.hintColor, for: .normal)
        editHint.titleLabel?.font = LiveInfoEditorStyle.editHintFont
        editHint.addTarget(self, action: #selector(editTopic), for: .touchUpInside)
        addSubview(editHint)

        coverButton.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(72)
        }
        coverImageView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        coverHint.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(22)
        }
        titleInput.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(32)
            make.top.equalTo(coverButton.snp.bottom).offset(32)
            make.height.greaterThanOrEqualTo(34)
        }
        editHint.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleInput.snp.bottom).offset(4)
            make.height.equalTo(32)
            make.bottom.equalToSuperview().inset(12)
        }
    }

    private func loadCover(_ coverURL: String = LiveKitResources.defaultCoverURL) {
        if representedCoverURL == coverURL, isImageLoading || coverImageView.image != nil { return }
        representedCoverURL = coverURL
        coverImageView.kf.cancelDownloadTask()
        isImageLoading = true
        coverImageView.kf.setImage(with: URL(string: coverURL), placeholder: coverImageView.image) {
            [weak self] result in
            if case .failure(let error) = result, error.isNotCurrentTask || error.isTaskCancelled { return }
            guard let self, representedCoverURL == coverURL else { return }
            isImageLoading = false
        }
    }

    @objc private func changeCover() { onChangeCover?() }

    @objc private func editTopic() { titleInput.becomeFirstResponder() }

    deinit { Task { @MainActor [coverImageView] in coverImageView.kf.cancelDownloadTask() } }
}

// Reference sizes match the iPhone 18 Pro Max layout at standard display settings.
private enum LiveInfoEditorStyle {
    static let coverBackground: UIColor = UIColor(red: 0.13, green: 0.15, blue: 0.23, alpha: 1)
    static let coverBorder: UIColor = UIColor.white.withAlphaComponent(0.16)
    static let titleFont: UIFont = UIFont.systemFont(ofSize: 24, weight: .semibold)
    static let hintColor: UIColor = UIColor(white: 0.75, alpha: 1)
    static let coverHintFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .medium)
    static let editHintFont: UIFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
}
