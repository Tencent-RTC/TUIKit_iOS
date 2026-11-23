import SnapKit
import UIKit

final class VoiceLoungeAudioEffectPanel: BottomSheetView {
    var onSetCaptureVolume: ((Int) -> Void)?

    private let audioEffectView = VoiceLoungeAudioEffectView()

    override var sheetHeight: CGFloat {
        let screenHeight = window?.bounds.height ?? UIScreen.main.bounds.height
        return min(max(screenHeight * 0.62, 420), screenHeight - safeAreaInsets.top - 40)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    func show(captureVolume: Int) {
        audioEffectView.bindCaptureVolume(captureVolume)
        present()
    }

    func applySkin(_ skin: VoiceLoungeSkin) { audioEffectView.applySkin(skin) }

    private func setupViews() { contentView.addSubview(audioEffectView) }

    private func setupConstraints() {
        audioEffectView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(58)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
    }

    private func setupStyles() {
        sheetTitle = .title
        audioEffectView.applySkin(.defaultSkin)
    }

    private func setupBindings() {
        audioEffectView.onSetCaptureVolume = { [weak self] volume in self?.onSetCaptureVolume?(volume) }
    }

    override func sheetWillPresent() { audioEffectView.setActive(true) }

    override func sheetWillDismiss() { audioEffectView.setActive(false) }
}

private extension String {
    static var title: String { LiveKitResources.localizedString("tuilivekit.voiceroom.audio.title") }
}
