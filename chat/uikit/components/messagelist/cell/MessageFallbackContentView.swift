import UIKit
import SnapKit
import AtomicXCore

final class MessageFallbackContentView: UIView, MessageContentView {
    private static let cornerRadius: CGFloat = 10

    private static let horizontalInset = CGFloat(SpacingScheme.iconIconSpacing)

    private static let verticalInset = CGFloat(SpacingScheme.smallSpacing)

    private static let maxBubbleWidth: CGFloat = UIScreen.main.bounds.width * 0.72

    private let kind: MessageContentKind

    private let bubbleView = UIView()

    private let textLabel = UILabel()

    // MARK: - Init

    init(kind: MessageContentKind) {
        self.kind = kind
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - MessageContentView

    func bind(message: MessageInfo, context: MessageContentContext) {
        textLabel.text = displayText(for: message, context: context)
        applyBubbleStyle(isSelf: message.isSentBySelf)
    }

    // MARK: - Private

    private func constructViewHierarchy() {
        addSubview(bubbleView)
        bubbleView.addSubview(textLabel)
    }

    private func activateConstraints() {
        bubbleView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.lessThanOrEqualTo(Self.maxBubbleWidth)
        }
        textLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Self.verticalInset)
            make.leading.trailing.equalToSuperview().inset(Self.horizontalInset)
        }
    }

    private func setupViewStyle() {
        bubbleView.layer.cornerRadius = Self.cornerRadius
        bubbleView.clipsToBounds = true
        textLabel.numberOfLines = 0
        textLabel.font = FontScheme.caption2Regular
    }

    private func displayText(for message: MessageInfo, context: MessageContentContext) -> String {
        if message.messagePayload == nil {
            return LocalizedChatString("NoMessageContent")
        }

        if kind == .unsupported {
            return context.config.isShowUnsupportMessage ? LocalizedChatString("MessageUnsupportedType") : ""
        }
        let abstract = MessageListHelper.getMessageAbstract(message)
        if !abstract.isEmpty {
            return abstract
        }
        return context.config.isShowUnsupportMessage ? LocalizedChatString("MessageUnsupportedType") : ""
    }

    private func applyBubbleStyle(isSelf: Bool) {
        let colors = ChatUIKitTheme.colors
        textLabel.textColor = isSelf ? colors.textColorAntiPrimary : colors.textColorPrimary
    }
}
