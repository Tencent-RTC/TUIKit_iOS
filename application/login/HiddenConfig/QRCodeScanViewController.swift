//
//  QRCodeScanViewController.swift
//  login
//
//

import AtomicX
import AVFoundation
import SnapKit
import UIKit

final class QRCodeScanViewController: UIViewController {
    // MARK: - Callbacks

    var onScanResult: ((_ result: String) -> Void)?

    var onCancel: (() -> Void)?

    // MARK: - Camera

    private var captureSession: AVCaptureSession?
    private let videoPreviewLayer = AVCaptureVideoPreviewLayer()

    // MARK: - UI

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        }
        button.tintColor = .white
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = LoginLocalize("login_hidden_config_scan_qr")
        label.font = ThemeStore.shared.typographyTokens.Medium18
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var scannerOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()

    private lazy var scannerFrame: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.borderWidth = 2
        view.layer.cornerRadius = 12
        return view
    }()

    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.text = LoginLocalize("login_hidden_config_scan_hint")
        label.font = ThemeStore.shared.typographyTokens.Regular14
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        checkCameraPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer.frame = view.bounds
        updateOverlayMask()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    // MARK: - Setup

    private func setupUI() {
        videoPreviewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(videoPreviewLayer)

        view.addSubview(scannerOverlay)
        view.addSubview(scannerFrame)
        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(hintLabel)

        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.width.height.equalTo(44)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.centerX.equalToSuperview()
        }

        scannerFrame.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(250)
        }

        scannerOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(scannerFrame.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }

    private func updateOverlayMask() {
        let overlayPath = UIBezierPath(rect: view.bounds)
        let scanRect = CGRect(
            x: (view.bounds.width - 250) / 2,
            y: (view.bounds.height - 250) / 2,
            width: 250,
            height: 250
        )
        let holePath = UIBezierPath(roundedRect: scanRect, cornerRadius: 12)
        overlayPath.append(holePath.reversing())

        let maskLayer = CAShapeLayer()
        maskLayer.path = overlayPath.cgPath
        scannerOverlay.layer.mask = maskLayer
    }

    // MARK: - Camera Permission

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showPermissionDeniedAlert()
                    }
                }
            }
        default:
            showPermissionDeniedAlert()
        }
    }

    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: LoginLocalize("login_hidden_config_camera_permission_title"),
            message: LoginLocalize("login_hidden_config_camera_permission_msg"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LoginLocalize("login_hidden_config_go_settings"), style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: LoginLocalize("login_hidden_config_cancel"), style: .cancel) { [weak self] _ in
            self?.onCancel?()
        })
        present(alert, animated: true)
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            let session = AVCaptureSession()
            session.addInput(input)

            let metadataOutput = AVCaptureMetadataOutput()
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]

            captureSession = session
            videoPreviewLayer.session = session

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        } catch {
            print("[HiddenConfig] Camera setup error: \(error.localizedDescription)")
        }
    }

    private func stopScanning() {
        captureSession?.stopRunning()
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        stopScanning()
        onCancel?()
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRCodeScanViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else { return }

        stopScanning()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        onScanResult?(stringValue)
    }
}
