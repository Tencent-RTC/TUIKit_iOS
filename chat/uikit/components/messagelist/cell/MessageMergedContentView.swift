import UIKit
import SnapKit
import AtomicXCore

final class MessageMergedContentView: UIView, MessageContentView {
    private static let cardWidth: CGFloat = 214

    private static let cornerRadius = CGFloat(RadiusScheme.alertRadius)

    private static let horizontalPadding = CGFloat(SpacingScheme.iconIconSpacing)

    private static let verticalPadding: CGFloat = 10

    private static let titleToAbstractSpacing: CGFloat = 6

    private static let abstractLineSpacing: CGFloat = 2

    private static let dividerTopSpacing: CGFloat = 9

    private static let dividerBottomSpacing: CGFloat = 6

    private static let dividerHeight: CGFloat = 0.5

    private static let maxAbstractLines = 4

    private static let cardBorderWidth: CGFloat = 1

    private static let titleMaxLines = 1

    private static let abstractMaxLines = 1

    private let cardView = UIView()

    private let titleLabel = UILabel()

    private let abstractStack = UIStackView()

    private let dividerView = UIView()

    private let hintLabel = UILabel()

    private var onTap: ((MessageInfo) -> Void)?

    private var tappedMessage: MessageInfo?

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - MessageContentView

    func bind(message: MessageInfo, context: MessageContentContext) {
        tappedMessage = message
        onTap = context.onMergedMessageTap
        titleLabel.text = Self.mergedTitle(from: message)
        rebuildAbstracts(Self.abstractList(from: message))
    }

    func setCardChromeHidden(_ hidden: Bool) {
        let colors = ChatUIKitTheme.colors
        cardView.backgroundColor = hidden ? .clear : colors.bgColorDialog
        cardView.layer.borderWidth = hidden ? 0 : Self.cardBorderWidth
    }

    // MARK: - Private

    private func constructViewHierarchy() {
        addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(abstractStack)
        cardView.addSubview(dividerView)
        cardView.addSubview(hintLabel)
    }

    private func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        guard let message = tappedMessage else { return }
        onTap?(message)
    }

    private func activateConstraints() {
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(Self.cardWidth)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
        }
        abstractStack.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Self.titleToAbstractSpacing)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
        }
        dividerView.snp.makeConstraints { make in
            make.top.equalTo(abstractStack.snp.bottom).offset(Self.dividerTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
            make.height.equalTo(Self.dividerHeight)
        }
        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(dividerView.snp.bottom).offset(Self.dividerBottomSpacing)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors

        cardView.backgroundColor = colors.bgColorDialog
        cardView.layer.cornerRadius = Self.cornerRadius
        cardView.layer.borderWidth = Self.cardBorderWidth
        cardView.layer.borderColor = colors.strokeColorPrimary.cgColor
        cardView.clipsToBounds = true

        titleLabel.font = FontScheme.caption1Regular
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.numberOfLines = Self.titleMaxLines
        titleLabel.textAlignment = .natural

        abstractStack.axis = .vertical
        abstractStack.alignment = .fill
        abstractStack.spacing = Self.abstractLineSpacing

        dividerView.backgroundColor = colors.strokeColorPrimary

        hintLabel.font = FontScheme.caption4Regular
        hintLabel.textColor = colors.textColorSecondary
        hintLabel.text = LocalizedChatString("RelayChatHistory")
        hintLabel.textAlignment = .natural
    }

    private func rebuildAbstracts(_ abstracts: [String]) {
        abstractStack.arrangedSubviews.forEach {
            abstractStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        abstractStack.isHidden = abstracts.isEmpty
        for abstract in abstracts.prefix(Self.maxAbstractLines) {
            abstractStack.addArrangedSubview(makeAbstractLabel(abstract))
        }
    }

    private func makeAbstractLabel(_ abstract: String) -> UILabel {
        let label = UILabel()
        label.font = FontScheme.caption3Regular
        label.textColor = ChatUIKitTheme.colors.textColorSecondary
        label.numberOfLines = Self.abstractMaxLines
        label.lineBreakMode = .byTruncatingTail
        label.textAlignment = .natural
        if abstract.contains("[TUIEmoji_") {
            label.attributedText = EmojiManager.shared.createStyledAttributedString(
                fromEmojiCodes: abstract,
                font: FontScheme.caption3Regular,
                textColor: ChatUIKitTheme.colors.textColorSecondary
            )
        } else {
            label.text = abstract
        }
        return label
    }

    private static func mergedTitle(from message: MessageInfo) -> String {
        if case .merged(let payload) = message.messagePayload, !payload.title.isEmpty {
            return payload.title
        }
        return LocalizedChatString("RelayChatHistory")
    }

    private static func abstractList(from message: MessageInfo) -> [String] {
        if case .merged(let payload) = message.messagePayload {
            return payload.abstractList ?? []
        }
        return []
    }
}
