//
//  MiniProgramViewController.swift
//
//  `TMFMiniAppSDKManager.miniAppSdkDelegate`。
//

#if RTCUBE_OVERSEAS

import UIKit
import SnapKit
import TCMPPSDK
import TCMPPExtScanCode

// MARK: - MiniProgramViewController

final class MiniProgramViewController: UIViewController {

    // MARK: - Hidden Debug Switch

    private var isScanVisible: Bool = false

    private enum MiniProgram: CaseIterable {
        case social
        case education
        case financial
        case clawMachine

        var appId: String {
            switch self {
            case .social:       return "mpxr4rw440r5qjvl"
            case .education:    return "mpyj90mwez4ow04p"
            case .financial:    return "mpwyrvbojp8xtanz"
            case .clawMachine:  return "mppdg601fbg5k69s"
            }
        }

        var appName: String {
            switch self {
            case .social:       return "1v1 Social"
            case .education:    return "education"
            case .financial:    return "financial"
            case .clawMachine:  return "Claw Machine"
            }
        }

        var iconAssetName: String {
            switch self {
            case .social:       return "module_mini_program_1v1_social"
            case .education:    return "module_mini_program_online_education"
            case .financial:    return "module_mini_program_financial_service"
            case .clawMachine:  return "module_mini_program_claw_machine"
            }
        }

        var localizedKey: String {
            switch self {
            case .social:       return "main_mini_program_1v1_social"
            case .education:    return "main_mini_program_online_education"
            case .financial:    return "main_mini_program_financial_service"
            case .clawMachine:  return "main_mini_program_claw_machine"
            }
        }
    }

    // MARK: - Properties

    private var availablePrograms: [MiniProgram] = []
    private let availabilityGroup = DispatchGroup()

    // MARK: - UI Elements

    private lazy var headerImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "module_mini_program_main")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "module_mini_program_ic_back"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = MainLocalize("main_mini_program_title")
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textColor = UIColor(red: 0x19 / 255.0, green: 0x1D / 255.0, blue: 0x27 / 255.0, alpha: 1)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = MainLocalize("main_mini_program_content")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(red: 0x72 / 255.0, green: 0x7A / 255.0, blue: 0x8A / 255.0, alpha: 1)
        label.numberOfLines = 0
        return label
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()

    private lazy var scanButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Scan", for: .normal)
        button.setTitleColor(UIColor(red: 0x4E / 255.0, green: 0x54 / 255.0, blue: 0x61 / 255.0, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        return button
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private let contentView = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0xF2 / 255.0, green: 0xF5 / 255.0, blue: 0xFC / 255.0, alpha: 1)
        constructViewHierarchy()
        activateConstraints()
        checkMiniProgramAvailability()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    // MARK: - View Setup

    private func constructViewHierarchy() {
        view.addSubview(headerImageView)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(stackView)
        view.addSubview(backButton)

        titleLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTitleTap))
        tap.numberOfTapsRequired = 5
        titleLabel.addGestureRecognizer(tap)
    }

    private func activateConstraints() {
        headerImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        backButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(8)
            make.leading.equalTo(view.safeAreaLayoutGuide.snp.leading).offset(16)
            make.width.height.equalTo(40)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(244)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(36)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().inset(40)
        }
    }

    // MARK: - Scan Entry Activation

    private func activateScanEntry() {
        guard scanButton.superview == nil else { return }

        scanButton.snp.makeConstraints { make in
            make.height.equalTo(64)
        }
        stackView.addArrangedSubview(scanButton)

        UIView.animate(withDuration: 0.2) {
            self.contentView.layoutIfNeeded()
        }
    }

    // MARK: - Availability Check

    private func checkMiniProgramAvailability() {
        var availableSet: Set<String> = []
        for program in MiniProgram.allCases {
            availabilityGroup.enter()
            TMFMiniAppSDKManager.sharedInstance().searchApplets(withName: program.appName) { [weak self] results, _ in
                DispatchQueue.main.async {
                    defer { self?.availabilityGroup.leave() }
                    if let results = results, !results.isEmpty {
                        availableSet.insert(program.appId)
                    } else {
                        debugPrint("[MiniProgram] \(program.appName) unavailable, hidden")
                    }
                }
            }
        }
        availabilityGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.availablePrograms = MiniProgram.allCases.filter { availableSet.contains($0.appId) }
            self.rebuildItems()
        }
    }

    // MARK: - Items

    private func rebuildItems() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for program in availablePrograms {
            stackView.addArrangedSubview(makeItemView(for: program))
        }
    }

    private func makeItemView(for program: MiniProgram) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 8
        container.clipsToBounds = true

        let iconView = UIImageView()
        iconView.image = UIImage(named: program.iconAssetName)
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = MainLocalize(program.localizedKey)
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = UIColor(red: 0x4E / 255.0, green: 0x54 / 255.0, blue: 0x61 / 255.0, alpha: 1)

        let arrowView = UIImageView()
        arrowView.image = UIImage(named: "module_mini_program_ic_arrow_right")
        arrowView.contentMode = .scaleAspectFit

        container.addSubview(iconView)
        container.addSubview(label)
        container.addSubview(arrowView)

        container.snp.makeConstraints { make in
            make.height.equalTo(64)
        }
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(22)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(arrowView.snp.leading).offset(-8)
        }
        arrowView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(22)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        container.isUserInteractionEnabled = true
        container.accessibilityIdentifier = program.appId
        let tap = UITapGestureRecognizer(target: self, action: #selector(itemTapped(_:)))
        container.addGestureRecognizer(tap)

        return container
    }

    // MARK: - Actions

    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleTitleTap() {
        guard !isScanVisible else { return }
        isScanVisible = true
        activateScanEntry()
    }

    @objc private func itemTapped(_ gesture: UITapGestureRecognizer) {
        guard let appId = gesture.view?.accessibilityIdentifier else { return }
        startMiniApp(appId: appId)
    }

    @objc private func scanButtonTapped() {
        let scanVC = TCMPPScanCodeController()
        scanVC.modalPresentationStyle = .fullScreen
        scanVC.scanResultHandler = { [weak self, weak scanVC] results in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let dismissAndLaunch: () -> Void = {
                    guard let result = results?.first as? TCMPPScanCodeResult else {
                        debugPrint("[MiniProgram] scan result is empty")
                        return
                    }
                    let link = result.stringValue
                    guard !link.isEmpty else {
                        debugPrint("[MiniProgram] scan result is empty")
                        return
                    }
                    debugPrint("[MiniProgram] scan result: \(link)")
                    TMFMiniAppSDKManager.sharedInstance().startUpMiniApp(
                        withLink: link,
                        scene: .scanQRCode,
                        parentVC: self,
                        completion: { error in
                            if let error = error {
                                debugPrint("[MiniProgram] startUpMiniApp(byLink) error: \(error.localizedDescription)")
                            }
                        }
                    )
                }
                if let scanVC = scanVC, scanVC.presentingViewController != nil {
                    scanVC.dismiss(animated: true, completion: dismissAndLaunch)
                } else {
                    dismissAndLaunch()
                }
            }
        }
        present(scanVC, animated: true)
    }

    private func startMiniApp(appId: String) {
        debugPrint("[MiniProgram] startMiniApp: \(appId)")
        TMFMiniAppSDKManager.sharedInstance().startUpMiniApp(withAppID: appId, parentVC: self) { error in
            if let error = error {
                debugPrint("[MiniProgram] startMiniApp error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - MiniProgramSDKDelegate

final class MiniProgramSDKDelegate: NSObject, TMFMiniAppSDKDelegate {

    func setLiveLicenceURL() -> String {
        return LIVE_LICENSE_URL
    }

    func setLiveLicenceKey() -> String {
        return LIVE_LICENSE_KEY
    }
}

#endif
