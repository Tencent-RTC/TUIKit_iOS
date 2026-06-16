import AlbumPickerCore
import UIKit

internal protocol WhatsAppPreviewHeaderViewDelegate: AnyObject {
    func previewHeaderViewDidTapBack(_ view: WhatsAppPreviewHeaderView)
}

internal class WhatsAppPreviewHeaderView: UIView {

    private static let backButtonSize: CGFloat = 24
    private static let backButtonTapSize: CGFloat = 44

    internal weak var delegate: WhatsAppPreviewHeaderViewDelegate?
    private let theme = AlbumPickerCoreTheme.shared

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        snp.makeConstraints { make in
            make.bottom.equalTo(backButton).offset(
                AlbumPickerCoreTheme.spacing8 - (Self.backButtonTapSize - Self.backButtonSize) / 2
            )
        }
    }

    @objc private func handleBack() {
        delegate?.previewHeaderViewDidTapBack(self)
    }
}
