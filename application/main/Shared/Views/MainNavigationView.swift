//
//  MainNavigationView.swift
//  main
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
    func jumpProfileController()

    func showLogUploadView(pressGesture: UILongPressGestureRecognizer)

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
        addSubview(mineCenterBtn)
    }

    private func activateConstraints() {
        iconView.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.equalTo(142)
            make.height.equalTo(32)
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

        LoginEntry.shared.$userModel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userModel in
                self?.updateAvatarImage(urlString: userModel?.avatar)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public

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
