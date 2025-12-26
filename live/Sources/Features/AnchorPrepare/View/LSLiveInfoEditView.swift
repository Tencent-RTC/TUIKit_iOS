//
//  LSLiveInfoEditView.swift
//  Pods
//
//  Created by jeremiawang on 2024/11/18.
//

import Foundation
import Kingfisher
import SnapKit
import TUICore
import Combine
import RTCCommon
import AtomicXCore
import AtomicX

class LSLiveInfoEditView: UIView {
    private var cancellableSet = Set<AnyCancellable>()
    private var state: PrepareState
    private weak var popupViewController: AtomicPopover?

    lazy var modeSelectionModel: PrepareSelectionModel = {
        let model = PrepareSelectionModel()
        model.leftIcon = internalImage("live_mode_icon")
        model.midText = .localizedReplace(.modeText, replace: state.privacyMode.getString())
        model.rightIcon = internalImage("live_selection_arrow_icon")
        return model
    }()
    
    lazy var templateSelectionModel: PrepareSelectionModel = {
        let model = PrepareSelectionModel()
        model.leftIcon = internalImage("live_mode_icon")
        model.midText = .templateText.appending(state.templateMode.toString())
        model.rightIcon = internalImage("live_selection_arrow_icon")
        return model
    }()
    
    private lazy var coverButtonView: UIButton = {
        let view = UIButton()
        view.backgroundColor = .g5
        view.showsTouchWhenHighlighted = false
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        view.addTarget(self, action: #selector(coverButtonClick), for: .touchUpInside)
        view.kf.setImage(with: URL(string: state.coverUrl), for: .normal, placeholder: UIImage.placeholderImage)
        
        let label = AtomicLabel(.editCoverTitle) { theme in
            let color = theme.tokens.color.textColorPrimary
            let bg = theme.tokens.color.bgColorTagMask
            let font = theme.tokens.typography.Regular14
            let appearance = LabelAppearance(textColor: color,
                                   backgroundColor: bg,
                                   font: font,
                                   cornerRadius: 0.0)
            return appearance
        }

        label.textAlignment = .center
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.width.equalTo(view)
            make.height.equalTo(22.scale375())
            make.left.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        return view
    }()

    private lazy var inputTextField: UITextField = {
        let view = UITextField(frame: .zero)
        view.returnKeyType = .done
        view.font = UIFont(name: "PingFangSC-Regular", size: 18)
        view.textColor = .white
        let attributes = [NSAttributedString.Key.font: UIFont.customFont(ofSize: 16),
                          NSAttributedString.Key.foregroundColor: UIColor.tui_color(withHex: "BBBBBB"),]
        view.attributedPlaceholder = NSAttributedString(string: .editPlaceholderText,
                                                        attributes: attributes)
        view.delegate = self
        return view
    }()

    private lazy var inputBgView: UIView = {
        let view = UIView()
        let editIcon = UIButton()
        editIcon.addTarget(self, action: #selector(editIconClick), for: .touchUpInside)
        editIcon.setBackgroundImage(internalImage("live_edit_icon"), for: .normal)
        view.addSubview(editIcon)
        editIcon.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(16.scale375())
            make.height.equalTo(16.scale375())
        }

        view.addSubview(inputTextField)
        inputTextField.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalTo(editIcon.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.height.equalToSuperview()
        }

        let lineView = UIView()
        lineView.backgroundColor = .flowKitWhite.withAlphaComponent(0.3)
        view.addSubview(lineView)
        lineView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(1)
            make.top.equalTo(inputTextField.snp.bottom)
        }

        return view
    }()

    private lazy var modeBgView: PrepareSelectionButton = {
        let view = PrepareSelectionButton(model: modeSelectionModel)
        view.addTarget(self, action: #selector(modeSelectionClick), for: .touchUpInside)
        return view
    }()
    
    init(state: inout PrepareState) {
        self.state = state
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        subscribeRoomState()
        initialize()
    }
    
    private func initialize() {
        let roomName = state.roomName
        inputTextField.text = roomName
    }
}

// MARK: Layout
extension LSLiveInfoEditView {
    func constructViewHierarchy() {
        layer.cornerRadius = 16
        layer.masksToBounds = true
        backgroundColor = .g2.withAlphaComponent(0.4)
        addSubview(coverButtonView)
        addSubview(inputBgView)
        addSubview(modeBgView)
    }

    func activateConstraints() {
        coverButtonView.snp.makeConstraints { make in
            make.width.equalTo(72.scale375())
            make.height.equalTo(96.scale375())
            make.leading.equalToSuperview().offset(8)
            make.top.equalToSuperview().offset(8)
        }
        inputBgView.snp.makeConstraints { make in
            make.leading.equalTo(coverButtonView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(12)
            make.top.equalToSuperview().offset(8)
            make.height.equalTo(36.scale375())
        }

        modeBgView.snp.makeConstraints { make in
            make.leading.equalTo(coverButtonView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(12)
            make.top.equalTo(inputBgView.snp.bottom).offset(14)
            make.height.equalTo(20.scale375())
        }
    }
}

// MARK: Action
extension LSLiveInfoEditView {
    @objc func coverButtonClick() {
        inputTextField.resignFirstResponder()
        let imageConfig = LSSystemImageFactory.getImageAssets()
        let systemImageSelectionPanel = LSSystemImageSelectionPanel(configs: imageConfig, state: &state)
        systemImageSelectionPanel.backButtonClickClosure = { [weak self] in
            guard let self = self else { return }
            self.popupViewController?.dismiss(animated: false)
        }
        
        let config = AtomicPopover.AtomicPopoverConfig(
            position: .bottom,
            height: .wrapContent,
            animation: .slideFromBottom,
            onBackdropTap: { [weak self] in
                self?.popupViewController?.dismiss(animated: false)
            }
        )
        
        let popover = AtomicPopover(contentView: systemImageSelectionPanel, configuration: config)
        guard let presentingViewController = getCurrentViewController() else { return }
        presentingViewController.present(popover, animated: false)
        self.popupViewController = popover
    }

    @objc func editIconClick() {
        inputTextField.becomeFirstResponder()
    }

    @objc func modeSelectionClick() {
        inputTextField.resignFirstResponder()
        showModeSelection()
    }

    private func showModeSelection() {
        var items: [AlertButtonConfig] = []
        for mode in LiveStreamPrivacyStatus.allCases {
            let item = AlertButtonConfig(text: mode.getString(), type: .primary) { [weak self] _ in
                guard let self = self else { return }
                state.privacyMode = mode
                self.popupViewController?.dismiss(animated: false)
            }
            items.append(item)
        }
        
        let alertConfig = AlertViewConfig(items: items)
        let alertView = AtomicAlertView(config: alertConfig)
        
        let config = AtomicPopover.AtomicPopoverConfig(
            position: .bottom,
            height: .wrapContent,
            animation: .slideFromBottom,
            onBackdropTap: { [weak self] in
                self?.popupViewController?.dismiss(animated: false)
            }
        )
        
        let popover = AtomicPopover(contentView: alertView, configuration: config)
        guard let presentingViewController = getCurrentViewController() else { return }
        presentingViewController.present(popover, animated: false)
        self.popupViewController = popover
    }
}

// MARK: UITextFieldDelegate
extension LSLiveInfoEditView: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let maxCount = 100
        guard let textFieldText = textField.text,
              let rangeOfTextToReplace = Range(range, in: textFieldText) else {
            return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        if substringToReplace.utf8.count > 0 && string.utf8.count == 0 {
            return true
        }
        let count = textFieldText.utf8.count - substringToReplace.utf8.count + string.utf8.count

        let res = count <= maxCount
        return res
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        var roomName: String = LoginStore.shared.state.value.loginUserInfo?.nickname ?? ""
        if let name = textField.text, !name.isEmpty {
            roomName = name
        }
        textField.text = roomName
        state.roomName = roomName
    }
}

extension LSLiveInfoEditView {
    private func subscribeRoomState() {
        state.$coverUrl
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] url in
                guard let self = self else { return }
                self.coverButtonView.kf.setImage(with: URL(string: url),
                                                 for: .normal,
                                                 placeholder: UIImage.placeholderImage)
            }
            .store(in: &cancellableSet)
        
        state.$privacyMode
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                guard let self = self else { return }
                let value = String.localizedReplace(.modeText, replace: mode.getString())
                self.modeSelectionModel.midText = value
            }
            .store(in: &cancellableSet)
        
        state.$templateMode
            .receive(on: RunLoop.main)
            .sink { [weak self] templateMode in
                guard let self = self else { return }
                templateSelectionModel.midText = .templateText.appending(templateMode.toString())
            }
            .store(in: &cancellableSet)
    }
}

private extension String {
    static let editCoverTitle = internalLocalized("Set Cover")
    static let editPlaceholderText = internalLocalized("Please enter room name")
    static let categoryText = internalLocalized("Live Category:xxx")
    static let modeText = internalLocalized("Live Mode:xxx")
    static let templateText  = internalLocalized("Template:")
}
