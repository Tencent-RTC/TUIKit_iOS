import UIKit
import AtomicXCore

enum MessageListFloatingEntry {

    case backToLatest

    case newMessages(count: Int, firstMessage: MessageInfo)

    case mention(target: MessageListMentionTarget)

    case backToQuote(returnMessage: MessageInfo)
}

enum MessageListMentionKind {
    case atMe
    case atAll
}

struct MessageListMentionTarget: Equatable {
    let sequence: Int64
    let kind: MessageListMentionKind
}

enum MessageListMentionTargetVisibility {
    case unknown
    case visible
    case hidden
}

enum MessageListFloatingEntryPolicy {

    private static let backToLatestThresholdScreenMultiplier: CGFloat = 1.5

    static func shouldShowBackToLatest(distanceFromLatest: CGFloat, viewportHeight: CGFloat) -> Bool {
        guard viewportHeight > 0, distanceFromLatest > 0 else { return false }
        return distanceFromLatest >= viewportHeight * backToLatestThresholdScreenMultiplier
    }

    static func findOldestMentionTarget(_ groupAtInfoList: [GroupAtInfo]) -> MessageListMentionTarget? {
        guard let oldest = groupAtInfoList.min(by: { $0.msgSeq < $1.msgSeq }) else { return nil }
        let kind: MessageListMentionKind
        switch oldest.atType {
        case .atAll, .atAllAtMe:
            kind = .atAll
        case .atMe:
            kind = .atMe
        }
        return MessageListMentionTarget(sequence: oldest.msgSeq, kind: kind)
    }

    static func iconRotationDegrees(_ entry: MessageListFloatingEntry) -> CGFloat {
        switch entry {
        case .mention:
            return 180
        case .backToLatest, .backToQuote, .newMessages:
            return 0
        }
    }
}

final class MessageListFloatingEntryStateController {
    private var firstNewMessage: MessageInfo?

    private var newMessageCount: Int = 0

    private var mentionTarget: MessageListMentionTarget?

    private var mentionTargetVisibility: MessageListMentionTargetVisibility = .unknown

    private var shouldShowBackToLatest: Bool = false

    private var isBeyondDisplayThreshold: Bool = false

    private var backToQuoteReturnMessage: MessageInfo?

    private var showBackToQuote: Bool = false

    func reset() {
        firstNewMessage = nil
        newMessageCount = 0
        mentionTarget = nil
        mentionTargetVisibility = .unknown
        shouldShowBackToLatest = false
        isBeyondDisplayThreshold = false
        backToQuoteReturnMessage = nil
        showBackToQuote = false
    }

    // MARK: - Quote

    func onQuoteNavigated(returnMessage: MessageInfo) {
        guard !returnMessage.msgID.isEmpty else { return }
        backToQuoteReturnMessage = returnMessage
        showBackToQuote = true
    }

    func currentBackToQuoteReturnMessage() -> MessageInfo? {
        return showBackToQuote ? backToQuoteReturnMessage : nil
    }

    // MARK: - Mention

    func onInitialMentionTarget(_ target: MessageListMentionTarget?,
                                visibility: MessageListMentionTargetVisibility = .hidden) {
        if target == nil || visibility == .visible {
            mentionTarget = nil
            mentionTargetVisibility = .unknown
            return
        }
        mentionTarget = target
        mentionTargetVisibility = visibility
    }

    func onMentionTargetVisibilityChanged(_ visibility: MessageListMentionTargetVisibility) {
        guard mentionTarget != nil else {
            mentionTargetVisibility = .unknown
            return
        }
        if visibility == .visible {
            mentionTarget = nil
            mentionTargetVisibility = .unknown
        } else {
            mentionTargetVisibility = visibility
        }
    }

    func currentMentionTarget() -> MessageListMentionTarget? {
        return mentionTarget
    }

    // MARK: - New Messages / Scroll

    func onNewMessage(_ message: MessageInfo, isLatestCompletelyVisible: Bool) {
        guard !message.msgID.isEmpty else { return }
        if isLatestCompletelyVisible {
            clearNewMessages()
            return
        }
        if firstNewMessage == nil {
            firstNewMessage = message
        }
        newMessageCount += 1
    }

    func onScroll(distanceFromLatest: CGFloat,
                  viewportHeight: CGFloat,
                  isLatestCompletelyVisible: Bool,
                  isReturnMessageCompletelyVisible: Bool) {
        if isReturnMessageCompletelyVisible {
            backToQuoteReturnMessage = nil
            showBackToQuote = false
        }
        if isLatestCompletelyVisible {
            clearNewMessages()
            isBeyondDisplayThreshold = false
            shouldShowBackToLatest = false
            return
        }
        if MessageListFloatingEntryPolicy.shouldShowBackToLatest(
            distanceFromLatest: distanceFromLatest,
            viewportHeight: viewportHeight
        ) {
            isBeyondDisplayThreshold = true
        }
        shouldShowBackToLatest = isBeyondDisplayThreshold
    }

    // MARK: - Current Entry / Consume

    func currentEntry() -> MessageListFloatingEntry? {
        if showBackToQuote, let returnMessage = backToQuoteReturnMessage {
            return .backToQuote(returnMessage: returnMessage)
        }
        if let target = mentionTarget, mentionTargetVisibility != .visible {
            return .mention(target: target)
        }
        if isBeyondDisplayThreshold,
           newMessageCount > 0,
           let newMessage = firstNewMessage,
           !newMessage.msgID.isEmpty {
            return .newMessages(count: newMessageCount, firstMessage: newMessage)
        }
        guard isBeyondDisplayThreshold else { return nil }
        return shouldShowBackToLatest ? .backToLatest : nil
    }

    func consume(_ entry: MessageListFloatingEntry) {
        switch entry {
        case .backToLatest:
            break
        case .newMessages:
            clearNewMessages()
        case .mention:
            mentionTarget = nil
        case .backToQuote:
            backToQuoteReturnMessage = nil
            showBackToQuote = false
        }
    }

    private func clearNewMessages() {
        firstNewMessage = nil
        newMessageCount = 0
    }
}
