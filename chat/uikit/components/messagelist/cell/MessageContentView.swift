import UIKit
import AtomicXCore

enum MessageContentViewFactory {

    static func makeContentView(for kind: MessageContentKind) -> MessageContentView {
        switch kind {
        case .text:
            return MessageTextContentView()
        case .image:
            return MessageImageContentView()
        case .video:
            return MessageVideoContentView()
        case .audio:
            return MessageAudioContentView()
        case .file:
            return MessageFileContentView()
        case .merged:
            return MessageMergedContentView()
        case .call:
            return MessageCallContentView()
        case .custom(let businessID):
            return MessageCellRegistry.shared.makeCustomContentView(for: businessID) ?? MessageFallbackContentView(kind: .unsupported)
        case .face, .unsupported:
            return MessageFallbackContentView(kind: kind)
        }
    }
}
