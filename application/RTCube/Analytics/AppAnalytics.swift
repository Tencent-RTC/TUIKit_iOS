//
//  AppAnalytics.swift
//  RTCube (Open Source)
//

import AppAssembly
import Foundation
import UIKit

public enum AppAnalytics {

    // MARK: - SDK Lifecycle

    public static func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // No-op in open source build.
    }

    public static func initialize(sdkAppId: Int, userId: String, appTarget: String, appVersion: String, loginMode: String) {
        // No-op in open source build.
    }

    @discardableResult
    public static func handleSchemeURL(_ url: URL) -> Bool {
        return false
    }

    public static func bindUser(_ userId: String) {
        // No-op in open source build.
    }

    // MARK: - Main Click Event

    public static func trackMainClick(eventName: AnalyticName, mainEvent: String, loginType: String) {
        // No-op in open source build.
    }

    // MARK: - Module Event

    public static func trackModuleEvent(moduleId: String, event: AnalyticName, params: [String: Any] = [:]) {
        // No-op in open source build.
    }
}
