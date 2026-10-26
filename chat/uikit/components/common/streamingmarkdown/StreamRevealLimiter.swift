/// 为流式文字提供额外的显示进度上限，例如与语音播放进度同步。
public protocol StreamRevealLimiter: AnyObject {
    var isSettled: Bool { get }
    func revealLimit(forTotalLength totalLength: Int) -> Int
}
