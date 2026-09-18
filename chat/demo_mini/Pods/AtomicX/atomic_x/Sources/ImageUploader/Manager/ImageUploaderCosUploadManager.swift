//  Created by eddard on 2025/10/21.
//  Copyright © 2025 Tencent. All rights reserved.

import Foundation

internal final class ImageUploaderCosUploadManager {
    
    private static let maxRetryCount = 3
    private static let retryDelayNanoseconds: UInt64 = 500_000_000
    
    func uploadFile(localPath: String, presignedURL: String) async -> Int {
        guard let url = URL(string: presignedURL) else {
            print("Invalid presigned URL")
            return -1
        }
        
        let fileURL = URL(fileURLWithPath: localPath)
        guard FileManager.default.fileExists(atPath: localPath) else {
            print("File does not exist at path: \(localPath)")
            return -1
        }
        
        return await uploadFile(fileURL, to: url, maxRetryCount: Self.maxRetryCount)
    }
    
    private func uploadFile(_ fileURL: URL, to url: URL, maxRetryCount: Int) async -> Int {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        var currentRetry = 0
        
        while currentRetry <= maxRetryCount {
            do {
                let (_, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    return -1
                }
                
                let statusCode = httpResponse.statusCode
                if (200...299).contains(statusCode) {
                    print("Upload completed with status code: \(statusCode)")
                    return statusCode
                }
                
                if statusCode >= 500 && currentRetry < maxRetryCount {
                    currentRetry += 1
                    try? await Task.sleep(nanoseconds: Self.retryDelayNanoseconds)
                    continue
                }
                
                print("Upload failed with status code: \(statusCode)")
                return statusCode
            } catch {
                let nsError = error as NSError
                let shouldRetry = isNetworkErrorAndRecoverable(nsError) && currentRetry < maxRetryCount
                
                if shouldRetry {
                    currentRetry += 1
                    try? await Task.sleep(nanoseconds: Self.retryDelayNanoseconds)
                    continue
                } else {
                    print("Upload failed with error: \(error)")
                    return -1
                }
            }
        }
        
        return -1
    }
    
    private func isNetworkErrorAndRecoverable(_ error: NSError) -> Bool {
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorCancelled,
                 NSURLErrorBadURL,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorSecureConnectionFailed,
                 NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid,
                 NSURLErrorClientCertificateRejected,
                 NSURLErrorClientCertificateRequired,
                 NSURLErrorCannotLoadFromNetwork:
                return false
            case NSURLErrorCannotConnectToHost:
                fallthrough
            default:
                return true
            }
        }
        
        if let serverCode = error.userInfo["Code"] as? String {
            if serverCode == "InvalidDigest" || serverCode == "BadDigest" ||
               serverCode == "InvalidSHA1Digest" || serverCode == "RequestTimeOut" {
                return true
            }
        }
        
        return false
    }
}
