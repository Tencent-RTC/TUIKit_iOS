//
//  PhoneVerifyState.swift
//  login
//

import Foundation

public struct PhoneVerifyState {
    public var phoneNumber: String = ""
    public var regionCode: String = "+86"
    public var verifyCode: String = ""
    public var sessionId: String = ""
    public var isLoading: Bool = false
    public var countdownSeconds: Int = 0
    public var toastMessage: String = ""
    public var fullScreenLoadingMessage: String = ""
    public var isFullScreenLoading: Bool = false
}
