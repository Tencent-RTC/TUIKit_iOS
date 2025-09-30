import AtomicX
import SwiftUI

class AppStyleSettings: ObservableObject {
    @Published var MessageListConfigProtocol: MessageListConfigProtocol = ChatMessageStyle()
    @Published var MessageInputConfigProtocol: MessageInputConfigProtocol = ChatMessageInputStyle()
}
