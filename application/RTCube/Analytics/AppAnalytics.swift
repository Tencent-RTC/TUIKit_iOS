//
//  AppAnalytics.swift
//  RTCube (Open Source)
//

import Foundation
import UIKit

public enum AppAnalytics {
    public static func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // No-op in open source build.
    }

    @discardableResult
    public static func handleSchemeURL(_ url: URL) -> Bool {
        return false
    }

    public static func bindUser(_ userId: String) {
        // No-op in open source build.
    }

    public static func trackMainClick(eventName: String, mainEvent: String, loginType: String) {
        // No-op in open source build.
    }
}
