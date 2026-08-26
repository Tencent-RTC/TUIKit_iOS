import AtomicXCore

// MARK: - Item Mapping

enum ConversationCreateSupport {

    static func displayName(for contact: ContactInfo) -> String {
        if let remark = contact.friendRemark, !remark.isEmpty { return remark }
        if let nickname = contact.nickname, !nickname.isEmpty { return nickname }
        return contact.userID
    }

    static func orderedListItems(from friendList: [ContactInfo]) -> [AZOrderedListItem] {
        friendList.map { contact in
            AZOrderedListItem(
                userID: contact.userID,
                avatarURL: contact.avatarURL,
                title: displayName(for: contact)
            )
        }
    }

    static func userPickerItems(from friendList: [ContactInfo]) -> [UserPickerItem] {
        friendList.map { contact in
            UserPickerItem(
                userID: contact.userID,
                avatarURL: contact.avatarURL,
                title: displayName(for: contact)
            )
        }
    }
}
