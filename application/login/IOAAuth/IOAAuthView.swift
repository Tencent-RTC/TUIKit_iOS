//
//  IOAAuthView.swift
//  login
//

import UIKit
import AtomicX
import Combine
import Toast_Swift

class IOAAuthView: UIView {
    
    // MARK: - Dependencies
    
    let store: IOAAuthStore
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - SubViews
    
    lazy var fullScreenLoadingView: FullScreenLoadingView = {
        let view = FullScreenLoadingView()
        return view
    }()
    
    // MARK: - Init
    
    init(store: IOAAuthStore) {
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
        
        store.showIOALogin(in: self)
    }
    
    func constructViewHierarchy() {
        addSubview(fullScreenLoadingView)
    }
    
    func activateConstraints() {
        fullScreenLoadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func bindInteraction() {
        store.$state
            .map(\.toastMessage)
            .removeDuplicates()
            .sink { [weak self] message in
                guard !message.isEmpty else { return }
                self?.makeToast(message)
            }
            .store(in: &cancellables)
        
        store.$state
            .map(\.isFullScreenLoading)
            .removeDuplicates()
            .sink { [weak self] isFullScreenLoading in
                guard let self = self else { return }
                if isFullScreenLoading {
                    self.fullScreenLoadingView.show(with: self.store.state.fullScreenLoadingMessage)
                } else {
                    self.fullScreenLoadingView.hide()
                }
            }
            .store(in: &cancellables)
    }
    
    func setupViewStyle() {
        fullScreenLoadingView.hide()
    }
    
}
