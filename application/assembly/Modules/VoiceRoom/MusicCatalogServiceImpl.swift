//
//  MusicCatalogServiceImpl.swift
//  AppAssembly
//
//  网络版曲库服务实现 — 从 iOS/App/RT-Cube/Main/ui/MusicCatalogServiceImpl 迁移
//
//  职责：
//    1. 通过后端接口获取版权曲库歌曲列表（searchMusicByTag）
//    2. 通过后端接口获取歌曲播放 Token（queryToken）
//    3. 回传版权曲库 License Key/URL 用于播放鉴权
//

import Alamofire
import Foundation
import Login
import TUILiveKit

// MARK: - MusicCatalogServiceImpl

/// 网络版曲库服务，对接腾讯云版权曲库后端接口
public class MusicCatalogServiceImpl: MusicCatalogService {

    /// 版权曲库 License Key（音速达）
    private let copyrightedLicenseKey: String
    /// 版权曲库 License URL（音速达）
    private let copyrightedLicenseUrl: String

    /// 默认歌曲标签 ID
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
    /// 曲库接口基础 URL
    private static var musicBaseUrl: String {
        return LoginEntry.shared.config.httpBaseUrl + "base/v1/music/"
    }

    /// 通用网络请求（复用 Login 模块的 base URL + 参数注入逻辑）
    private static func request(
        url: String,
        params: [String: Any],
        success: @escaping (KaraokeMusicResponse) -> Void,
        failed: @escaping (Int32, String?) -> Void
    ) {
        var requestParams = params
        // 注入通用参数（userId、token、appId）
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
    /// 轻量级响应模型（避免依赖 Login 模块的 HttpJsonModel）
    struct KaraokeMusicResponse {
        var errorCode: Int32 = -1
        var errorMessage: String = ""
        var data: Any?
    }
}

// MARK: - JSON Parsing

extension MusicCatalogServiceImpl {
    /// 解析后端返回的歌曲列表 JSON 为 [MusicInfo]
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
