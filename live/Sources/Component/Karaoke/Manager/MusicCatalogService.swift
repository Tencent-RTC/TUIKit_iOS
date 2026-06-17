//
//  MusicCatalogService.swift
//  AtomicX
//
//  Created by ssc on 2025/11/18.
//

import Foundation

public protocol QueryPlayTokenCallBack {
    func onSuccess(
        musicId: String,
        playToken: String,
        copyrightedLicenseKey: String?,
        copyrightedLicenseUrl: String?
    )

    func onFailure(code: Int, desc: String)
}

public class ClosureQueryPlayTokenCallback: QueryPlayTokenCallBack {
    private let successHandler: (String, String, String?, String?) -> Void
    private let failureHandler: (Int, String) -> Void

    init(onSuccess: @escaping (String, String, String?, String?) -> Void,
         onFailure: @escaping (Int, String) -> Void) {
        self.successHandler = onSuccess
        self.failureHandler = onFailure
    }

    public func onSuccess(musicId: String,
                   playToken: String,
                   copyrightedLicenseKey: String?,
                   copyrightedLicenseUrl: String?) {
        successHandler(musicId, playToken, copyrightedLicenseKey, copyrightedLicenseUrl)
    }

    public func onFailure(code: Int, desc: String) {
        failureHandler(code, desc)
    }
}



public protocol MusicCatalogService: AnyObject {

    func getSongList(completion: @escaping ([MusicInfo]) -> Void)

    func queryPlayToken(musicId: String, liveID: String, callback: QueryPlayTokenCallBack)
}

public class LocalMusicCatalogServiceImpl: MusicCatalogService {
    
    public init() {}
    
    public func getSongList(completion: @escaping ([MusicInfo]) -> Void) {
        let emptyListJson = "[]"
    }
    
    public func queryPlayToken(musicId: String, liveID: String, callback: QueryPlayTokenCallBack) {
        DispatchQueue.main.async {
            callback.onSuccess(
                musicId: musicId,
                playToken: "",
                copyrightedLicenseKey: nil,
                copyrightedLicenseUrl: nil
            )
        }
    }
}

public class MusicCatalogServiceManager {

    public static let shared = MusicCatalogServiceManager()

    private var currentService: MusicCatalogService
    
    private init() {
        self.currentService = LocalMusicCatalogServiceImpl()
    }

    public func setService(_ service: MusicCatalogService) {
        self.currentService = service
    }

    public func resetToDefault() {
        self.currentService = LocalMusicCatalogServiceImpl()
    }
    
    public func getService() -> MusicCatalogService {
        return currentService
    }
}
