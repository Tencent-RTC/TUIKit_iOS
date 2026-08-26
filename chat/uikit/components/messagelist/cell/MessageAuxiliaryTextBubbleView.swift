import UIKit
import SnapKit
import Combine

final class MessageAuxiliaryTextBubbleView: UIView {
    var onLongPress: (() -> Void)?

    override var intrinsicContentSize: CGSize {
        let maxContentWidth = Self.maxBubbleWidth - 2 * Self.horizontalInset
        if !contentLabel.isHidden {
            let contentSize = contentLabel.sizeThatFits(CGSize(width: maxContentWidth, height: .greatestFiniteMagnitude))
            var contentWidth = contentSize.width
            var totalHeight = Self.verticalInset + contentSize.height + Self.verticalInset
            if !footerLabel.isHidden, let footerText = footerLabel.text, !footerText.isEmpty {
                let footerSize = footerLabel.sizeThatFits(CGSize(width: maxContentWidth, height: .greatestFiniteMagnitude))
                contentWidth = max(contentWidth, footerSize.width)
                totalHeight += Self.footerTopSpacing + footerSize.height
            }
            return CGSize(
                width: min(ceil(contentWidth) + 2 * Self.horizontalInset, Self.maxBubbleWidth),
                height: ceil(totalHeight)
            )
        }
        let indicatorSize = loadingIndicator.intrinsicContentSize
        return CGSize(
            width: indicatorSize.width * Self.loadingIndicatorScale + 2 * Self.horizontalInset,
            height: indicatorSize.height * Self.loadingIndicatorScale + 2 * Self.verticalInset
        )
    }

    private static let cornerRadius: CGFloat = 9

    private static let verticalInset: CGFloat = 6

    private static let horizontalInset: CGFloat = 9

    private static let footerTopSpacing = CGFloat(SpacingScheme.iconTextSpacing)

    private static let contentLineHeightMultiple: CGFloat = 1.3

    private static let maxBubbleWidth: CGFloat = UIScreen.main.bounds.width * 0.72

    private static let loadingIndicatorScale: CGFloat = 0.8

    private static let footerSelfAlpha: CGFloat = 0.6

    private let contentLabel = UILabel()

    private let footerLabel = UILabel()

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var lastIsSelf = false

    private var lastContentText: String?

    private var themeCancellable: AnyCancellable?

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
        observeThemeChanges()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(isSelf: Bool, isLoading: Bool, contentText: String?, footerText: String?) {
        lastIsSelf = isSelf
        applyColors()

        if isLoading {
            loadingIndicator.startAnimating()
            contentLabel.isHidden = true
            footerLabel.isHidden = true
            loadingIndicator.snp.remakeConstraints { make in
                make.center.equalToSuperview()
                make.top.equalToSuperview().offset(Self.verticalInset)
                make.bottom.equalToSuperview().offset(-Self.verticalInset)
            }
            contentLabel.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(Self.verticalInset)
                make.leading.equalToSuperview().offset(Self.horizontalInset)
                make.trailing.equalToSuperview().offset(-Self.horizontalInset)
            }
            footerLabel.snp.remakeConstraints { make in
                make.top.equalTo(contentLabel.snp.bottom).offset(Self.footerTopSpacing)
                make.leading.equalTo(contentLabel)
                make.trailing.lessThanOrEqualTo(contentLabel)
                make.bottom.equalToSuperview().offset(-Self.verticalInset)
            }
        } else {
            contentLabel.isHidden = false
            applyContentText(contentText)
            if let footer = footerText, !footer.isEmpty {
                footerLabel.isHidden = false
                footerLabel.text = footer
            } else {
                footerLabel.isHidden = true
                footerLabel.text = nil
            }
            contentLabel.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(Self.verticalInset)
                make.leading.equalToSuperview().offset(Self.horizontalInset)
                make.trailing.equalToSuperview().offset(-Self.horizontalInset)
                if footerLabel.isHidden {
                    make.bottom.equalToSuperview().offset(-Self.verticalInset)
                }
            }
            if !footerLabel.isHidden {
                footerLabel.snp.remakeConstraints { make in
                    make.top.equalTo(contentLabel.snp.bottom).offset(Self.footerTopSpacing)
                    make.leading.equalTo(contentLabel)
                    make.trailing.lessThanOrEqualTo(contentLabel)
                    make.bottom.equalToSuperview().offset(-Self.verticalInset)
                }
            }
            loadingIndicator.stopAnimating()
        }
        invalidateIntrinsicContentSize()
    }

    func reset() {
        loadingIndicator.stopAnimating()
        contentLabel.attributedText = nil
        contentLabel.isHidden = false
        lastContentText = nil
        footerLabel.text = nil
        footerLabel.isHidden = true
        onLongPress = nil
        invalidateIntrinsicContentSize()
    }

    private func constructViewHierarchy() {
        addSubview(loadingIndicator)
        addSubview(contentLabel)
        addSubview(footerLabel)
    }

    private func activateConstraints() {
        snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(Self.maxBubbleWidth)
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(Self.verticalInset)
            make.bottom.lessThanOrEqualToSuperview().offset(-Self.verticalInset)
        }
        contentLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.verticalInset)
            make.leading.equalToSuperview().offset(Self.horizontalInset)
            make.trailing.equalToSuperview().offset(-Self.horizontalInset)
        }
        footerLabel.snp.makeConstraints { make in
            make.top.equalTo(contentLabel.snp.bottom).offset(Self.footerTopSpacing)
            make.leading.equalTo(contentLabel)
            make.trailing.lessThanOrEqualTo(contentLabel)
            make.bottom.equalToSuperview().offset(-Self.verticalInset)
        }
    }

    private func setupViewStyle() {
        layer.cornerRadius = Self.cornerRadius
        clipsToBounds = true
        contentLabel.numberOfLines = 0
        footerLabel.font = FontScheme.caption3Regular
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.transform = CGAffineTransform(scaleX: Self.loadingIndicatorScale, y: Self.loadingIndicatorScale)
    }

    private func bindInteraction() {
        isUserInteractionEnabled = true
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:))))
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        onLongPress?()
    }

    private func applyColors() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = lastIsSelf ? colors.bgColorBubbleOwn : colors.bgColorBubbleReciprocal
        footerLabel.textColor = lastIsSelf
            ? colors.textColorAntiPrimary.withAlphaComponent(Self.footerSelfAlpha)
            : colors.textColorSecondary
        applyContentText(lastContentText)
    }

    private func applyContentText(_ text: String?) {
        lastContentText = text
        guard let text = text, !text.isEmpty else {
            contentLabel.attributedText = nil
            return
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = Self.contentLineHeightMultiple
        let contentColor = lastIsSelf ? ChatUIKitTheme.colors.textColorAntiPrimary : ChatUIKitTheme.colors.textColorPrimary
        contentLabel.attributedText = NSAttributedString(string: text, attributes: [
            .font: FontScheme.caption2Regular,
            .foregroundColor: contentColor,
            .paragraphStyle: paragraph
        ])
    }

    private func observeThemeChanges() {
        themeCancellable = ThemeState.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyColors()
            }
    }
}
