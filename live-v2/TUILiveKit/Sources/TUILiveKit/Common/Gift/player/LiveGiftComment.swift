import Foundation

/// A client-local comment derived from an AtomicXCore gift event.
///
/// This model is never encoded or sent. Each client independently settles the
/// same gift-event combo before inserting the comment into its local timeline.
struct LiveGiftComment: Equatable {
    let id: String
    let giftID: String
    let giftName: String
    let giftIconURL: String
    let count: UInt
    let senderID: String
    let senderName: String
    let senderLevel: Int

    init(
        id: String = UUID().uuidString,
        giftID: String,
        giftName: String,
        giftIconURL: String,
        count: UInt,
        senderID: String,
        senderName: String,
        senderLevel: Int
    ) {
        self.id = id
        self.giftID = giftID
        self.giftName = giftName
        self.giftIconURL = giftIconURL
        self.count = count
        self.senderID = senderID
        self.senderName = senderName
        self.senderLevel = senderLevel
    }
}
