import AtomicXCore
import SnapKit
import TUIChatKit
import UIKit

// MARK: - 自定义消息数据模型

struct CustomLinkMessage {
    static let businessID = "text_link"

    let text: String?

    let link: String?

    static func from(customData: String?) -> CustomLinkMessage? {
        guard let customData = customData, !customData.isEmpty,
              let data = customData.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return CustomLinkMessage(text: dict["text"] as? String, link: dict["link"] as? String)
    }

    static func from(message: MessageInfo) -> CustomLinkMessage? {
        guard case .custom(let payload) = message.messagePayload else { return nil }
        return from(customData: payload.customData)
    }
}

// MARK: - 注册自定义消息渲染器（App 启动时调用一次）

enum CustomLinkMessageRegistrar {
    static func register() {
        MessageListView.registerCustomMessageCell(
            businessID: CustomLinkMessage.businessID,
            summaryProvider: { payload in
                CustomLinkMessage.from(customData: payload.customData)?.text
            },
            makeContentView: {
                CustomLinkMessageContentView()
            }
        )
    }
}

// MARK: - 发送自定义消息

func sendCustomLinkMessage(conversationID: String) {
    let text = LocalizedChatString("DemoChatCustomMessageContent")
    let payload: [String: Any] = [
        "businessID": CustomLinkMessage.businessID,
        "text": text,
        "link": "https://cloud.tencent.com/document/product/269/3794"
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else { return }
    let customPayload = CustomSendMessagePayload(customData: json, description: text)
    MessageInputStore.create(conversationID: conversationID)
        .sendMessage(payload: .custom(customPayload), option: nil, completion: nil)
}

// MARK: - 气泡内容视图

final class CustomLinkMessageContentView: UIView, MessageContentView {
    private static let maxBubbleWidth: CGFloat = 245
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 12
    private static let linkTopSpacing: CGFloat = 8
    private let textLabel = UILabel()
    private let linkLabel = UILabel()
    private var linkURL: URL?

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(message: MessageInfo, context: MessageContentContext) {
        let linkMessage = CustomLinkMessage.from(message: message)
        let colors = TUIChatKitTheme.colors

        textLabel.text = linkMessage?.text
        textLabel.textColor = message.isSentBySelf ? colors.textColorAntiPrimary : colors.textColorPrimary

        let link = linkMessage?.link?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        linkURL = URL(string: link)
        linkLabel.isHidden = link.isEmpty
        linkLabel.text = LocalizedChatString("DemoChatCustomMessageViewDetails")
        linkLabel.textColor = colors.textColorLink

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
        textLabel.font = .systemFont(ofSize: 16)
        textLabel.preferredMaxLayoutWidth = Self.maxBubbleWidth - Self.horizontalPadding * 2
        linkLabel.numberOfLines = 1
        linkLabel.font = .systemFont(ofSize: 14)
    }

    @objc private func handleTap() {
        guard let url = linkURL else { return }
        UIApplication.shared.open(url)
    }
}
