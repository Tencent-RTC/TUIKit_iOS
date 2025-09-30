import AtomicX
import AtomicXCore
import Foundation
import Kingfisher
import SwiftUI

extension MessageInfo {
    var contentText: String? {
        return messageBody?.text
    }

    var imageInfo: (image: UIImage?, size: CGSize?) {
        guard let body = messageBody, messageType == .image else {
            return (nil, nil)
        }
        if let imagePath = body.originalImagePath, let image = UIImage(contentsOfFile: imagePath) {
            return (image, CGSize(width: body.originalImageWidth, height: body.originalImageHeight))
        }
        return (nil, CGSize(width: body.originalImageWidth, height: body.originalImageHeight))
    }

    var videoInfo: (snapshot: UIImage?, duration: Int?) {
        guard let body = messageBody, messageType == .video else {
            return (nil, nil)
        }
        if let snapshotPath = body.videoSnapshotPath {
            return (UIImage(contentsOfFile: snapshotPath), body.videoDuration)
        } else {
            return (nil, body.videoDuration)
        }
    }
}

public struct ChatPage: View {
    @EnvironmentObject var themeState: ThemeState
    @StateObject private var toast = Toast()
    @State private var messageText: String = ""
    @State private var inputAreaHeight: CGFloat = 60
    let listStyle: MessageListConfigProtocol
    let inputStyle: MessageInputConfigProtocol
    let onBack: (() -> Void)?
    let onUserAvatarClick: ((String) -> Void)?
    let onNavigationAvatarClick: (() -> Void)?
    let locateMessage: MessageInfo?
    private var conversation: ConversationInfo

    public init(
        conversation: ConversationInfo,
        listStyle: MessageListConfigProtocol = ChatMessageStyle(),
        inputStyle: MessageInputConfigProtocol = ChatMessageInputStyle(),
        locateMessage: MessageInfo? = nil,
        onBack: (() -> Void)? = nil,
        onUserAvatarClick: ((String) -> Void)? = nil,
        onNavigationAvatarClick: (() -> Void)? = nil
    ) {
        self.conversation = conversation
        self.listStyle = listStyle
        self.inputStyle = inputStyle
        self.locateMessage = locateMessage
        self.onBack = onBack
        self.onUserAvatarClick = onUserAvatarClick
        self.onNavigationAvatarClick = onNavigationAvatarClick
    }

    public var body: some View {
        if #available(iOS 15.0, *) {
            let _ = Self._printChanges()
        } else {
            // Fallback on earlier versions
        }

        return VStack(spacing: 0) {
            self.navigationBarView

            Divider()
                .background(self.themeState.colors.strokeColorPrimary)

            VStack(spacing: 0) {
                MessageList(
                    conversationID: self.conversation.id,
                    listStyle: self.listStyle,
                    locateMessage: self.locateMessage,
                    onUserClick: { userID in
                        onUserAvatarClick?(userID)
                    }
                )

                self.messageInputAreaView
            }
            .ignoresSafeArea(.keyboard)
        }
        .toast(toast)
        .onAppear {
//            self.setupNotificationObservers()
        }
        .onDisappear {
//            self.removeNotificationObservers()
        }
    }

    private var navigationBarView: some View {
        HStack {
            Button(action: {
                onBack?()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeState.colors.textColorLink)
            }
            .padding(.leading, 16)

            Button(action: {
                onNavigationAvatarClick?()
            }) {
                HStack(spacing: 12) {
                    Avatar(
                        url: conversation.avatarURL,
                        name: conversation.title ?? conversation.conversationID,
                        size: .s
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.title ?? conversation.conversationID)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(themeState.colors.textColorPrimary)
                            .lineLimit(1)

                        if conversation.type == .group {
                            Text("群聊")
                                .font(.system(size: 12))
                                .foregroundColor(themeState.colors.textColorSecondary)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
        .frame(height: 44)
    }

    private var messageInputAreaView: some View {
        VStack(spacing: 0) {
            MessageInput(
                text: $messageText,
                conversationID: conversation.id,
                style: inputStyle,
                onHeightChange: { height in
                    self.inputAreaHeight = height
                }
            )
            .padding(.bottom, 8)
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            handleKeyboardShow(notification)
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { notification in
            handleKeyboardHide(notification)
        }
    }

    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    private func handleKeyboardShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return
        }
    }

    private func handleKeyboardHide(_ notification: Notification) {}
}
