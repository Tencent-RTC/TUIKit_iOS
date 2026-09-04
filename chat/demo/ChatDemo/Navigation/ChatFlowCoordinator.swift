import TUIChatKit
import AtomicXCore
import SnapKit
import UIKit

final class ChatFlowCoordinator {
    weak var navigationController: UINavigationController?

    init() {}

    // MARK: - Chat

    func pushChat(_ conversation: ConversationInfo, locateMessage: MessageInfo? = nil, animated: Bool = true) {
        let page = makeChatPage(conversation, locateMessage)

        page.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(page, animated: animated)
    }

    // MARK: - C2C Setting

    func pushC2CSetting(userID: String, parentConversationID: String?) {
        let setting = C2CChatSettingViewController(
            userID: userID,
            onSendMessageClick: { [weak self] in
                self?.handleC2CSendMessage(userID: userID, parentConversationID: parentConversationID)
            },
            onContactDelete: { [weak self] in
                self?.navigationController?.popToRootViewController(animated: true)
            }
        )
        pushSettingPage(setting)
    }

    // MARK: - Group Setting

    func pushGroupSetting(groupID: String, parentConversationID: String?) {
        let setting = GroupChatSettingViewController(
            groupID: groupID,
            onSendMessageClick: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            },
            onGroupDelete: { [weak self] in
                self?.navigationController?.popToRootViewController(animated: true)
            },
            onGroupMemberClick: { [weak self] memberUserID in
                self?.pushUserProfile(userID: memberUserID, parentConversationID: parentConversationID)
            }
        )
        pushSettingPage(setting)
    }

    // MARK: - Setting Push

    private func makeChatPage(_ conversation: ConversationInfo, _ locateMessage: MessageInfo?) -> ChatPage {
        let page = ChatPage(
            conversation: conversation,
            locateMessage: locateMessage,
            messageListConfig: makeMessageListConfig(),
            messageInputConfig: makeMessageInputConfig(conversationID: conversation.conversationID),
            isShowMoreButton: true,
            onBack: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            },
            onUserClick: { [weak self] userID in
                self?.pushC2CSetting(userID: userID, parentConversationID: conversation.conversationID)
            },
            onMoreClick: { [weak self] in
                self?.handleNavigationAvatarClick(for: conversation)
            }
        )
        let warningView = ChatSecurityWarningView()
        warningView.onClose = { [weak page] in
            page?.topBannerView = nil
        }
        page.topBannerView = warningView
        return page
    }
    
    private func makeMessageListConfig() -> ChatMessageListConfig {
        return ChatMessageListConfig(isShowRightAvatar: true)
    }

    private func makeMessageInputConfig(conversationID: String) -> ChatMessageInputConfig {
        return ChatMessageInputConfig(actionCustomizer: { editor in
            editor.add(MessageInputMenuAction(
                ID: "demo.messageInput.customLink",
                title: LocalizedChatString("DemoChatCustomMessageMenuTitle"),
                iconName: "",
                icon: UIImage(systemName: "paperplane.fill")?
                    .withTintColor(TUIChatKitTheme.colors.textColorSecondary, renderingMode: .alwaysOriginal),
                onClick: {
                    ChatFlowCoordinator.sendCustomLinkMessage(conversationID: conversationID)
                }
            ))
        })
    }

    private static func sendCustomLinkMessage(conversationID: String) {
        let text = LocalizedChatString("DemoChatCustomMessageContent")
        let payload: [String: Any] = [
            "businessID": "text_link",
            "text": text,
            "link": "https://cloud.tencent.com/document/product/269/3794"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        let customPayload = CustomSendMessagePayload(customData: json, description: text)
        var option = SendMessageOption()
        option.needReadReceipt = ChatMessageInputConfig().enableReadReceipt
        MessageInputStore.create(conversationID: conversationID)
            .sendMessage(payload: .custom(customPayload), option: option, completion: nil)
    }

    private func handleNavigationAvatarClick(for conversation: ConversationInfo) {
        if conversation.type == .c2c, let userID = ChatUtil.getUserID(conversation.conversationID) {
            pushC2CSetting(userID: userID, parentConversationID: conversation.conversationID)
        } else if conversation.type == .group, let groupID = ChatUtil.getGroupID(conversation.conversationID) {
            pushGroupSetting(groupID: groupID, parentConversationID: conversation.conversationID)
        }
    }

    private func handleC2CSendMessage(userID: String, parentConversationID: String?) {
        let targetConversationID = ChatUtil.getC2CConversationID(userID)
        if parentConversationID == targetConversationID {
            navigationController?.popViewController(animated: true)
            return
        }
        ContactStore.shared.getContactInfo(
            userIDList: [userID],
            completion: CoordinatorContactInfoHandler(
                onSuccess: { [weak self] list in
                    DispatchQueue.main.async { self?.pushC2CChat(userID: userID, contact: list.first) }
                },
                onFailure: { [weak self] _, _ in
                    DispatchQueue.main.async { self?.pushC2CChat(userID: userID, contact: nil) }
                }
            )
        )
    }

    private func pushC2CChat(userID: String, contact: ContactInfo?) {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(userID))
        conversation.type = .c2c
        conversation.title = displayName(for: contact) ?? userID
        conversation.avatarURL = contact?.avatarURL
        pushChat(conversation)
    }

    private func displayName(for contact: ContactInfo?) -> String? {
        guard let contact = contact else { return nil }
        if let remark = contact.friendRemark, !remark.isEmpty { return remark }
        if let nickname = contact.nickname, !nickname.isEmpty { return nickname }
        return nil
    }

    private func pushUserProfile(userID: String, parentConversationID: String?) {
        guard let source = navigationController?.topViewController else { return }
        UserProfileRouter.open(
            userID: userID,
            from: source,
            onSendMessageClick: { [weak self] in
                self?.handleC2CSendMessage(userID: userID, parentConversationID: parentConversationID)
            },
            onContactDelete: { [weak self] in
                self?.navigationController?.popToRootViewController(animated: true)
            }
        )
    }

    private func pushSettingPage(_ viewController: UIViewController) {
        viewController.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(viewController, animated: true)
    }
}

// MARK: - Security Warning Banner

final class ChatSecurityWarningView: UIView {
    var onClose: (() -> Void)?

    private static let leadingInset: CGFloat = 20

    private static let trailingInset: CGFloat = 17

    private static let verticalInset: CGFloat = 16

    private static let iconSize: CGFloat = 16

    private static let iconTextGap: CGFloat = 10

    private static let textCloseGap: CGFloat = 7

    private static let closeButtonSize: CGFloat = 22

    private static let warningFontSize: CGFloat = 14

    private static let reportURL = "https://cloud.tencent.com/act/event/report-platform"

    private let iconView = UIImageView()

    private let warningTextView = UITextView()

    private let closeButton = UIButton(type: .custom)

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

    private var textHeightConstraint: Constraint?

    private var currentTextHeight: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        let textWidth = bounds.width - Self.leadingInset - Self.iconSize - Self.iconTextGap
            - Self.textCloseGap - Self.closeButtonSize - Self.trailingInset
        guard textWidth > 0 else { return }
        let fitting = warningTextView.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        guard abs(fitting.height - currentTextHeight) > 0.5 else { return }
        currentTextHeight = fitting.height
        textHeightConstraint?.update(offset: fitting.height)
    }

    private func constructViewHierarchy() {
        addSubview(iconView)
        addSubview(warningTextView)
        addSubview(closeButton)
    }

    private func activateConstraints() {
        let firstLineHeight = UIFont.systemFont(ofSize: Self.warningFontSize).lineHeight
        let iconTopOffset = Self.verticalInset + max(0, (firstLineHeight - Self.iconSize) / 2)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.leadingInset)
            make.top.equalToSuperview().offset(iconTopOffset)
            make.width.height.equalTo(Self.iconSize)
        }
        warningTextView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Self.iconTextGap)
            make.top.equalToSuperview().offset(Self.verticalInset)
            make.bottom.equalToSuperview().offset(-Self.verticalInset)
            make.trailing.equalTo(closeButton.snp.leading).offset(-Self.textCloseGap)
            textHeightConstraint = make.height.equalTo(0).constraint
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.trailingInset)
            make.top.equalToSuperview().offset(Self.verticalInset)
            make.width.height.equalTo(Self.closeButtonSize)
        }
    }

    private func setupViewStyle() {
        let colors = ThemeState.shared.colors
        backgroundColor = colors.toastColorWarning
        iconView.image = UIImage(named: "demo_ic_security_warning")?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = colors.textColorWarning
        iconView.contentMode = .scaleAspectFit
        closeButton.setImage(
            UIImage(named: "demo_ic_security_close")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        closeButton.tintColor = colors.textColorWarning
        closeButton.imageView?.contentMode = .scaleAspectFit

        warningTextView.isEditable = false
        warningTextView.isScrollEnabled = false
        warningTextView.backgroundColor = .clear
        warningTextView.textContainerInset = .zero
        warningTextView.textContainer.lineFragmentPadding = 0
        warningTextView.dataDetectorTypes = []
        warningTextView.linkTextAttributes = [.foregroundColor: colors.textColorLink]
        warningTextView.attributedText = makeWarningText()
    }

    private func bindInteraction() {
        warningTextView.delegate = self
        closeButton.addTarget(self, action: #selector(handleCloseTapped), for: .touchUpInside)
    }

    private func makeWarningText() -> NSAttributedString {
        let colors = ThemeState.shared.colors
        let warning = LocalizedChatString("ChatSecurityWarning")
        let report = LocalizedChatString("ChatSecurityWarningReport")
        let text = NSMutableAttributedString(
            string: warning + " ",
            attributes: [
                .font: UIFont.systemFont(ofSize: Self.warningFontSize),
                .foregroundColor: colors.textColorWarning
            ]
        )
        text.append(NSAttributedString(
            string: report,
            attributes: [
                .font: UIFont.systemFont(ofSize: Self.warningFontSize),
                .foregroundColor: colors.textColorLink,
                .link: URL(string: Self.reportURL) as Any
            ]
        ))
        return text
    }

    @objc private func handleCloseTapped() {
        onClose?()
    }
}

extension ChatSecurityWarningView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL)
        return false
    }
}

// MARK: - Custom Link Message

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

enum CustomLinkMessageManager {
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

final class CustomLinkMessageContentView: UIView, MessageContentView {
    private static let horizontalPadding: CGFloat = 16

    private static let verticalPadding: CGFloat = 12

    private static let linkTopSpacing: CGFloat = 8

    private static let textFontSize: CGFloat = 16

    private static let linkFontSize: CGFloat = 14

    private static let textLineSpacingMultiplier: CGFloat = 0.3

    private static let linkLineSpacingMultiplier: CGFloat = 0.2

    private static let maxBubbleWidth: CGFloat = UIScreen.main.bounds.width * 0.72

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
        let linkMessage = CustomLinkMessage.from(message: message)
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
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
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

    @objc private func handleTap() {
        guard let url = linkURL else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Store Completion Handler

private final class CoordinatorContactInfoHandler: GetContactInfoCompletionHandler {
    private let onSuccessBlock: ([ContactInfo]) -> Void

    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping ([ContactInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(contactInfoList: [ContactInfo]) {
        onSuccessBlock(contactInfoList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}
