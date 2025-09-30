//
//  LogUploadManager.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/18.
//

import UIKit
import RTCCommon

class FileModel {
    var fileName: String
    var filePath: String
    
    init(fileName: String, filePath: String) {
        self.fileName = fileName
        self.filePath = filePath
    }
}

public class LogUploadManager: NSObject {

    public static let sharedInstance: LogUploadManager = {
        let instance = LogUploadManager()
        if let currentWin = WindowUtils.getCurrentWindow() {
            currentWin.addSubview(instance.logUploadView)
        }
        return instance
    }()
    
    private var fileModelArray: [FileModel] = []
    public func startUpload(withSuccessHandler success:((() ->Void))?,
                            withCancelHandler canceld:((() ->Void))?) {
        self.showLogUploadView()
        logUploadView.shareHandler = { [weak self] row in
            guard let self = self else { return }
            if row < self.fileModelArray.count {
                let fileModel = self.fileModelArray[row]
                let logPath = fileModel.filePath
                let shareObj = URL(fileURLWithPath: logPath)
                let activityView = UIActivityViewController(activityItems: [shareObj], applicationActivities: nil)
                guard let curVC = WindowUtils.getCurrentWindowViewController() else { return }
                curVC.present(activityView, animated: true) {
                    self.logUploadView.isHidden = true
                    success?()
                }
            }
        }
        logUploadView.cancelHandler = { [weak self] in
            guard let self = self else { return }
            self.logUploadView.isHidden = true
            canceld?()
        }
        
    }
    
    private lazy var logUploadView: LogUploadView = {
        let uploadView = LogUploadView()
        uploadView.frame = CGRect(x: 0, y: 0, width: ScreenWidth, height: screenHeight)
        uploadView.delegate = self
        uploadView.dataSource = self
        uploadView.isHidden = true
        return uploadView
    }()
    
    private func getFilesFromDirectory(atPath path: String, withExtension fileExtension: String) -> [FileModel] {
        let fileManager = FileManager.default
        var files: [FileModel] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for fileName in contents {
                if fileName.hasSuffix(fileExtension) {
                    let filePath = (path as NSString).appendingPathComponent(fileName)
                    let file = FileModel(fileName: fileName, filePath: filePath)
                    files.append(file)
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        
        return files
    }
    
}

extension LogUploadManager {
    
    func showLogUploadView() {
        var fileArray: [FileModel] = []
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        else { return }
        let logPath = (documentsPath as NSString).appendingPathComponent("log")
        guard let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first
        else { return }
        let cachePath = (libraryPath as NSString).appendingPathComponent("Caches/com_tencent_imsdk_log")
        let liteAVSDKClogFiles = getFilesFromDirectory(atPath: logPath, withExtension: ".clog")
        fileArray += liteAVSDKClogFiles
        let liteAVSDKXlogFiles = getFilesFromDirectory(atPath: logPath, withExtension: ".xlog")
        fileArray += liteAVSDKXlogFiles
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
    
    internal func logUploadView(_ logUploadView: LogUploadView, titleForRow row: Int, forComponent component: Int) -> String? {
        if row < fileModelArray.count {
            return fileModelArray[row].fileName
        }
        return nil
    }

}
