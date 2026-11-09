//
//  KeyMetrics.swift
//  App-UIKit
//
//  Local shim for the AtomicXCore `KeyMetrics` API, which is absent from the
//  5.3.0 binary. Mirrors the TUILiveKit implementation (reports via the ImSDK
//  experimental API).
//

import Foundation
import ImSDK_Plus

enum KeyMetrics {
    static func setComponent(_ component: Int) {}

    static func reportAtomicMetrics(_ platform: Int) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: ["UIComponentType": platform]
        ), let param = String(data: data, encoding: .utf8) else { return }
        V2TIMManager.sharedInstance()?.callExperimentalAPI(
            api: "reportTUIFeatureUsage",
            param: param as NSString,
            succ: nil,
            fail: { code, desc in
                print("App-UIKit-DataReporter reportFeatureUsage failed: \(code) \(desc ?? "")")
            }
        )
    }
}
