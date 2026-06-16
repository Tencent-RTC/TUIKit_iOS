//
//  IOAAuthStore.swift
//  login
//
//  iOA 企业登录 Store
//

import UIKit
import Combine

class IOAAuthStore: LoginSubStore {

    // MARK: - State

    @Published private(set) var state = IOAAuthState()

    // MARK: - LoginSubStore

    private let resultSubject = PassthroughSubject<Result<LoginResult, LoginError>, Never>()
    var resultPublisher: AnyPublisher<Result<LoginResult, LoginError>, Never> {
        resultSubject.eraseToAnyPublisher()
    }

    // MARK: - Toast Event

    private let toastSubject = PassthroughSubject<String, Never>()
    var toastPublisher: AnyPublisher<String, Never> { toastSubject.eraseToAnyPublisher() }

    // MARK: - Dependencies

    let ioaService = IOAService()
    private let networkService = LoginNetworkService()
    private var logoutCancellable: AnyCancellable?

    /// 保存父视图引用，后端失败时需要重新展示 IOA 登录视图
    private weak var parentView: UIView?

    /// 返回上一页的回调
    var onBack: (() -> Void)?

    // MARK: - Init

    init() {
        logoutCancellable = subscribeLogout()
    }

    // MARK: - LoginSubStore

    func resetState() {
        state = IOAAuthState()
    }

    // MARK: - Public Methods

    /// 展示 iOA 登录视图
    func showIOALogin(in parentView: UIView?) {
        self.parentView = parentView
        state.isLoading = true

        ioaService.setOnBackButtonTapped { [weak self] in
            self?.state.isLoading = false
            self?.onBack?()
        }

        ioaService.showLoginView(in: parentView)
    }

    /// iOA 票据登录
    func loginWithTicket(_ ticket: String) {
        state.isFullScreenLoading = true
        state.fullScreenLoadingMessage = LoginLocalize("login_ioa_loading")

        networkService.loginByMOA(ticket: ticket) { [weak self] result in
            guard let self = self else { return }
            self.state.isFullScreenLoading = false
            self.state.isLoading = false
            switch result {
            case .success(let loginResult):
                self.resultSubject.send(.success(loginResult))
            case .failure(let error):
                // SDK 认证成功后会自动隐藏其登录视图，后端失败时需要重新展示
                self.ioaService.showLoginView(in: self.parentView)
                self.toastSubject.send(error.message)
            }
        }
    }

    /// 返回上一页
    func goBack() {
        ioaService.dismissLoginView()
        onBack?()
    }
}

// MARK: - State

public struct IOAAuthState {
    public var isLoading: Bool = false
    public var isFullScreenLoading: Bool = false
    public var fullScreenLoadingMessage: String = ""
}
