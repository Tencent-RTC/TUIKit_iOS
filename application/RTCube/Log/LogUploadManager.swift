//
//  LogUploadManager.swift
//  RTCube
//

import UIKit

// MARK: - FileModel

class FileModel {
    var fileName: String
    var filePath: String

    init(fileName: String, filePath: String) {
        self.fileName = fileName
        self.filePath = filePath
    }
}

// MARK: - LogUploadManager

public class LogUploadManager: NSObject {

    public static let sharedInstance: LogUploadManager = {
        let instance = LogUploadManager()
        if let currentWindow = LogUploadManager.getCurrentWindow() {
            currentWindow.addSubview(instance.logUploadView)
        }
        return instance
    }()

    private var fileModelArray: [FileModel] = []

    // MARK: - Public

    public func startUpload(withSuccessHandler success: (() -> Void)?,
                            withCancelHandler cancelled: (() -> Void)?) {
        showLogUploadView()

        logUploadView.shareHandler = { [weak self] row in
            guard let self = self, row < self.fileModelArray.count else { return }
            let fileModel = self.fileModelArray[row]
            let shareObj = URL(fileURLWithPath: fileModel.filePath)
            let activityView = UIActivityViewController(activityItems: [shareObj], applicationActivities: nil)
            guard let curVC = LogUploadManager.getCurrentViewController() else { return }
            curVC.present(activityView, animated: true) {
                self.logUploadView.isHidden = true
                success?()
            }
        }

        logUploadView.cancelHandler = { [weak self] in
            guard let self = self else { return }
            self.logUploadView.isHidden = true
            cancelled?()
        }
    }

    // MARK: - Private

    private lazy var logUploadView: LogUploadView = {
        let uploadView = LogUploadView()
        uploadView.frame = CGRect(x: 0, y: 0, width: ScreenWidth, height: ScreenHeight)
        uploadView.delegate = self
        uploadView.dataSource = self
        uploadView.isHidden = true
        return uploadView
    }()

    private func showLogUploadView() {
        var fileArray: [FileModel] = []

        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return }
        let logPath = (documentsPath as NSString).appendingPathComponent("log")

        guard let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first else { return }
        let cachePath = (libraryPath as NSString).appendingPathComponent("Caches/com_tencent_imsdk_log")

        let clogFiles = getFilesFromDirectory(atPath: logPath, withExtension: ".clog")
        fileArray += clogFiles

        let xlogFiles = getFilesFromDirectory(atPath: logPath, withExtension: ".xlog")
        fileArray += xlogFiles

        let imXlogFiles = getFilesFromDirectory(atPath: cachePath, withExtension: ".xlog")
        fileArray += imXlogFiles

        fileModelArray = fileArray
        logUploadView.reloadAllComponents()
        logUploadView.alpha = 0.1
        UIView.animate(withDuration: 0.5) {
            self.logUploadView.isHidden = false
            self.logUploadView.alpha = 1
        }
    }

    private func getFilesFromDirectory(atPath path: String, withExtension fileExtension: String) -> [FileModel] {
        let fileManager = FileManager.default
        var files: [FileModel] = []
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for fileName in contents where fileName.hasSuffix(fileExtension) {
                let filePath = (path as NSString).appendingPathComponent(fileName)
                files.append(FileModel(fileName: fileName, filePath: filePath))
            }
        } catch {
            AppLogger.App.warn(" Error listing directory: \(error.localizedDescription)")
        }
        return files
    }

    private static func getCurrentWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }

    private static func getCurrentViewController() -> UIViewController? {
        guard let rootVC = getCurrentWindow()?.rootViewController else { return nil }
        return topViewController(of: rootVC)
    }

    private static func topViewController(of viewController: UIViewController) -> UIViewController {
        if let nav = viewController as? UINavigationController,
           let visibleVC = nav.visibleViewController {
            return topViewController(of: visibleVC)
        }
        if let tab = viewController as? UITabBarController,
           let selectedVC = tab.selectedViewController {
            return topViewController(of: selectedVC)
        }
        if let presented = viewController.presentedViewController {
            return topViewController(of: presented)
        }
        return viewController
    }
}

// MARK: - LogUploadViewDataSource

extension LogUploadManager: LogUploadViewDataSource {
    func numberOfComponents(in logUploadView: LogUploadView) -> Int {
        return 1
    }

    func logUploadView(_ logUploadView: LogUploadView, numberOfRowsInComponent component: Int) -> Int {
        return fileModelArray.count
    }
}

// MARK: - LogUploadViewDelegate

extension LogUploadManager: LogUploadViewDelegate {
    func logUploadView(_ logUploadView: LogUploadView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard row < fileModelArray.count else { return nil }
        return fileModelArray[row].fileName
    }
}
