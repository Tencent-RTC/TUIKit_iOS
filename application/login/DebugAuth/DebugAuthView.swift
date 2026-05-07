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
    
    // MARK: - SubViews
    
    lazy var debugConfigView: DebugConfigView = {
        let view = DebugConfigView()
        return view
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
    }
    
    func activateConstraints() {
        debugConfigView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func bindInteraction() {
        debugConfigView.accountTextField.text = store.state.userName
        
        debugConfigView.onLoginButtonTapped = { [weak self] in
            guard let self = self else { return }
            self.store.updateUserName(self.debugConfigView.accountTextField.text ?? "")
            self.store.login()
        }
        
        debugConfigView.onUserNameChanged = { [weak self] name in
            self?.store.updateUserName(name)
        }
        
        store.$state
            .map(\.toastMessage)
            .removeDuplicates()
            .sink { [weak self] message in
                guard !message.isEmpty else { return }
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
    
    func setupViewStyle() {}
}
