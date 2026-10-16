import Foundation

struct LiveGiftEvent: Equatable {
    let giftID: String
    let name: String
    let iconURL: String
    let resourceURL: String
    let coins: UInt
    let count: UInt
    let senderID: String
    let senderName: String
    let senderAvatarURL: String

    var comboKey: String { "\(senderID)_\(giftID)" }
    var isAdvanced: Bool { !resourceURL.isEmpty }
}
