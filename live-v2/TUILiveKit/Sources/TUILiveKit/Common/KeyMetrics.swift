import Foundation
import ImSDK_Plus

public enum KeyMetrics {
    public static let componentLiveStream = 21
    public static let liveIntegrationSuccessful = 1120

    public static func setComponent(_ component: Int) {}

    public static func reportAtomicMetrics(_ platform: Int) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: ["UIComponentType": platform]
        ), let param = String(data: data, encoding: .utf8) else { return }
        V2TIMManager.sharedInstance()?.callExperimentalAPI(
            api: "reportTUIFeatureUsage",
            param: param as NSString,
            succ: nil,
            fail: { code, desc in
                print("TUILiveKit-DataReporter reportFeatureUsage failed: \(code) \(desc ?? "")")
            }
        )
    }
}
