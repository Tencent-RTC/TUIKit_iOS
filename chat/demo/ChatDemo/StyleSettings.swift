import AtomicX
import SwiftUI

class AppStyleSettings: ObservableObject {
    @Published var MessageListConfigProtocol: MessageListConfigProtocol = ChatMessageListConfig()
    @Published var MessageInputConfigProtocol: MessageInputConfigProtocol = ChatMessageInputConfig()
}
