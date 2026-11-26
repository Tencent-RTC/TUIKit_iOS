import AtomicXCore

extension UserProfile {

    public var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        return userID
    }
}

extension RoomParticipant {

    public var displayName: String {
        if !nameCard.isEmpty { return nameCard }
        if !userName.isEmpty { return userName }
        return userID
    }
}

extension RoomUser {

    public var displayName: String {
        userName.isEmpty ? userID : userName
    }
}

extension DeviceRequestInfo {

    public var senderName: String {
        if !senderNameCard.isEmpty { return senderNameCard }
        if !senderUserName.isEmpty { return senderUserName }
        return senderUserID
    }
}

extension ParticipantRole {

    func canManage(_ target: ParticipantRole) -> Bool {
        switch self {
        case .owner: return true
        case .admin: return target == .generalUser
        case .generalUser: return false
        }
    }
}
