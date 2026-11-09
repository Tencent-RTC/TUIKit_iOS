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
