//
//  UserInfoManager.swift
//  Login
//
//  Created by gg on 2026/3/26.
//

import ImSDK_Plus

class UserInfoManager: NSObject, V2TIMSDKListener {
    private var hasAddedListener = false

    func startListener() {
        guard !hasAddedListener else { return }
        V2TIMManager.sharedInstance().addIMSDKListener(listener: self)
        hasAddedListener = true
    }

    func stopListener() {
        guard hasAddedListener else { return }
        V2TIMManager.sharedInstance().removeIMSDKListener(listener: self)
        hasAddedListener = false
    }

    func updateSelfInfo(userModel: UserModel) {
        ProfileManager.shared.curUserModel?.name = userModel.name
        LoginManager.shared.currentUser?.name = userModel.name
        LoginEntry.shared.userModel?.name = userModel.name

        ProfileManager.shared.curUserModel?.avatar = userModel.avatar
        LoginManager.shared.currentUser?.avatar = userModel.avatar
        LoginEntry.shared.userModel?.avatar = userModel.avatar

        ProfileManager.shared.localizeUserModel()
        if let userModel = LoginManager.shared.currentUser {
            LoginManager.shared.syncUserModelLocalData(userModel)
        }
    }

    func onSelfInfoUpdated(info Info: V2TIMUserFullInfo!) {
        guard let info = Info else { return }
        if let nickName = info.nickName, !nickName.isEmpty {
            ProfileManager.shared.curUserModel?.name = nickName
            LoginManager.shared.currentUser?.name = nickName
            LoginEntry.shared.userModel?.name = nickName
        }
        if let faceURL = info.faceURL, !faceURL.isEmpty {
            ProfileManager.shared.curUserModel?.avatar = faceURL
            LoginManager.shared.currentUser?.avatar = faceURL
            LoginEntry.shared.userModel?.avatar = faceURL
        }
        ProfileManager.shared.localizeUserModel()
        if let userModel = LoginManager.shared.currentUser {
            LoginManager.shared.syncUserModelLocalData(userModel)
        }
    }
}
