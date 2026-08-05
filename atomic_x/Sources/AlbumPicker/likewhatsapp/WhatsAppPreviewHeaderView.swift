import AlbumPickerCore
import Combine
import UIKit

internal protocol WhatsAppPreviewHeaderViewDelegate: AnyObject {
    func previewHeaderViewDidTapBack(_ view: WhatsAppPreviewHeaderView)
    func previewHeaderViewDidTapEdit(_ view: WhatsAppPreviewHeaderView)
}

internal class WhatsAppPreviewHeaderView: UIView {

    private static let backButtonSize: CGFloat = 24
    private static let backButtonTapSize: CGFloat = 44
    private static let videoEditButtonAlpha: CGFloat = 0.4

    internal weak var delegate: WhatsAppPreviewHeaderViewDelegate?

    private let store: AlbumPickerStore
    private let theme = AlbumPickerCoreTheme.shared
    private let editButton = UIButton(type: .system)
    private var cancellable: AnyCancellable?

    internal init(store: AlbumPickerStore) {
        self.store = store
        super.init(frame: .zero)
        setupViews()
        startObserving()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cancellable = nil
    }

    private func setupViews() {
        backgroundColor = AlbumPickerCoreTheme.previewBackgroundColor

        let backButton = UIButton(type: .system)
        backButton.setImage(
            UIImage(systemName: "chevron.left"), for: .normal
        )
        backButton.tintColor = .white
        backButton.addTarget(
            self, action: #selector(handleBack), for: .touchUpInside
        )
        addSubview(backButton)

        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(
                AlbumPickerCoreTheme.spacing16 - (Self.backButtonTapSize - Self.backButtonSize) / 2
            )
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.width.height.equalTo(Self.backButtonTapSize)
        }

        editButton.setTitle("edit".albumPickerLocalized(), for: .normal)
        editButton.setTitleColor(.white, for: .normal)
        editButton.titleLabel?.font = .systemFont(
            ofSize: theme.normalFontSize, weight: .medium
        )
        editButton.addTarget(
            self, action: #selector(handleEdit), for: .touchUpInside
        )
        addSubview(editButton)

        editButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-AlbumPickerCoreTheme.spacing16)
            make.centerY.equalTo(backButton)
        }

        snp.makeConstraints { make in
            make.bottom.equalTo(backButton).offset(
                AlbumPickerCoreTheme.spacing8 - (Self.backButtonTapSize - Self.backButtonSize) / 2
            )
        }
    }

    private func startObserving() {
        cancellable = store.state.$currentPreviewMedia
            .receive(on: DispatchQueue.main)
            .sink { [weak self] media in
                self?.updateEditButton(media: media)
            }
    }

    private func updateEditButton(media: AlbumMediaModel?) {
        let isVideo = media?.type == .video
        editButton.alpha = isVideo ? Self.videoEditButtonAlpha : 1.0
        editButton.isUserInteractionEnabled = !isVideo
    }

    @objc private func handleBack() {
        delegate?.previewHeaderViewDidTapBack(self)
    }

    @objc private func handleEdit() {
        delegate?.previewHeaderViewDidTapEdit(self)
    }
}
