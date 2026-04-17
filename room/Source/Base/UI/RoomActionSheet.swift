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
//  let actionSheet = RoomActionSheet(
//      message: TUIRoomKitLocalized("ConfirmLeaveRoom"),
//      actions: [
//          RoomActionSheet.Action(title: "Leave Room") { _ in print("Leave") },
//          RoomActionSheet.Action(title: "End Room", titleColor: RoomColors.destructiveActionButtonTitleColor) { _ in print("End") },
//      ]
//  )
//  actionSheet.show(in: self.view, animated: true)
//
//  // Example 2: Custom appearance and per-action font/color
//  var appearance = RoomActionSheet.Appearance()
//  appearance.backgroundColor = .white
//
//  let sheet = RoomActionSheet(
//      actions: [
//          RoomActionSheet.Action(title: "Option A", titleColor: .black, titleFont: RoomFonts.pingFangSCFont(size: 16, weight: .regular)) { _ in },
//          RoomActionSheet.Action(title: "Option B", titleColor: .systemBlue) { _ in },
//      ],
//      appearance: appearance
//  )
//  sheet.show(in: self.view, animated: true)
//  ```
//

import UIKit
import SnapKit
import AtomicX

// MARK: - RoomActionSheet
class RoomActionSheet: UIView, BasePanel, PanelHeightProvider {
    // MARK: - Nested Types
    
    /// Appearance configuration for the action sheet
    struct Appearance {
        var backgroundColor: UIColor = RoomColors.g2
        var separatorColor: UIColor = RoomColors.g3.withAlphaComponent(0.3)
    }
    
    /// Action model
    struct Action {
        let title: String
        let titleColor: UIColor
        let titleFont: UIFont
        let handler: ((Action) -> Void)?
        
        init(title: String,
             titleColor: UIColor = RoomColors.defaultActionButtonTitleColor,
             titleFont: UIFont = RoomFonts.pingFangSCFont(size: 18, weight: .medium),
             handler: ((Action) -> Void)? = nil) {
            self.title = title
            self.titleColor = titleColor
            self.titleFont = titleFont
            self.handler = handler
        }
    }
    
    // MARK: - BasePanel Properties
    weak var parentView: UIView?
    weak var backgroundMaskView: PanelMaskView?
    
    // MARK: - Properties
    private let message: String?
    private let actions: [Action]
    private let appearance: Appearance
    
    private let contentView: UIView = {
        let view = UIView()
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
        let safeAreaBottom = WindowUtils.bottomSafeHeight
        return dropHeight + messageContainerHeight + actionHeight + actionSpacing + safeAreaBottom
    }
    
    // MARK: - Initialization
    init(message: String? = nil, actions: [Action], appearance: Appearance = Appearance()) {
        self.message = message
        self.actions = actions
        self.appearance = appearance
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
                separator.backgroundColor = appearance.separatorColor
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
        contentView.backgroundColor = appearance.backgroundColor
        messageSeparatorView.backgroundColor = appearance.separatorColor
        messageLabel.text = message
    }
    
    private func setupBindings() {
        dropButton.addTarget(self, action: #selector(dropButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Private Methods
    private func createActionButton(for action: Action, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(action.title, for: .normal)
        button.setTitleColor(action.titleColor, for: .normal)
        button.titleLabel?.font = action.titleFont
        button.backgroundColor = appearance.backgroundColor
        button.tag = index
        button.addTarget(self, action: #selector(actionButtonTapped(_:)), for: .touchUpInside)
        
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
