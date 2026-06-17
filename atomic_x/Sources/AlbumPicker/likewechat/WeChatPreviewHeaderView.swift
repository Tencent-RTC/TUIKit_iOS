import AlbumPickerCore
import Combine
import UIKit

internal protocol WeChatPreviewHeaderViewDelegate: AnyObject {
    func previewHeaderViewDidTapBack(_ view: WeChatPreviewHeaderView)
    func previewHeaderViewDidTapSelect(_ view: WeChatPreviewHeaderView)
}

internal class WeChatPreviewHeaderView: UIView {

    private static let headerHeight: CGFloat = 44
    private static let indicatorSize: CGFloat = 20
    private static let doneIconSize: CGFloat = 14
    private static let doneIconScale: CGFloat = 0.7
    private static let backButtonSize: CGFloat = 24
    private static let backButtonTapSize: CGFloat = 44
    private static let borderWidth: CGFloat = 1

    internal weak var delegate: WeChatPreviewHeaderViewDelegate?

    private let store: AlbumPickerStore
    private let theme = AlbumPickerCoreTheme.shared
    private var cancellable: AnyCancellable?

    private lazy var backButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(
            UIImage(systemName: "chevron.left"), for: .normal
        )
        btn.tintColor = .white
        btn.addTarget(
            self, action: #selector(handleBack),
            for: .touchUpInside
        )
        return btn
    }()

    private lazy var pageIndicator: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(
            ofSize: AlbumPickerCoreTheme.shared.bigFontSize,
            weight: .semibold
        )
        label.textAlignment = .center
        return label
    }()

    private lazy var selectButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.addTarget(
            self, action: #selector(handleSelect),
            for: .touchUpInside
        )
        return btn
    }()

    private lazy var selectIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Self.indicatorSize / 2
        view.layer.borderWidth = Self.borderWidth
        view.layer.borderColor = UIColor.white.cgColor
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var selectDoneIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(
            pointSize: Self.doneIconSize * Self.doneIconScale, weight: .medium
        )
        let icon = theme.confirmButtonIcon
            ?? UIImage(
                systemName: "checkmark",
                withConfiguration: config
            )?.withRenderingMode(.alwaysTemplate)
        imageView.image = icon
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private lazy var selectTextLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(
            ofSize: theme.normalFontSize, weight: .medium
        )
        label.text = "select".albumPickerLocalized()
        label.isUserInteractionEnabled = false
        return label
    }()

    internal init(store: AlbumPickerStore) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = AlbumPickerCoreTheme.previewBackgroundColor
        constructViewHierarchy()
        activateConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

internal extension WeChatPreviewHeaderView {
    func startObserving() {
        cancellable = Publishers.CombineLatest(
            store.state.$currentPreviewMedia,
            store.state.$selectedMedias
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _ in
            self?.updatePageIndicator()
            self?.updateSelectState()
        }
    }

    func stopObserving() {
        cancellable?.cancel()
        cancellable = nil
    }
}

private extension WeChatPreviewHeaderView {
    func constructViewHierarchy() {
        addSubview(backButton)
        addSubview(pageIndicator)
        addSubview(selectButton)
        selectButton.addSubview(selectIndicator)
        selectIndicator.addSubview(selectDoneIcon)
        selectButton.addSubview(selectTextLabel)
    }

    func activateConstraints() {
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
        pageIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
        }
        selectButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-AlbumPickerCoreTheme.spacing16)
            make.centerY.equalTo(backButton)
        }
        selectIndicator.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.indicatorSize)
        }
        selectDoneIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Self.doneIconSize)
        }
        selectTextLabel.snp.makeConstraints { make in
            make.leading.equalTo(
                selectIndicator.snp.trailing
            ).offset(AlbumPickerCoreTheme.spacing8)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
}

private extension WeChatPreviewHeaderView {
    func updatePageIndicator() {
        let previewMedias = store.state.previewMedias
        guard let currentMedia = store.state
            .currentPreviewMedia else { return }
        let idx = previewMedias.firstIndex(
            where: { $0.id == currentMedia.id }
        )
        guard let currentIdx = idx else { return }
        pageIndicator.text =
            "\(currentIdx + 1)/\(previewMedias.count)"
    }

    func updateSelectState() {
        guard let currentMedia = store.state
            .currentPreviewMedia else { return }
        let selectedItem = store.state.selectedMedias.first(
            where: { $0.media.id == currentMedia.id }
        )
        let isSelected = selectedItem != nil
            && !(selectedItem?.isPendingRemoval ?? true)
        let primaryColor = theme.currentPrimaryColor

        if isSelected {
            selectDoneIcon.isHidden = false
            selectIndicator.backgroundColor = primaryColor
            selectIndicator.layer.borderColor =
                primaryColor.cgColor
        } else {
            selectDoneIcon.isHidden = true
            selectIndicator.backgroundColor = .clear
            selectIndicator.layer.borderColor =
                UIColor.white.cgColor
        }
    }
}

private extension WeChatPreviewHeaderView {
    @objc func handleBack() {
        delegate?.previewHeaderViewDidTapBack(self)
    }

    @objc func handleSelect() {
        delegate?.previewHeaderViewDidTapSelect(self)
    }
}
