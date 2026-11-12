import AtomicXCore
import Foundation

@objc
public class TUICallKit: NSObject {

    private static let shared = TUICallKit()

    @objc
    public static func createInstance() -> TUICallKit {
        return shared
    }

    public override init() {
        super.init()
        _ = CallLauncher.shared
    }

    public func setSelfInfo(nickname: String, avatar: String, completion: CompletionClosure?) {
        let userID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let profile = UserProfile(userID: userID, nickname: nickname, avatarURL: avatar)
        LoginStore.shared.setSelfInfo(userProfile: profile, completion: completion)
    }

    public func calls(userIdList: [String], mediaType: CallMediaType, params: CallParams?, completion: CompletionClosure?) {
        CallStore.shared.calls(participantIds: userIdList, mediaType: mediaType, params: params, completion: completion)
    }

    public func join(callId: String, completion: CompletionClosure?) {
        CallStore.shared.join(callId: callId, completion: completion)
    }

    @objc
    public func setCallingBell(filePath: String) {
        CallKitConfig.shared.callingBellPath = filePath
    }

    @objc
    public func enableMuteMode(enable: Bool) {
        CallKitConfig.shared.updateMuteMode(enable)
    }

    @objc
    public func enableFloatWindow(enable: Bool) {
        CallKitConfig.shared.enableFloatWindow = enable
    }

    @objc
    public func enableVirtualBackground(enable: Bool) {
        CallKitConfig.shared.enableVirtualBackground = enable
    }

    @objc
    public func enableIncomingBanner(enable: Bool) {
        CallKitConfig.shared.enableIncomingBanner = enable
    }

    @objc
    public func enableAITranscriber(enable: Bool) {
        CallKitConfig.shared.updateAITranscriber(enable)
    }

    @objc
    public func callExperimentalAPI(jsonStr: String) {
        CallStore.shared.callExperimentalAPI(jsonStr: jsonStr)
    }

    public func setScreenOrientation(orientation: Int, completion: CompletionClosure?) {
        guard (0...2).contains(orientation) else {
            CallKitLog.warning("setScreenOrientation invalid value: \(orientation)")
            completion?(.failure(ErrorInfo(code: -1001, message: "Invalid screen orientation value.")))
            return
        }
        CallKitConfig.shared.screenOrientation = orientation
        completion?(.success(()))
    }
}
