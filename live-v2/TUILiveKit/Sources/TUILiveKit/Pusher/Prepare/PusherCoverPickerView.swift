import Kingfisher
import SnapKit
import UIKit

final class PusherCoverPickerView: BottomSheetView {
    var onSelect: ((String) -> Void)?

    private var selectedURL = LiveKitResources.defaultCoverURL
    private var options: [(url: String, view: PusherCoverOptionView)] = []

    override var sheetHeight: CGFloat { 190 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    func bind(selectedURL: String) {
        self.selectedURL = selectedURL
        options.forEach { option in
            option.view.bind(url: option.url, isSelected: option.url == selectedURL)
        }
    }

    private func configureUI() {
        sheetTitle = LiveKitResources.localizedString("tuilivekit.pusher.prepare.change_cover")

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 8
        contentView.addSubview(stack)

        LiveKitResources.presetCoverURLs.enumerated().forEach { index, url in
            let optionView = PusherCoverOptionView()
            optionView.accessibilityLabel = LiveKitResources.localizedFormat(
                "tuilivekit.pusher.prepare.cover_option",
                index + 1
            )
            optionView.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                selectedURL = url
                bind(selectedURL: url)
                onSelect?(url)
                dismiss()
            }, for: .touchUpInside)
            options.append((url, optionView))
            stack.addArrangedSubview(optionView)
        }

        stack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalToSuperview().offset(68)
            make.height.equalTo(stack.arrangedSubviews[0].snp.width)
            make.bottom.lessThanOrEqualTo(contentView.safeAreaLayoutGuide.snp.bottom).inset(12)
        }

        bind(selectedURL: selectedURL)
    }
}

private final class PusherCoverOptionView: UIControl {
    private let imageView = UIImageView()
    private var isImageLoading = false
    private var representedURL = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.06)
        layer.cornerRadius = 12
        layer.borderWidth = 2
        layer.masksToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bind(url: String, isSelected: Bool) {
        layer.borderColor = isSelected
            ? LiveTheme.Color.brandBlue.cgColor
            : UIColor.white.withAlphaComponent(0.14).cgColor
        accessibilityTraits = isSelected ? [.button, .selected] : .button

        if representedURL == url, isImageLoading || imageView.image != nil {
            return
        }
        representedURL = url
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        isEnabled = false
        alpha = 0.55
        isImageLoading = true
        imageView.kf.setImage(with: URL(string: url), placeholder: imageView.image) { [weak self] result in
            if case .failure(let error) = result, error.isNotCurrentTask || error.isTaskCancelled { return }
            let image = try? result.get().image
            guard let self, representedURL == url else { return }
            isImageLoading = false
            guard image != nil else { return }
            isEnabled = true
            alpha = 1
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Task { @MainActor [imageView] in
            imageView.kf.cancelDownloadTask()
        }
    }
}
