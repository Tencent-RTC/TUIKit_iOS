//
//  IOAAuthViewController.swift
//  login
//
//  iOA 企业登录容器控制器（模态呈现）
//
//  等价于 Android 的 IOAAuthActivity：
//  将 IOA 登录流程封装在独立的全屏模态 VC 中，
//  避免在导航栈中留下白色容器视图导致白屏闪烁。
//

import UIKit
import Combine
import AtomicX
import Toast_Swift

#if LOGIN_FULL

/// IOA 登录结果（传回给 LoginNavigator）
enum IOAAuthResult {
    case success(LoginResult)
    case failure(LoginError)
    case cancelled
}

/// iOA 企业登录全屏模态控制器
///
/// 职责：
///   1. 拥有并管理 IOAAuthStore 的完整生命周期
///   2. 在自身 view 上展示 ITLogin SDK 的登录视图
///   3. 通过 completion 回调登录结果
///   4. 用户取消（返回按钮）→ dismiss 自身 + 回调 .cancelled
///   5. 登录成功 → dismiss 整个登录流程 + 回调 .success
///   6. 登录失败 → 展示 toast，用户可重试或返回
///
/// 使用方式：
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
        // ITLogin SDK 的视图 (ITLoginUIView) 直接添加在 UIWindow 上，
        // 会覆盖 VC 的 view，toast 必须显示在该视图上才可见。
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
            // 显示全屏加载框，覆盖 ITLogin SDK 移除登录视图后的空白。
            // 取消所有订阅，防止 store 状态变化把 loading 隐藏掉。
            // 加载框将随 VC 整体 dismiss 时一起消失。
            cancellables.removeAll()
            fullScreenLoadingView.show(with: "")

            // 不在此处 dismiss 整个呈现链。
            //
            // 原因：如果从 windowRoot dismiss，completion 只能放在 dismiss handler 中，
            // 导致 wrappedCompletion（markLoggedIn）在 dismiss 之后才执行。
            // 而 dismiss 过程中 EntranceVC.viewWillAppear 会触发开屏动画判定——
            // 此时 hasLoggedIn 仍为 false，动画路径全部失效。
            //
            // 正确做法：直接回调 completion，让结果沿正常链路传播：
            //   IOAAuthVC.completion → resultBridge → LoginNavigator.finish
            //   → wrappedCompletion（markLoggedIn）→ SceneDelegate callback
            //   → playLaunchAnimationOnLoginSuccess（统一 dismiss + 播放动画）
            //
            // SceneDelegate 使用 animated: false dismiss 整个呈现链（loginVC + IOAAuthVC），
            // 视觉上从"加载中"直接切到"开屏动画首帧"，不会闪现底层登录页。
            completion(result)
        case .failure, .cancelled:
            dismiss(animated: true) { [completion] in
                completion(result)
            }
        }
    }
}

#endif
