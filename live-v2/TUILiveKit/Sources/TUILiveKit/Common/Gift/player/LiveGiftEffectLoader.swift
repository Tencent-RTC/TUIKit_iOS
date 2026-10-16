import CryptoKit
import Foundation

final class LiveGiftEffectLoader {
    enum LoaderError: Error {
        case invalidURL
        case invalidResponse
        case missingTemporaryFile
    }

    private let fileManager: FileManager
    private let session: URLSession
    private let cacheDirectory: URL

    init(fileManager: FileManager = .default, session: URLSession = .shared) {
        self.fileManager = fileManager
        self.session = session
        cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TUILiveKit/PusherGiftEffects", isDirectory: true)
    }

    @discardableResult
    func load(
        resourceURL: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> URLSessionDownloadTask? {
        guard let remoteURL = URL(string: resourceURL),
              let scheme = remoteURL.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else {
            DispatchQueue.main.async { completion(.failure(LoaderError.invalidURL)) }
            return nil
        }

        let cachedURL = cacheURL(for: remoteURL)
        if fileManager.fileExists(atPath: cachedURL.path) {
            DispatchQueue.main.async { completion(.success(cachedURL)) }
            return nil
        }

        let task = session.downloadTask(with: remoteURL) { [weak self] temporaryURL, response, error in
            guard let self else { return }
            let result: Result<URL, Error>
            if let error {
                result = .failure(error)
            } else if let response = response as? HTTPURLResponse,
                      200 ..< 300 ~= response.statusCode,
                      let temporaryURL {
                result = Result { try self.store(temporaryURL: temporaryURL, at: cachedURL) }
            } else {
                result = .failure(
                    temporaryURL == nil ? LoaderError.missingTemporaryFile : LoaderError.invalidResponse
                )
            }
            DispatchQueue.main.async { completion(result) }
        }
        task.priority = URLSessionTask.highPriority
        task.resume()
        return task
    }

    private func cacheURL(for remoteURL: URL) -> URL {
        let digest = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let pathExtension = remoteURL.pathExtension.lowercased()
        return cacheDirectory
            .appendingPathComponent(digest)
            .appendingPathExtension(pathExtension)
    }

    private func store(temporaryURL: URL, at destinationURL: URL) throws -> URL {
        try fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }
        do {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch where fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }
        return destinationURL
    }
}
