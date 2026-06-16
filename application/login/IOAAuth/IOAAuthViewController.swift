//
//  IOAAuthViewController.swift
//  login
//

import UIKit
import Combine
import AtomicX
import Toast_Swift

#if LOGIN_FULL

enum IOAAuthResult {
    case success(LoginResult)
    case failure(LoginError)
    case cancelled
}

///
///   ```
///   let vc = IOAAuthViewController { result in ... }
///   present(vc, animated: true)
///   ```
final class IOAAuthViewController: UIViewController {

    // MARK: - Properties

    private let store: IOAAuthStore
    private let completion: (IOAAuthResult) -> Void
    private var cancellables = Set<AnyCancellable>()
    private var hasFinished = false

    private lazy var fullScreenLoadingView: FullScreenLoadingView = {
        let view = FullScreenLoadingView()
        return view
    }()

    // MARK: - Init

    init(completion: @escaping (IOAAuthResult) -> Void) {
        self.store = IOAAuthStore()
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        setupSubviews()
        bindStore()

        store.onBack = { [weak self] in
            self?.finishWithResult(.cancelled)
        }

        store.showIOALogin(in: view)
    }

    deinit {
        store.ioaService.dismissLoginView()
    }

    // MARK: - Setup

    private func setupSubviews() {
        view.addSubview(fullScreenLoadingView)
        fullScreenLoadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        fullScreenLoadingView.hide()
    }

    private func bindStore() {
        store.toastPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                guard let self = self else { return }
                if let window = self.view.window,
                   let itLoginView = window.subviews.last(where: {
                       NSStringFromClass(type(of: $0)).contains("ITLogin")
                   }) {
                    itLoginView.makeToast(message)
                } else {
                    self.view.makeToast(message)
                }
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

        store.resultPublisher
            .first()
            .receive(on: RunLoop.main)
            .sink { [weak self] result in
                switch result {
                case .success(let loginResult):
                    self?.finishWithResult(.success(loginResult))
                case .failure(let error):
                    self?.finishWithResult(.failure(error))
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Ticket Forwarding

    func handleTicket(_ ticket: String) {
        store.loginWithTicket(ticket)
    }

    // MARK: - Finish

    private func finishWithResult(_ result: IOAAuthResult) {
        guard !hasFinished else { return }
        hasFinished = true

        switch result {
        case .success:
            cancellables.removeAll()
            fullScreenLoadingView.show(with: "")

            //
            //   IOAAuthVC.completion → resultBridge → LoginNavigator.finish
            //   → wrappedCompletion（markLoggedIn）→ SceneDelegate callback
            //
            completion(result)
        case .failure, .cancelled:
            dismiss(animated: true) { [completion] in
                completion(result)
            }
        }
    }
}

#endif
