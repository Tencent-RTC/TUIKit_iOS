import Foundation
import ImSDK_Plus

enum AIAssistantUsageReporter {
    private static let sendMessageMetricsCode = 1022
    private static let invokeCallMetricsCode = 1023

    private static var reportedCodes = Set<Int>()
    private static let reportedCodesLock = NSLock()

    static func reportSendMessageOnce() {
        reportOnce(code: sendMessageMetricsCode)
    }

    static func reportInvokeCallOnce() {
        reportOnce(code: invokeCallMetricsCode)
    }

    private static func reportOnce(code: Int) {
        reportedCodesLock.lock()
        let inserted = reportedCodes.insert(code).inserted
        reportedCodesLock.unlock()
        guard inserted else { return }
        let param = "{\"UIComponentType\":\(code)}" as NSString
        DispatchQueue.main.async {
            V2TIMManager.sharedInstance().callExperimentalAPI(
                api: "reportTUIFeatureUsage",
                param: param,
                succ: { _ in },
                fail: { _, _ in }
            )
        }
    }
}
