//
//  DebugAuthView.swift
//  login
//

import UIKit
import AtomicX
import Combine
import Toast_Swift

class DebugAuthView: UIView {

    // MARK: - Dependencies

    let store: DebugAuthStore
    private var cancellables = Set<AnyCancellable>()

    var isUserIdEditable: Bool = true {
        didSet {
            debugConfigView.isUserIdEditable = isUserIdEditable
            backButton.isHidden = isUserIdEditable
        }
    }

    var onBack: (() -> Void)?

    // MARK: - SubViews

    lazy var debugConfigView: DebugConfigView = {
        let view = DebugConfigView()
        return view
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = UIColor("676A70")
        button.isHidden = true
        return button
    }()
    
    // MARK: - Init
    
    init(store: DebugAuthStore) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        isViewReady = true
    }
    
    func constructViewHierarchy() {
        addSubview(debugConfigView)
        addSubview(backButton)
    }

    func activateConstraints() {
        debugConfigView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        backButton.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(9)
            make.leading.equalToSuperview().offset(24)
            make.width.equalTo(16)
            make.height.equalTo(28)
        }
    }
    
    func bindInteraction() {
        debugConfigView.accountTextField.text = store.state.userName

        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)

        debugConfigView.onLoginButtonTapped = { [weak self] in
            guard let self = self else { return }
            self.store.updateUserName(self.debugConfigView.accountTextField.text ?? "")
            self.store.login()
        }
        
        debugConfigView.onUserNameChanged = { [weak self] name in
            self?.store.updateUserName(name)
        }
        
        store.toastPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.makeToast(message)
            }
            .store(in: &cancellables)

        store.$state
            .map(\.isLoginEnabled)
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                self?.debugConfigView.loginButton.isEnabled = isEnabled
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.userName)
            .removeDuplicates()
            .filter { $0.isEmpty }
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.debugConfigView.accountTextField.text = ""
                self.debugConfigView.loginButton.isEnabled = true
                self.hideAllToasts()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions

    @objc private func backButtonTapped() {
        onBack?()
    }

    func setupViewStyle() {}
}
