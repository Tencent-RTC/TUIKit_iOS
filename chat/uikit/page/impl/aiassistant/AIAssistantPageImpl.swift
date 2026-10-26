import AtomicXCore
import SnapKit
import UIKit

internal final class AIAssistantPageImpl: PageImplementation {
    private static let headerHeight: CGFloat = 48

    private static let headerHorizontalInset: CGFloat = 16

    private static let titleFontSize: CGFloat = 17

    private static let titleMaxWidth: CGFloat = 180

    private static let dropdownSize: CGFloat = 16

    private static let dropdownLeadingGap: CGFloat = 2

    private static let callButtonSize: CGFloat = 20

    private static let callIconPointSize: CGFloat = 15

    private static let dropdownIconPointSize: CGFloat = 10

    private static let dividerHeight: CGFloat = 0.5

    private static let bubbleMaxWidthRatio: CGFloat = 0.9

    private static let emptyFontSize: CGFloat = 15

    private static let emptyHorizontalPadding: CGFloat = 32

    private static let emptyVerticalPadding: CGFloat = 48

    private let headerView = UIView()

    private let titleRow = UIControl()

    private let titleLabel = UILabel()

    private let dropdownImageView = UIImageView()

    private let callButton = UIButton(type: .system)

    private let divider = UIView()

    private let emptyLabel = UILabel()

    private let contentContainer = UIView()

    private var agents: [AIAssistantAgent] = []

    private var selectedAgent: AIAssistantAgent?

    private var boundConversationID: String?

    private var fetchGeneration = 0

    private var needsRefreshOnAppearance = false

    private weak var chatPage: ChatPage?

    private var agentLoader: AIAssistantAgentLoader?
    private let config: AIAssistantPageConfig

    internal init(config: AIAssistantPageConfig) {
        self.config = config
        super.init()
    }

    internal func setup(agentLoader: AIAssistantAgentLoader) {
        self.agentLoader = agentLoader
        fetchGeneration += 1
        if isViewLoaded { reloadAgents() }
    }

    internal func onPageVisible() {
        if isViewLoaded { reloadAgents() }
    }

    internal func viewWillAppear() {
        if needsRefreshOnAppearance { reloadAgents() }
    }

    internal func viewDidDisappear() {
        fetchGeneration += 1
        needsRefreshOnAppearance = true
    }

    internal func viewDidLoad() {
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        reloadAgents()
    }

    private func constructViewHierarchy() {
        view.addSubview(headerView)
        headerView.addSubview(titleRow)
        titleRow.addSubview(titleLabel)
        titleRow.addSubview(dropdownImageView)
        headerView.addSubview(callButton)
        view.addSubview(divider)
        view.addSubview(contentContainer)
        view.addSubview(emptyLabel)
    }

    private func activateConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(Self.headerHeight)
        }
        titleRow.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(headerView.snp.bottom).offset(-Self.headerHeight / 2)
            make.leading.greaterThanOrEqualToSuperview().offset(Self.headerHorizontalInset)
            make.trailing.lessThanOrEqualTo(callButton.snp.leading).offset(-Self.headerHorizontalInset)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(Self.titleMaxWidth)
        }
        dropdownImageView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(Self.dropdownLeadingGap)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.dropdownSize)
        }
        callButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.headerHorizontalInset)
            make.centerY.equalTo(headerView.snp.bottom).offset(-Self.headerHeight / 2)
            make.width.height.equalTo(Self.callButtonSize)
        }
        divider.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.dividerHeight)
        }
        contentContainer.snp.makeConstraints { make in
            make.top.equalTo(divider.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Self.emptyHorizontalPadding)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.emptyHorizontalPadding)
        }
    }

    private func bindInteraction() {
        titleRow.addTarget(self, action: #selector(handleTitleRowTapped), for: .touchUpInside)
        callButton.addTarget(self, action: #selector(handleCallTapped), for: .touchUpInside)
        titleRow.isEnabled = false
        titleRow.accessibilityLabel = LocalizedChatString("DemoAISelectAgent")
        callButton.accessibilityLabel = LocalizedChatString("DemoAICallButton")
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = colors.bgColorDefault
        headerView.backgroundColor = colors.bgColorOperate
        divider.backgroundColor = colors.strokeColorPrimary

        titleLabel.text = LocalizedChatString("DemoAIPageTitle")
        titleLabel.font = .systemFont(ofSize: Self.titleFontSize, weight: .bold)
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        dropdownImageView.image = UIImage(systemName: "chevron.down")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.dropdownIconPointSize, weight: .semibold))
            .withRenderingMode(.alwaysTemplate)
        dropdownImageView.tintColor = colors.textColorPrimary
        dropdownImageView.isHidden = true

        callButton.setImage(
            UIImage(systemName: "phone.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: Self.callIconPointSize, weight: .regular))
                .withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        callButton.tintColor = colors.textColorPrimary
        callButton.isHidden = true

        emptyLabel.text = LocalizedChatString("DemoAIAgentsEmpty")
        emptyLabel.font = .systemFont(ofSize: Self.emptyFontSize)
        emptyLabel.textColor = colors.textColorSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
    }

    private func reloadAgents() {
        needsRefreshOnAppearance = false
        fetchGeneration += 1
        let generation = fetchGeneration
        guard let agentLoader else {
            onAgentsLoaded([])
            return
        }
        agentLoader.load { [weak self] agents in
            DispatchQueue.main.async {
                guard let self, generation == self.fetchGeneration else { return }
                self.onAgentsLoaded(agents)
            }
        }
    }

    private func onAgentsLoaded(_ agents: [AIAssistantAgent]) {
        self.agents = agents
        if agents.isEmpty {
            selectedAgent = nil
            boundConversationID = nil
            removeChatPage()
            titleLabel.text = LocalizedChatString("DemoAIPageTitle")
            dropdownImageView.isHidden = true
            titleRow.isEnabled = false
            callButton.isHidden = true
            contentContainer.isHidden = true
            emptyLabel.isHidden = false
            return
        }
        emptyLabel.isHidden = true
        contentContainer.isHidden = false
        callButton.isHidden = false
        let currentID = selectedAgent?.id
        let next = agents.first { $0.id == currentID } ?? agents[0]
        bindAgent(next)
    }

    private func bindAgent(_ agent: AIAssistantAgent) {
        selectedAgent = agent
        titleLabel.text = agent.displayName
        let canSwitch = agents.count > 1
        dropdownImageView.isHidden = !canSwitch
        titleRow.isEnabled = canSwitch
        if boundConversationID == agent.conversationID, chatPage != nil {
            return
        }
        let generation = fetchGeneration
        AgentWelcomeInserter.insertIfConversationEmpty(agent) { [weak self] in
            guard let self, generation == self.fetchGeneration,
                  self.selectedAgent?.id == agent.id,
                  self.selectedAgent?.conversationID == agent.conversationID else { return }
            self.embedChatPage(for: agent)
            self.boundConversationID = agent.conversationID
        }
    }

    private func removeChatPage() {
        guard let existing = chatPage else { return }
        existing.willMove(toParent: nil)
        existing.view.removeFromSuperview()
        existing.removeFromParent()
        chatPage = nil
    }

    private func embedChatPage(for agent: AIAssistantAgent) {
        guard let owner else { return }
        removeChatPage()
        var conversation = ConversationInfo(conversationID: agent.conversationID)
        conversation.type = .c2c
        conversation.title = agent.displayName
        var listConfig = ChatMessageListConfig(
            isShowLeftAvatar: false,
            isShowRightAvatar: false,
            bubbleMaxWidthRatio: Self.bubbleMaxWidthRatio,
            enableChatbotReplyPlaceholder: config.enableChatbotReplyPlaceholder,
            streamingMaxCharactersPerSecond: config.streamingMaxCharactersPerSecond
        )
        listConfig.addMessageExclusion { message in
            RobotControlMessages.isControlMessage(message)
        }
        let inputConfig = ChatMessageInputConfig(
            isShowMore: false,
            isShowEmoji: false,
            isShowVideoCall: false,
            isShowAudioCall: false,
            enableRealtimeVoiceToText: config.enableRealtimeVoiceToText,
            enableSendRecordedVoice: config.enableSendRecordedVoice
        )
        let page = ChatPage(
            conversation: conversation,
            messageListConfig: listConfig,
            messageInputConfig: inputConfig,
            isShowMoreButton: false,
            showsNavigationBar: false
        )
        owner.addChild(page)
        contentContainer.addSubview(page.view)
        page.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        page.didMove(toParent: owner)
        chatPage = page
    }

    @objc private func handleTitleRowTapped() {
        showAgentPicker()
    }

    @objc private func handleCallTapped() {
        guard let agent = selectedAgent else { return }
        present(AICallViewController(robotUserID: agent.imUserId, config: config.callConfig), animated: true)
    }

    private func showAgentPicker() {
        guard agents.count > 1 else { return }
        let sheet = AIAgentPickerSheet(agentNames: agents.map { $0.displayName }) { [weak self] index in
            guard let self = self, self.agents.indices.contains(index) else { return }
            self.bindAgent(self.agents[index])
        }
        sheet.modalPresentationStyle = .overFullScreen
        present(sheet, animated: false)
    }
}
