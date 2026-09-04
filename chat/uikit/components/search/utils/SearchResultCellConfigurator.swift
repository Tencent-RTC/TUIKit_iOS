import UIKit
import AtomicXCore

enum SearchResultCellConfigurator {

    private static var titleFont: UIFont { FontScheme.caption1Regular }
    private static var subtitleFont: UIFont { FontScheme.caption2Regular }

    static func configureFriend(_ cell: SearchResultCell,
                                friend: FriendSearchInfo,
                                keyword: String,
                                showDivider: Bool) {
        let colors = TUIChatKitTheme.colors
        let displayName = SearchDisplayHelper.friendDisplayName(friend)
        let title = SearchHighlightBuilder.attributedText(
            text: displayName, keyword: keyword, font: titleFont,
            normalColor: colors.textColorPrimary, highlightColor: colors.textColorLink
        )
        let subtitle = SearchHighlightBuilder.attributedText(
            text: "ID: \(friend.userID)", keyword: keyword, font: subtitleFont,
            normalColor: colors.textColorTertiary, highlightColor: colors.textColorLink
        )
        cell.configure(avatarURL: friend.userInfo?.avatarURL, avatarName: displayName,
                       title: title, subtitle: subtitle, showDivider: showDivider)
    }

    static func configureGroup(_ cell: SearchResultCell,
                               group: GroupSearchInfo,
                               keyword: String,
                               showDivider: Bool) {
        let colors = TUIChatKitTheme.colors
        let displayName = SearchDisplayHelper.groupDisplayName(group)
        let title = SearchHighlightBuilder.attributedText(
            text: displayName, keyword: keyword, font: titleFont,
            normalColor: colors.textColorPrimary, highlightColor: colors.textColorLink
        )
        let subtitle = SearchHighlightBuilder.attributedText(
            text: String(format: LocalizedChatString("SearchResultGroupIDFormat"), group.groupID),
            keyword: keyword, font: subtitleFont,
            normalColor: colors.textColorTertiary, highlightColor: colors.textColorLink
        )
        cell.configure(avatarURL: group.groupAvatarURL, avatarName: displayName,
                       title: title, subtitle: subtitle, showDivider: showDivider)
    }

    static func configureMessage(_ cell: SearchResultCell,
                                 item: MessageSearchResultItem,
                                 keyword: String,
                                 showDivider: Bool) {
        let colors = TUIChatKitTheme.colors
        let title = SearchHighlightBuilder.attributedText(
            text: item.conversationShowName, keyword: keyword, font: titleFont,
            normalColor: colors.textColorPrimary, highlightColor: colors.textColorLink
        )
        let subtitle: NSAttributedString
        if item.messageCount > 1 {
            subtitle = NSAttributedString(
                string: String(format: LocalizedChatString("SearchResultDisplayChatHistoryCountFormat"), item.messageCount),
                attributes: [.foregroundColor: colors.textColorTertiary, .font: subtitleFont]
            )
        } else {
            let abstract = item.messageList.first.map {
                MessageListHelper.getMessageAbstract($0, showMergedTitle: true)
            } ?? ""
            if abstract.contains("[TUIEmoji_") {
                subtitle = SearchHighlightBuilder.attributedTextWithEmoji(
                    text: abstract, keyword: keyword, font: subtitleFont,
                    normalColor: colors.textColorTertiary, highlightColor: colors.textColorLink
                )
            } else {
                subtitle = SearchHighlightBuilder.attributedText(
                    text: abstract, keyword: keyword, font: subtitleFont,
                    normalColor: colors.textColorTertiary, highlightColor: colors.textColorLink
                )
            }
        }
        cell.configure(avatarURL: item.conversationAvatarURL, avatarName: item.conversationShowName,
                       title: title, subtitle: subtitle, showDivider: showDivider)
    }
}
