import AlbumPickerCore
import Combine
import UIKit

internal protocol WeChatBottomBarDelegate: AnyObject {
    func bottomBarDidTapSend(_ bar: WeChatBottomBar)
    func bottomBarDidTapPreview(_ bar: WeChatBottomBar)
}

internal class WeChatBottomBar: UIView {

    private static let indicatorSize: CGFloat = 20
    private static let doneIconSize: CGFloat = 14
    private static let doneIconScale: CGFloat = 0.7
    private static let borderWidth: CGFloat = 1

    internal weak var delegate: WeChatBottomBarDelegate?

    private let store: AlbumPickerStore
    private let isPreview: Bool
    private let theme = AlbumPickerCoreTheme.shared

    private var sendContainer: UIView!
    private var sendTitleLabel: UILabel!
    private var sendCountLabel: UILabel!
    private var previewTitleLabel: UILabel?
    private var previewCountLabel: UILabel?
    private var previewContainer: UIView?
    private var originalContainer: UIView!
    private var originalIndicator: UIView!
    private var originalDoneIcon: UIImageView!
    private var originalLabel: UILabel!
    private var originalSizeLabel: UILabel!

    private var selectedCount: Int = 0
    private var totalSizeBytes: Int64 = 0
    private var cancellables = Set<AnyCancellable>()

    internal init(store: AlbumPickerStore, isPreview: Bool = false) {
        self.store = store
        self.isPreview = isPreview
        super.init(frame: .zero)
        setupViews()
        startObserving()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension WeChatBottomBar {
    func setupViews() {
        let bgColor = isPreview ? AlbumPickerCoreTheme.previewBackgroundColor : theme
            .backgroundColor
        backgroundColor = bgColor
        setupSendButton()
        setupOriginalButton()
        if !isPreview { setupPreviewButton() }
    }

    func setupSendButton() {
        let bgSecondary = isPreview
            ? AlbumPickerCoreTheme.previewBackgroundColorSecondary
            : theme.backgroundColorSecondary

        let container = UIView()
        container.backgroundColor = bgSecondary
        container.layer.cornerRadius = theme.normalRadius
        container.clipsToBounds = true
        addSubview(container)
        container.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(
                -AlbumPickerCoreTheme.spacing16
            )
            make.centerY.equalToSuperview()
        }
        sendContainer = container

        let tap = UITapGestureRecognizer(
            target: self, action: #selector(handleSend)
        )
        container.addGestureRecognizer(tap)

        setupSendButtonLabels(in: container)
    }

    func setupSendButtonLabels(in container: UIView) {
        let txtSecondary = isPreview
            ? AlbumPickerCoreTheme.previewTextColorSecondary
            : theme.textColorSecondary
        let font = UIFont.systemFont(
            ofSize: theme.normalFontSize, weight: .medium
        )

        let titleLabel = UILabel()
        titleLabel.text = "send".albumPickerLocalized()
        titleLabel.font = font
        titleLabel.textColor = txtSecondary
        container.addSubview(titleLabel)

        let countLabel = UILabel()
        countLabel.font = font
        countLabel.textColor = txtSecondary
        countLabel.isHidden = true
        container.addSubview(countLabel)

        let insetH = AlbumPickerCoreTheme.spacing8 + AlbumPickerCoreTheme.spacing2
        let insetV = AlbumPickerCoreTheme.spacing6
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(insetH)
            make.top.equalToSuperview().offset(insetV)
            make.bottom.equalToSuperview().offset(-insetV)
        }
        countLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing)
            make.trailing.equalToSuperview().offset(-insetH)
            make.centerY.equalTo(titleLabel)
        }

        sendTitleLabel = titleLabel
        sendCountLabel = countLabel
    }

    func setupOriginalButton() {
        let txtColor = isPreview ? UIColor.white : theme.textColor
        let txtSecondary = isPreview
            ? AlbumPickerCoreTheme.previewTextColorSecondary
            : theme.textColorSecondary
        let font = UIFont.systemFont(
            ofSize: theme.normalFontSize, weight: .medium
        )

        let container = UIView()
        addSubview(container)
        container.snp.makeConstraints { make in
            if isPreview {
                make.leading.equalToSuperview().offset(AlbumPickerCoreTheme.spacing16)
            } else {
                make.centerX.equalToSuperview()
            }
            make.centerY.equalToSuperview()
        }
        originalContainer = container

        let tap = UITapGestureRecognizer(
            target: self, action: #selector(handleOriginalToggle)
        )
        container.addGestureRecognizer(tap)

        let indicator = UIView()
        indicator.layer.cornerRadius = Self.indicatorSize / 2
        indicator.layer.borderWidth = Self.borderWidth
        indicator.layer.borderColor = txtColor.cgColor
        indicator.clipsToBounds = true
        indicator.isUserInteractionEnabled = false
        container.addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(Self.indicatorSize)
        }
        originalIndicator = indicator

        let config = UIImage.SymbolConfiguration(
            pointSize: Self.doneIconSize * Self.doneIconScale, weight: .medium
        )
        let icon = theme.confirmButtonIcon
            ?? UIImage(
                systemName: "checkmark",
                withConfiguration: config
            )?.withRenderingMode(.alwaysTemplate)
        let doneIcon = UIImageView()
        doneIcon.image = icon
        doneIcon.tintColor = .white
        doneIcon.contentMode = .scaleAspectFit
        doneIcon.isHidden = true
        doneIcon.isUserInteractionEnabled = false
        indicator.addSubview(doneIcon)
        doneIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Self.doneIconSize)
        }
        originalDoneIcon = doneIcon

        let label = UILabel()
        label.text = "original".albumPickerLocalized()
        label.font = font
        label.textColor = txtColor
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalTo(indicator.snp.trailing).offset(
                AlbumPickerCoreTheme.spacing4
            )
            make.trailing.top.bottom.equalToSuperview()
        }
        originalLabel = label

        let sizeLabel = UILabel()
        sizeLabel.font = UIFont.systemFont(
            ofSize: theme.smallFontSize, weight: .regular
        )
        sizeLabel.textColor = txtSecondary
        sizeLabel.textAlignment = .center
        sizeLabel.isHidden = true
        sizeLabel.isUserInteractionEnabled = false
        addSubview(sizeLabel)
        sizeLabel.snp.makeConstraints { make in
            make.top.equalTo(container.snp.bottom)
            make.centerX.equalTo(container)
        }
        originalSizeLabel = sizeLabel
    }

    func setupPreviewButton() {
        let txtSecondary = isPreview
            ? AlbumPickerCoreTheme.previewTextColorSecondary
            : theme.textColorSecondary
        let font = UIFont.systemFont(
            ofSize: theme.normalFontSize, weight: .medium
        )

        let container = UIView()
        addSubview(container)
        container.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(
                AlbumPickerCoreTheme.spacing16
            )
            make.centerY.equalToSuperview()
        }
        previewContainer = container

        let tap = UITapGestureRecognizer(
            target: self, action: #selector(handlePreview)
        )
        container.addGestureRecognizer(tap)

        let titleLabel = UILabel()
        titleLabel.text = "preview".albumPickerLocalized()
        titleLabel.font = font
        titleLabel.textColor = txtSecondary
        container.addSubview(titleLabel)

        let countLabel = UILabel()
        countLabel.font = font
        countLabel.textColor = txtSecondary
        countLabel.isHidden = true
        container.addSubview(countLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        countLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing)
            make.trailing.equalToSuperview()
            make.centerY.equalTo(titleLabel)
        }

        previewTitleLabel = titleLabel
        previewCountLabel = countLabel
    }

    func startObserving() {
        store.state.$selectedMedias
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedMedias in
                guard let self else { return }
                let activeItems = isPreview
                    ? selectedMedias.filter { !$0.isPendingRemoval }
                    : selectedMedias
                totalSizeBytes = activeItems.reduce(0) { $0 + $1.media.size }
                updateState(count: activeItems.count)
            }
            .store(in: &cancellables)

        store.state.$isOriginalSelected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateOriginalButton()
            }
            .store(in: &cancellables)
    }

    func activeCount(from selectedMedias: [SelectedMediaItem]) -> Int {
        isPreview
            ? selectedMedias.filter { !$0.isPendingRemoval }.count
            : selectedMedias.count
    }

    func updateState(count: Int) {
        selectedCount = count
        updateSendButton(count: count)
        updatePreviewButton(count: count)
        updateOriginalButton()
    }

    func updateSendButton(count: Int) {
        let txtSecondary = isPreview
            ? AlbumPickerCoreTheme.previewTextColorSecondary
            : theme.textColorSecondary
        let bgSecondary = isPreview
            ? AlbumPickerCoreTheme.previewBackgroundColorSecondary
            : theme.backgroundColorSecondary

        if count > 0 {
            sendCountLabel.text = "(\(count))"
            sendCountLabel.isHidden = false
            sendTitleLabel.textColor = .white
            sendCountLabel.textColor = .white
            sendContainer.backgroundColor =
                theme.currentPrimaryColor
        } else {
            sendCountLabel.text = nil
            sendCountLabel.isHidden = true
            sendTitleLabel.textColor = txtSecondary
            sendCountLabel.textColor = txtSecondary
            sendContainer.backgroundColor = bgSecondary
        }
    }

    func updatePreviewButton(count: Int) {
        let txtColor = isPreview
            ? UIColor.white
            : theme.textColor
        let txtSecondary = isPreview
            ? AlbumPickerCoreTheme.previewTextColorSecondary
            : theme.textColorSecondary

        if count > 0 {
            previewCountLabel?.text = "(\(count))"
            previewCountLabel?.isHidden = false
            previewTitleLabel?.textColor = txtColor
            previewCountLabel?.textColor = txtColor
        } else {
            previewCountLabel?.text = nil
            previewCountLabel?.isHidden = true
            previewTitleLabel?.textColor = txtSecondary
        }
    }

    func updateOriginalButton() {
        let txtColor = isPreview
            ? UIColor.white
            : theme.textColor
        let primaryColor = theme.currentPrimaryColor
        let isOriginal = store.state.isOriginalSelected

        if isOriginal {
            originalDoneIcon.isHidden = false
            originalIndicator.backgroundColor = primaryColor
            originalIndicator.layer.borderColor = primaryColor.cgColor
        } else {
            originalDoneIcon.isHidden = true
            originalIndicator.backgroundColor = .clear
            originalIndicator.layer.borderColor = txtColor.cgColor
        }
        originalLabel.textColor = txtColor
        updateOriginalSizeLabel()
    }

    func updateOriginalSizeLabel() {
        if store.state.isOriginalSelected, totalSizeBytes > 0 {
            let sizeStr = formatFileSize(totalSizeBytes)
            let template = "total_size".albumPickerLocalized()
            originalSizeLabel.text = String(
                format: template, sizeStr
            )
            originalSizeLabel.isHidden = false
        } else {
            originalSizeLabel.isHidden = true
        }
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let gb: Int64 = 1024 * 1024 * 1024
        let mb: Int64 = 1024 * 1024
        let kb: Int64 = 1024
        if bytes >= gb {
            return String(format: "%.1fGB", Double(bytes) / Double(gb))
        } else if bytes >= mb {
            return "\(bytes / mb)MB"
        } else {
            return "\(max(bytes / kb, 1))KB"
        }
    }

    @objc func handleSend() {
        if isPreview || selectedCount > 0 {
            delegate?.bottomBarDidTapSend(self)
        }
    }

    @objc func handlePreview() {
        if selectedCount > 0 {
            delegate?.bottomBarDidTapPreview(self)
        }
    }

    @objc func handleOriginalToggle() {
        let toggled = store.toggleOriginalSelection()
        guard !toggled else { return }
        showOriginalOversizedBlockedAlert()
    }

    func showOriginalOversizedBlockedAlert() {
        let size = store.config.maxOutputFileSizeInMB
        let message = String(
            format: "original_oversized_blocked".albumPickerLocalized(),
            size
        )
        let buttonTitle = "i_know".albumPickerLocalized()
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: buttonTitle, style: .default))
        parentViewController?.present(alert, animated: true)
    }

    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let controller = next as? UIViewController { return controller }
            responder = next
        }
        return nil
    }
}
