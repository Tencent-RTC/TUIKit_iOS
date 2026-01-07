//
//  RoomActionSheet.swift
//  TUIRoomKit
//
//  Created by AI Assistant on 2025/11/25.
//
//  A reusable action sheet component with customizable actions.
//
//  Usage:
//  ```swift
//  // Example 1: Simple action sheet with message
//  let action1 = RoomActionSheet.Action(
//      title: TUIRoomKitLocalized("LeaveRoom"),
//      style: .default,
//      handler: { _ in
//          print("Leave room")
//      }
//  )
//  
//  let action2 = RoomActionSheet.Action(
//      title: TUIRoomKitLocalized("EndRoom"),
//      style: .destructive,
//      handler: { _ in
//          print("End room")
//      }
//  )
//  
//  let actionSheet = RoomActionSheet(
//      message: TUIRoomKitLocalized("ConfirmLeaveRoom"),
//      actions: [action1, action2]
//  )
//  actionSheet.show(in: self.view, animated: true)
//  
//  // Example 2: Action sheet without message
//  let shareAction = RoomActionSheet.Action(
//      title: TUIRoomKitLocalized("ShareRoom"),
//      style: .default,
//      handler: { _ in
//          print("Share room")
//      }
//  )
//  
//  let inviteAction = RoomActionSheet.Action(
//      title: TUIRoomKitLocalized("InviteMembers"),
//      style: .default,
//      handler: { _ in
//          print("Invite members")
//      }
//  )
//  
//  let sheet = RoomActionSheet(actions: [shareAction, inviteAction])
//  sheet.show(in: self.view, animated: true)
//  
//  // Example 3: Custom text color (using action styles)
//  let normalAction = RoomActionSheet.Action(
//      title: "Normal Action",
//      style: .default  // Uses brand color (blue)
//  )
//  
//  let dangerAction = RoomActionSheet.Action(
//      title: "Danger Action",
//      style: .destructive  // Uses error color (red)
//  )
//  
//  let cancelAction = RoomActionSheet.Action(
//      title: "Cancel Action",
//      style: .cancel  // Uses primary text color (gray)
//  )
//  ```
//

import UIKit
import SnapKit

// MARK: - RoomActionSheet
class RoomActionSheet: UIView, BasePanel, PanelHeightProvider {
    // MARK: - Nested Types
    
    /// Action style
    enum ActionStyle {
        case `default`
        case destructive
        case cancel
    }
    
    /// Action model
    struct Action {
        let title: String
        let style: ActionStyle
        let handler: ((Action) -> Void)?
        
        init(title: String, 
             style: ActionStyle = .default,
             handler: ((Action) -> Void)? = nil) {
            self.title = title
            self.style = style
            self.handler = handler
        }
    }
    
    // MARK: - BasePanel Properties
    weak var parentView: UIView?
    var backgroundMaskView: PanelMaskView?
    
    // MARK: - Properties
    private let message: String?
    private let actions: [Action]
    
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()
    
    private let messageContainerView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var dropButton: UIButton = {
        let button = UIButton()
        button.setImage(ResourceLoader.loadImage("room_drop_arrow"), for: .normal)
        button.imageView?.contentMode = .center
        return button
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        label.textColor = RoomColors.actionSheetTitleColor
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var messageSeparatorView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g3.withAlphaComponent(0.3)
        return view
    }()
    
    private lazy var actionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()
    
    // MARK: - PanelHeightProvider
    var panelHeight: CGFloat {
        let dropHeight: CGFloat = 22
        let messageContainerHeight: CGFloat = message != nil ? 46 : 0
        let actionHeight: CGFloat = CGFloat(actions.count) * 56
        let actionSpacing: CGFloat = CGFloat(actions.count - 1) * 1
        let safeAreaBottom = safeAreaInsets.bottom
        return dropHeight + messageContainerHeight + actionHeight + actionSpacing + safeAreaBottom
    }
    
    // MARK: - Initialization
    init(message: String? = nil, actions: [Action]) {
        self.message = message
        self.actions = actions
        super.init(frame: .zero)
        
        // Fix AutoLayout constraint conflict
        translatesAutoresizingMaskIntoConstraints = false
        
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        addSubview(contentView)
        contentView.addSubview(dropButton)
        
        if message != nil {
            contentView.addSubview(messageContainerView)
            messageContainerView.addSubview(messageLabel)
            messageContainerView.addSubview(messageSeparatorView)
        }
        
        contentView.addSubview(actionStackView)
        
        // Add action buttons
        for (index, action) in actions.enumerated() {
            let actionButton = createActionButton(for: action, index: index)
            actionStackView.addArrangedSubview(actionButton)
            
            // Add separator between actions
            if index < actions.count - 1 {
                let separator = UIView()
                separator.backgroundColor = RoomColors.g3.withAlphaComponent(0.3)
                actionStackView.addArrangedSubview(separator)
                separator.snp.makeConstraints { make in
                    make.height.equalTo(1)
                }
            }
        }
    }
    
    private func setupConstraints() {
        // Content view
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        dropButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
        }
        
        // Message label (if exists)
        if message != nil {
            messageContainerView.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.top.equalTo(dropButton.snp.bottom)
                make.height.equalTo(46)
            }
            
            messageLabel.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalToSuperview().offset(16)
                make.right.equalToSuperview().offset(-16)
            }
            
            messageSeparatorView.snp.makeConstraints { make in
                make.height.equalTo(1)
                make.left.right.equalToSuperview()
                make.bottom.equalToSuperview()
            }
            
            actionStackView.snp.makeConstraints { make in
                make.top.equalTo(messageContainerView.snp.bottom)
                make.left.right.equalToSuperview()
                make.height.equalTo(CGFloat(actions.count) * 56 + CGFloat(actions.count - 1) * 1)
            }
        } else {
            actionStackView.snp.makeConstraints { make in
                make.top.equalTo(dropButton.snp.bottom)
                make.left.right.equalToSuperview()
                make.height.equalTo(CGFloat(actions.count) * 56 + CGFloat(actions.count - 1) * 1)
            }
        }
    }
    
    private func setupStyles() {
        backgroundColor = .clear
        messageLabel.text = message
    }
    
    private func setupBindings() {
        dropButton.addTarget(self, action: #selector(dropButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Private Methods
    private func createActionButton(for action: Action, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(action.title, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 18, weight: .medium)
        button.backgroundColor = RoomColors.g2
        button.tag = index
        button.addTarget(self, action: #selector(actionButtonTapped(_:)), for: .touchUpInside)
        
        // Set button color based on style
        switch action.style {
        case .default:
            button.setTitleColor(RoomColors.defaultActionButtonTitleColor, for: .normal)
        case .destructive:
            button.setTitleColor(RoomColors.destructiveActionButtonTitleColor, for: .normal)
        case .cancel:
            button.setTitleColor(RoomColors.brandBlue, for: .normal)
        }
        
        button.snp.makeConstraints { make in
            make.height.equalTo(56)
        }
        
        return button
    }
    
    // MARK: - Actions
    @objc private func dropButtonTapped() {
        dismiss()
    }
    
    @objc private func actionButtonTapped(_ sender: UIButton) {
        let action = actions[sender.tag]
        
        dismiss(animated: true) {
            action.handler?(action)
        }
    }
}
