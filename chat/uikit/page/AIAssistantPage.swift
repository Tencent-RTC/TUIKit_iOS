import UIKit

public struct AIAssistantPageConfig {
    public var userStreamingMaxCharactersPerSecond: Double? = nil
    public var userEnableChatbotReplyPlaceholder: Bool? = nil
    public var userEnableRealtimeVoiceToText: Bool? = nil
    public var userEnableSendRecordedVoice: Bool? = nil
    public var userCallConfig: AICallConfig? = nil
}

public final class AIAssistantPageViewController: UIViewController {
    private let implementation: AIAssistantPageImpl

    public init(config: AIAssistantPageConfig? = nil) {
        implementation = AIAssistantPageImpl(config: config ?? AIAssistantPageConfig())
        super.init(nibName: nil, bundle: nil)
        implementation.owner = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setup(agentLoader: AIAssistantAgentLoader) {
        implementation.setup(agentLoader: agentLoader)
    }

    public func onPageVisible() {
        implementation.onPageVisible()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        implementation.viewDidLoad()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        implementation.viewWillAppear()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        implementation.viewDidDisappear()
    }
}

public struct AIAssistantAgent {
    public let id: String
    public let name: String
    public let welcome: String
    public let imUserId: String
    public let imNickname: String

    public init(id: String, name: String, welcome: String, imUserId: String, imNickname: String) {
        self.id = id
        self.name = name
        self.welcome = welcome
        self.imUserId = imUserId
        self.imNickname = imNickname
    }

    public var conversationID: String {
        return "c2c_\(imUserId)"
    }

    public var displayName: String {
        if !imNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return imNickname }
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return name }
        return imUserId
    }
}

public protocol AIAssistantAgentLoader {
    func load(onResult: @escaping ([AIAssistantAgent]) -> Void)
}
