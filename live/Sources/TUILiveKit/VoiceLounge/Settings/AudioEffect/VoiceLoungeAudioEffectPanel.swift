import SnapKit
import UIKit

final class VoiceLoungeAudioEffectPanel: BottomSheetView {
    var onSetCaptureVolume: ((Int) -> Void)?

    private let audioEffectView = AudioEffectView()
    private var currentCaptureVolume: Int = 100

    override var sheetHeight: CGFloat { 466 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    func show(captureVolume: Int) {
        currentCaptureVolume = captureVolume
        audioEffectView.bindCaptureVolume(captureVolume)
        present()
    }

    private func setupViews() { contentView.addSubview(audioEffectView) }

    private func setupConstraints() {
        audioEffectView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(60)
            make.height.equalTo(372)
        }
    }

    private func setupStyles() { sheetTitle = .title }

    private func setupBindings() {
        audioEffectView.onSetCaptureVolume = { [weak self] volume in
            self?.currentCaptureVolume = volume
            self?.onSetCaptureVolume?(volume)
        }
    }

    override func sheetWillPresent() { audioEffectView.setActive(true) }

    override func sheetWillDismiss() { audioEffectView.setActive(false) }
}

private extension String {
    static var title: String { LiveKitResources.localizedString("tuilivekit.voiceroom.audio.title") }
}
