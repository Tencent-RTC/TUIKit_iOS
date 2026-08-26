//
//  UserModel.swift
//  login
//

import Foundation

public struct UserModel {
    public var userId: String
    public var token: String
    public var userSig: String
    public var phone: String
    public var email: String
    public var name: String
    public var avatar: String
    
    public init(
        userId: String = "",
        token: String = "",
        userSig: String = "",
        phone: String = "",
        email: String = "",
        name: String = "",
        avatar: String = ""
    ) {
        self.userId = userId
        self.token = token
        self.userSig = userSig
        self.phone = phone
        self.email = email
        self.name = name
        self.avatar = avatar
    }
}
