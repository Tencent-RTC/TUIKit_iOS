import Kingfisher
import SnapKit
import UIKit

final class PusherLiveInfoEditorView: UIView {
    var onChangeCover: (() -> Void)?
    var onTitleChanged: ((String) -> Void)?

    private let coverButton = UIControl()
    private let coverImageView = UIImageView()
    private static let titleByteLimit = 100
    private let titleInput = LiveTextInputView(limit: PusherLiveInfoEditorView.titleByteLimit, unit: .utf8Bytes, maximumLines: 3, minimumHeight: 28)
    private var isImageLoading = false
    private var representedCoverURL = ""
    private var isBindingTitle = false

    var title: String {
        titleInput.text ?? ""
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        loadCover()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        coverImageView.layer.cornerRadius = 14
        coverImageView.layer.borderWidth = 1
        coverImageView.layer.borderColor = LiveInfoEditorStyle.coverBorder.cgColor
        coverImageView.layer.shadowColor = UIColor.black.cgColor
        coverImageView.layer.shadowOpacity = 0.4
        coverImageView.layer.shadowOffset = CGSize(width: 0, height: 6)
        coverImageView.layer.shadowRadius = 9
        coverImageView.clipsToBounds = true

        let coverHint = LiveText(.metadata, alignment: .center, emphasized: true)
        coverHint.text = LiveKitResources.localizedString("tuilivekit.pusher.prepare.change_cover")

        let coverStack = UIStackView(arrangedSubviews: [coverImageView, coverHint])
        coverStack.axis = .vertical
        coverStack.alignment = .center
        coverStack.spacing = 6
        coverStack.isUserInteractionEnabled = false
        coverButton.accessibilityLabel = coverHint.text
        coverButton.addTarget(self, action: #selector(changeCover), for: .touchUpInside)
        coverButton.addSubview(coverStack)
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
                LiveKitResources.localizedFormat("tuilivekit.pusher.prepare.topic_byte_limit", Self.titleByteLimit)
            )
        }
        addSubview(titleInput)

        let editHint = UIButton(type: .system)
        editHint.setTitle(LiveKitResources.localizedString("tuilivekit.pusher.prepare.edit_topic"), for: .normal)
        editHint.setTitleColor(.white, for: .normal)
        editHint.titleLabel?.font = LiveInfoEditorStyle.editHintFont
        editHint.addTarget(self, action: #selector(editTopic), for: .touchUpInside)
        addSubview(editHint)

        coverButton.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        coverStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        coverImageView.snp.makeConstraints { make in
            make.size.equalTo(58)
        }
        titleInput.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(45)
            make.top.equalToSuperview().offset(90)
        }
        editHint.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleInput.snp.bottom)
            make.height.equalTo(25)
            make.bottom.equalToSuperview().inset(10)
        }
    }

    private func loadCover(_ coverURL: String = LiveKitResources.defaultCoverURL) {
        if representedCoverURL == coverURL, isImageLoading || coverImageView.image != nil {
            return
        }
        representedCoverURL = coverURL
        coverImageView.kf.cancelDownloadTask()
        isImageLoading = true
        coverImageView.kf.setImage(with: URL(string: coverURL), placeholder: coverImageView.image) { [weak self] result in
            if case .failure(let error) = result, error.isNotCurrentTask || error.isTaskCancelled { return }
            guard let self, representedCoverURL == coverURL else { return }
            isImageLoading = false
        }
    }

    @objc private func changeCover() {
        onChangeCover?()
    }

    @objc private func editTopic() {
        titleInput.becomeFirstResponder()
    }

    deinit {
        Task { @MainActor [coverImageView] in
            coverImageView.kf.cancelDownloadTask()
        }
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum LiveInfoEditorStyle {
    static let coverBackground: UIColor = UIColor(red: 0.13, green: 0.15, blue: 0.23, alpha: 1)
    static let coverBorder: UIColor = UIColor.white.withAlphaComponent(0.16)
    static let titleFont: UIFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
    static let editHintFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
}
