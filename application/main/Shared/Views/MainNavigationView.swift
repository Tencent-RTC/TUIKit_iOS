//
//  MainNavigationView.swift
//  main
//
//  顶部导航栏（Logo + 头像按钮）— 从旧版 MainNavigationView.swift 迁移
//
//  变更说明：
//    - 移除 `import BusinessService` 和 `import AtomicXCore` 依赖
//    - 头像更新改为监听 LoginEntry.shared.$userModel 变更自动刷新
//    - 其他 UI 布局完全保持旧版不变
//

import UIKit
import Combine
import Kingfisher
import TUICore
import SnapKit
import Login
import AtomicX

// MARK: - Delegate

protocol MainNavigationViewDelegate: NSObjectProtocol {
    /// 点击头像，跳转个人中心
    func jumpProfileController()

    /// 长按 Logo 2 秒，触发日志上传
    func showLogUploadView(pressGesture: UILongPressGestureRecognizer)

    /// 点击 Logo，取消日志上传
    func dismissLogUploadView(tapGesture: UITapGestureRecognizer)
}

// MARK: - View

class MainNavigationView: UIView {

    weak var delegate: MainNavigationViewDelegate?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Elements

    private lazy var iconView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.isUserInteractionEnabled = true
        imageView.image = UIImage(named: Self.mainLogoImageName())
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    private lazy var mineCenterBtn: UIButton = {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = ThemeStore.shared.borderRadius.radius16
        button.clipsToBounds = true
        return button
    }()

    private lazy var sdkAppIdTipLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = ThemeStore.shared.colorTokens.textColorTertiary
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    // MARK: - Lifecycle

    private var isViewReady = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true

        backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    // MARK: - Setup

    private func constructViewHierarchy() {
        addSubview(iconView)
        addSubview(sdkAppIdTipLabel)
        addSubview(mineCenterBtn)
    }

    private func activateConstraints() {
        iconView.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.equalTo(142)
            make.height.equalTo(32)
        }

        sdkAppIdTipLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(iconView.snp.right).offset(8)
            make.right.lessThanOrEqualTo(mineCenterBtn.snp.left).offset(-8)
        }

        mineCenterBtn.snp.makeConstraints { make in
            make.right.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
    }

    private func bindInteraction() {
        mineCenterBtn.addTarget(self, action: #selector(goMine(sender:)), for: .touchUpInside)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(tapGesture:)))
        iconView.addGestureRecognizer(tapGesture)

        let pressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(pressGesture:)))
        pressGesture.minimumPressDuration = 2.0
        pressGesture.numberOfTouchesRequired = 1
        iconView.addGestureRecognizer(pressGesture)

        tapGesture.require(toFail: pressGesture)

        // 监听用户信息变更，自动更新头像
        LoginEntry.shared.$userModel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userModel in
                self?.updateAvatarImage(urlString: userModel?.avatar)
                self?.updateSdkAppIdTip()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public

    /// 更新用户头像
    ///
    /// - Parameter urlString: 头像 URL 字符串，传 nil 则使用默认头像
    func updateAvatarImage(urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            self.mineCenterBtn.setBackgroundImage(UIImage(named: "default_avatar"), for: .normal)
            return
        }
        self.mineCenterBtn.kf.setBackgroundImage(
            with: url,
            for: .normal,
            placeholder: UIImage(named: "default_avatar")
        )
    }

    private func updateSdkAppIdTip() {
        if let credentials = LoginEntry.shared.hiddenCredentials {
            sdkAppIdTipLabel.text = "SDKAppID: \(credentials.sdkAppId)"
            sdkAppIdTipLabel.isHidden = false
        } else {
            sdkAppIdTipLabel.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func handleTap(tapGesture: UITapGestureRecognizer) {
        delegate?.dismissLogUploadView(tapGesture: tapGesture)
    }

    @objc private func handleLongPress(pressGesture: UILongPressGestureRecognizer) {
        delegate?.showLogUploadView(pressGesture: pressGesture)
    }

    @objc private func goMine(sender: UIButton) {
        delegate?.jumpProfileController()
    }

    // MARK: - Logo

    /// 根据当前语言返回对应的 Logo 图片名
    private static func mainLogoImageName() -> String {
        guard let language = TUIGlobalization.tk_localizableLanguageKey() else {
            return "main_english_logo"
        }

        if language.contains("zh-Hans") {
            return "main_simplified_chinese_logo"
        } else if language.contains("zh-Hant") {
            return "main_traditional_chinese_logo"
        } else {
            return "main_english_logo"
        }
    }
}
