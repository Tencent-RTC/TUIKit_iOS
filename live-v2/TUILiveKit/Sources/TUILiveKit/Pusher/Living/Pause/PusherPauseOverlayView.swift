import UIKit
import SnapKit

final class PusherPauseOverlayView: UIView {
    var onResume: (() -> Void)?

    private let contentView = UIView()
    private let timerLabel = UILabel()
    private var contentTopConstraint: Constraint!
    private var renderedSeconds: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentTopConstraint.update(offset: bounds.height * 273 / 844)
    }

    func bind(isPaused: Bool, seconds: Int) {
        isHidden = !isPaused
        guard isPaused, renderedSeconds != seconds else { return }
        renderedSeconds = seconds
        timerLabel.text = String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func configureUI() {
        backgroundColor = PauseOverlayStyle.background

        addSubview(contentView)

        let titleLabel = UILabel()
        titleLabel.text = LiveKitResources.localizedString("tuilivekit.pusher.living.paused")
        titleLabel.textColor = .white
        titleLabel.font = PauseOverlayStyle.titleFont
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)

        timerLabel.textColor = .white
        timerLabel.font = PauseOverlayStyle.timerFont
        timerLabel.textAlignment = .center
        contentView.addSubview(timerLabel)

        let resumeButton = UIButton(type: .system)
        resumeButton.setTitle(LiveKitResources.localizedString("tuilivekit.pusher.living.resume"), for: .normal)
        resumeButton.setTitleColor(PauseOverlayStyle.resumeForeground, for: .normal)
        resumeButton.titleLabel?.font = PauseOverlayStyle.resumeFont
        resumeButton.backgroundColor = .white
        resumeButton.layer.cornerRadius = 10
        resumeButton.layer.shadowColor = UIColor.black.cgColor
        resumeButton.layer.shadowOpacity = 0.28
        resumeButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        resumeButton.layer.shadowRadius = 28
        resumeButton.addTarget(self, action: #selector(resume), for: .touchUpInside)
        addSubview(resumeButton)

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            contentTopConstraint = make.top.equalToSuperview().constraint
            make.height.equalTo(87)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(29)
        }
        timerLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(50)
            make.height.equalTo(37)
        }
        resumeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-42)
            make.size.equalTo(CGSize(width: 205, height: 48))
        }
    }

    @objc private func resume() {
        onResume?()
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum PauseOverlayStyle {
    static let background: UIColor = UIColor.black.withAlphaComponent(0.9)
    static let resumeForeground: UIColor = UIColor(white: 0.067, alpha: 1)
    static let titleFont: UIFont = UIFont.systemFont(ofSize: 21)
    static let timerFont: UIFont = UIFont.systemFont(ofSize: 36)
    static let resumeFont: UIFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
}
