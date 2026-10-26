import TUIChatKit
import AtomicXCore
import SnapKit
import UIKit

internal struct CustomLinkMessage {
    internal static let businessID = "text_link"
    internal let text: String?
    internal let link: String?

    internal static func decode(customData: String?) -> CustomLinkMessage? {
        guard let customData, !customData.isEmpty,
              let data = customData.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return CustomLinkMessage(text: payload["text"] as? String, link: payload["link"] as? String)
    }

    internal static func decode(message: MessageInfo) -> CustomLinkMessage? {
        guard case .custom(let payload) = message.messagePayload else { return nil }
        return decode(customData: payload.customData)
    }
}

internal enum CustomLinkMessageManager {
    private static let menuActionID = "demo.messageInput.customLink"
    private static let exampleLink = "https://cloud.tencent.com/document/product/269/3794"

    internal static func register() {
        MessageListView.registerCustomMessageCell(
            businessID: CustomLinkMessage.businessID,
            summaryProvider: { payload in
                CustomLinkMessage.decode(customData: payload.customData)?.text
            },
            makeContentView: {
                CustomLinkMessageContentView()
            }
        )
    }

    internal static func makeMenuAction(conversationID: String, enableReadReceipt: Bool) -> MessageInputMenuAction {
        return MessageInputMenuAction(
            ID: menuActionID,
            title: LocalizedChatString("DemoChatCustomMessageMenuTitle"),
            iconName: "",
            icon: UIImage(systemName: "paperplane.fill")?
                .withTintColor(TUIChatKitTheme.colors.textColorSecondary, renderingMode: .alwaysOriginal),
            onClick: {
                sendExampleMessage(conversationID: conversationID, enableReadReceipt: enableReadReceipt)
            }
        )
    }

    private static func sendExampleMessage(conversationID: String, enableReadReceipt: Bool) {
        let text = LocalizedChatString("DemoChatCustomMessageContent")
        let payload: [String: Any] = [
            "businessID": CustomLinkMessage.businessID,
            "text": text,
            "link": exampleLink
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        let customPayload = CustomSendMessagePayload(customData: json, description: text)
        var option = SendMessageOption()
        option.needReadReceipt = enableReadReceipt
        MessageInputStore.create(conversationID: conversationID)
            .sendMessage(payload: .custom(customPayload), option: option, completion: nil)
    }
}

private final class CustomLinkMessageContentView: UIView, MessageContentView {
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 12
    private static let linkTopSpacing: CGFloat = 8
    private static let textFontSize: CGFloat = 16
    private static let linkFontSize: CGFloat = 14
    private static let textLineSpacingMultiplier: CGFloat = 0.3
    private static let linkLineSpacingMultiplier: CGFloat = 0.2
    private static let bubbleWidthRatio: CGFloat = 0.72
    private static let maxBubbleWidth = UIScreen.main.bounds.width * bubbleWidthRatio

    private let textLabel = UILabel()
    private let linkLabel = UILabel()
    private var linkURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(message: MessageInfo, context: MessageContentContext) {
        let linkMessage = CustomLinkMessage.decode(message: message)
        let colors = TUIChatKitTheme.colors
        let textColor = message.isSentBySelf ? colors.textColorAntiPrimary : colors.textColorPrimary
        textLabel.attributedText = makeAttributedText(
            linkMessage?.text ?? "",
            fontSize: Self.textFontSize,
            color: textColor,
            multiplier: Self.textLineSpacingMultiplier
        )
        let link = linkMessage?.link?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        linkURL = URL(string: link)
        linkLabel.isHidden = link.isEmpty
        linkLabel.attributedText = makeAttributedText(
            LocalizedChatString("DemoChatCustomMessageViewDetails"),
            fontSize: Self.linkFontSize,
            color: colors.textColorLink,
            multiplier: Self.linkLineSpacingMultiplier
        )
        isUserInteractionEnabled = !link.isEmpty && !context.isMultiSelectMode
    }

    private func constructViewHierarchy() {
        addSubview(textLabel)
        addSubview(linkLabel)
    }

    private func activateConstraints() {
        textLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalPadding)
            make.width.lessThanOrEqualTo(Self.maxBubbleWidth - Self.horizontalPadding * 2)
        }
        linkLabel.snp.makeConstraints { make in
            make.top.equalTo(textLabel.snp.bottom).offset(Self.linkTopSpacing)
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
        }
    }

    private func setupViewStyle() {
        textLabel.numberOfLines = 0
        textLabel.textAlignment = .natural
        textLabel.preferredMaxLayoutWidth = Self.maxBubbleWidth - Self.horizontalPadding * 2
        linkLabel.numberOfLines = 1
        linkLabel.textAlignment = .natural
    }

    private func bindInteraction() {
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openLink)))
    }

    private func makeAttributedText(_ text: String, fontSize: CGFloat, color: UIColor, multiplier: CGFloat) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .natural
        paragraph.lineSpacing = font.lineHeight * multiplier
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
    }

    @objc private func openLink() {
        guard let url = linkURL else { return }
        UIApplication.shared.open(url)
    }
}
