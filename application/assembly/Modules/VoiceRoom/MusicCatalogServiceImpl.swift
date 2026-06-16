//
//  MusicCatalogServiceImpl.swift
//  AppAssembly
//

import Alamofire
import Foundation
import Login
import TUILiveKit

// MARK: - MusicCatalogServiceImpl

public class MusicCatalogServiceImpl: MusicCatalogService {

    private let copyrightedLicenseKey: String
    private let copyrightedLicenseUrl: String

    private let defaultTagId = "72"

    public init(copyrightedLicenseKey: String, copyrightedLicenseUrl: String) {
        self.copyrightedLicenseKey = copyrightedLicenseKey
        self.copyrightedLicenseUrl = copyrightedLicenseUrl
    }

    // MARK: - MusicCatalogService

    public func getSongList(completion: @escaping ([MusicInfo]) -> Void) {
        let url = Self.musicBaseUrl + "search_music_by_tag"
        let params: [String: Any] = [
            "tagId": defaultTagId,
            "limit": "10",
            "scrollToken": "",
        ]

        Self.request(url: url, params: params) { model in
            let musicInfoList = Self.parseMusicInfoList(from: model.data)
            completion(musicInfoList)
        } failed: { err, code in
            completion([])
        }
    }

    public func queryPlayToken(musicId: String, liveID: String, callback: QueryPlayTokenCallBack) {
        let url = Self.musicBaseUrl + "query_token"
        let params: [String: Any] = [
            "roomId": liveID,
            "musicId": musicId,
        ]

        Self.request(url: url, params: params) { [weak self] model in
            guard let self = self else { return }

            if let data = model.data as? [String: String],
               let playToken = data["playToken"]
            {
                callback.onSuccess(
                    musicId: musicId,
                    playToken: playToken,
                    copyrightedLicenseKey: self.copyrightedLicenseKey,
                    copyrightedLicenseUrl: self.copyrightedLicenseUrl
                )
            } else {
                callback.onFailure(code: -1, desc: "Failed to get playToken")
            }
        } failed: { errorCode, errorMessage in
            callback.onFailure(code: Int(errorCode), desc: errorMessage ?? "Network request failed")
        }
    }
}

// MARK: - Network

extension MusicCatalogServiceImpl {
    private static var musicBaseUrl: String {
        return LoginEntry.shared.config.httpBaseUrl + "base/v1/music/"
    }

    private static func request(
        url: String,
        params: [String: Any],
        success: @escaping (KaraokeMusicResponse) -> Void,
        failed: @escaping (Int32, String?) -> Void
    ) {
        var requestParams = params
        if let userId = LoginManager.shared.getCurrentUser()?.userId, requestParams["userId"] == nil {
            requestParams["userId"] = userId
        }
        if let token = LoginManager.shared.getCurrentUser()?.token, requestParams["token"] == nil {
            requestParams["token"] = token
        }
        if let apaasUserId = LoginManager.shared.getCurrentUser()?.apaasUserId,
           !apaasUserId.isEmpty, requestParams["apaasUserId"] == nil
        {
            requestParams["apaasUserId"] = apaasUserId
        }
        if requestParams["appId"] == nil {
            requestParams["appId"] = HttpLogicRequest.sdkAppId
        }

        AF.request(url, method: .post, parameters: requestParams, encoding: JSONEncoding.default)
            .responseJSON { response in
                var result = KaraokeMusicResponse()
                if let respData = response.data, respData.count > 0,
                   let value = try? JSONSerialization.jsonObject(with: respData) as? [String: Any]
                {
                    #if DEBUG
                    debugPrint("[MusicCatalog] http_result: \(value)")
                    #endif
                    if let errorCode = value["errorCode"] as? Int32,
                       let errorMessage = value["errorMessage"] as? String
                    {
                        result.errorCode = errorCode
                        result.errorMessage = errorMessage
                        result.data = value["data"]
                    }
                }

                if result.errorCode == 0 {
                    success(result)
                } else {
                    failed(result.errorCode, result.errorMessage)
                }
            }
    }
}

// MARK: - Response Model

extension MusicCatalogServiceImpl {
    struct KaraokeMusicResponse {
        var errorCode: Int32 = -1
        var errorMessage: String = ""
        var data: Any?
    }
}

// MARK: - JSON Parsing

extension MusicCatalogServiceImpl {
    static func parseMusicInfoList(from data: Any?) -> [MusicInfo] {
        guard let result = data as? [String: Any],
              let ktvMusicInfoSet = result["ktvMusicInfoSet"] as? [[String: Any]]
        else {
            return []
        }

        var musicInfoList: [MusicInfo] = []
        for dict in ktvMusicInfoSet {
            guard let musicId = dict["MusicId"] as? String,
                  let musicName = dict["Name"] as? String,
                  let singerSet = dict["SingerSet"] as? [String]
            else {
                continue
            }

            var coverUrl = ""
            if let albumInfo = dict["AlbumInfo"] as? [String: Any],
               let coverInfoSet = albumInfo["CoverInfoSet"] as? [Any],
               let coverMiniInfo = coverInfoSet.first as? [String: String]
            {
                coverUrl = coverMiniInfo["Url"] ?? ""
            } else {
                coverUrl = dict["AlbumInfoCoverUrl"] as? String ?? ""
            }

            let artist = singerSet.joined(separator: ";")

            let musicInfo = MusicInfo(
                musicId: musicId,
                musicName: musicName,
                artist: artist,
                duration: 0,
                coverUrl: coverUrl,
                accompanyUrl: "",
                originalUrl: "",
                lyricUrl: "",
                isOriginal: true,
                hasRating: false
            )
            musicInfoList.append(musicInfo)
        }
        return musicInfoList
    }
}
