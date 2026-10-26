import Foundation
import AtomicXCore
import SnapKit
import UIKit

public typealias ConversationActionCustomizer = (CustomEditor<ConversationCustomAction>) -> Void

public struct ConversationCustomAction: CustomItem {
    public var ID: String
    public let title: String
    public let dangerous: Bool
    public let action: (ConversationInfo) -> Void

    public init(ID: String, title: String, dangerous: Bool = false, action: @escaping (ConversationInfo) -> Void) {
        self.ID = ID
        self.title = title
        self.dangerous = dangerous
        self.action = action
    }

    public init(title: String, action: @escaping (ConversationInfo) -> Void) {
        self.init(ID: UUID().uuidString, title: title, dangerous: false, action: action)
    }
}

final class ConversationListView: UIView {
    private let impl: ConversationListViewImpl

    init(onConversationClick: @escaping (ConversationInfo) -> Void,
         config: ConversationActionConfig = ConversationActionConfig()) {
        impl = ConversationListViewImpl(onConversationClick: onConversationClick, config: config)
        super.init(frame: .zero)
        addSubview(impl)
        impl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
