//
//  HiddenConfigViewController.swift
//  login
//
//

import UIKit

public struct HiddenConfigCredentials {
    public let sdkAppId: String
    public let userId: String
    public let userSig: String
}

final class HiddenConfigViewController: UIViewController {
    // MARK: - Callbacks

    var onConfirm: ((_ credentials: HiddenConfigCredentials) -> Void)?

    var onRestoreDefault: (() -> Void)?

    // MARK: - UI

    private lazy var configView: HiddenConfigView = {
        let view = HiddenConfigView()
        return view
    }()

    // MARK: - Lifecycle

    override func loadView() {
        view = configView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindCallbacks()
    }

    // MARK: - Bindings

    private func bindCallbacks() {
        configView.onBack = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        configView.onConfirm = { [weak self] sdkAppID, userId, userSig in
            guard let self = self else { return }
            let credentials = HiddenConfigCredentials(sdkAppId: sdkAppID, userId: userId, userSig: userSig)
            LoginEntry.shared.switchSDKAppID(credentials: credentials)
            self.onConfirm?(credentials)
            self.pushDebugAuthWithCredentials(credentials)
        }

        configView.onRestoreDefault = { [weak self] in
            LoginEntry.shared.resetSDKAppID()
            self?.onRestoreDefault?()
            self?.navigationController?.popViewController(animated: true)
        }

        configView.onScanQRCode = { [weak self] in
            self?.pushQRScanner()
        }
    }

    // MARK: - QR Scanner

    private func pushQRScanner() {
        let scannerVC = QRCodeScanViewController()
        scannerVC.onScanResult = { [weak self] result in
            self?.navigationController?.popViewController(animated: true)
            self?.configView.handleQRCodeResult(result)
        }
        scannerVC.onCancel = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        navigationController?.pushViewController(scannerVC, animated: true)
    }

    // MARK: - Debug Auth

    private func pushDebugAuthWithCredentials(_ credentials: HiddenConfigCredentials) {
        LoginEntry.shared.loginWithHiddenCredentials(credentials)
    }
}
