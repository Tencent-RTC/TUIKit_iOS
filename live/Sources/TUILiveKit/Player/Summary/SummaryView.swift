import Kingfisher
import AtomicXCore
import SnapKit
import UIKit

@MainActor
final class SummaryView: UIView {
    private let backgroundView = UIImageView()
    private let titleLabel = UILabel()
    private let avatarRingView = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let hintLabel = UILabel()
    private let swipeArrowView = UIImageView()
    private let swipeHintLabel = UILabel()

    private var liveInfo: LiveInfo?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Task { @MainActor [avatarImageView, backgroundView] in
            avatarImageView.kf.cancelDownloadTask()
            backgroundView.kf.cancelDownloadTask()
        }
    }

    func bind(_ liveInfo: LiveInfo, reason: String? = nil) {
        titleLabel.text = reason ?? LiveKitResources.localizedString("tuilivekit.player.live_ended")
        self.liveInfo = liveInfo

        nameLabel.text = liveInfo.liveOwner.userName.isEmpty
            ? liveInfo.liveOwner.userID
            : liveInfo.liveOwner.userName

        avatarImageView.kf.cancelDownloadTask()
        avatarImageView.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        let avatarURL = liveInfo.liveOwner.avatarURL
        avatarImageView.kf.setImage(with: URL(string: avatarURL), placeholder: avatarImageView.image)

        setBackground(liveInfo)
    }

    private func setBackground(_ liveInfo: LiveInfo) {
        let url = liveInfo.backgroundURL.isEmpty
        ? (liveInfo.coverURL.isEmpty ? LiveKitResources.defaultBackgroundURL : liveInfo.coverURL)
            : liveInfo.backgroundURL
        let placeholder = LiveKitResources.image(named: "livekit_livelist_default_cover")
        backgroundView.kf.cancelDownloadTask()
        backgroundView.kf.setImage(
            with: URL(string: url),
            placeholder: placeholder,
            options: [.processor(BlurImageProcessor(blurRadius: 80))]
        )
    }

    private func configureUI() {
        backgroundColor = .clear
        isUserInteractionEnabled = true

        backgroundView.contentMode = .scaleAspectFill
        backgroundView.clipsToBounds = true
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        addSubview(backgroundView)

        titleLabel.text = LiveKitResources.localizedString("tuilivekit.player.live_ended")
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 27, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1

        avatarRingView.backgroundColor = .white
        avatarRingView.layer.cornerRadius = Layout.avatarRingSize / 2
        avatarRingView.layer.masksToBounds = true

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        avatarImageView.layer.cornerRadius = Layout.avatarSize / 2

        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail

        hintLabel.text = LiveKitResources.localizedString("tuilivekit.player.summary.next_live_hint")
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        hintLabel.font = .systemFont(ofSize: 14)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 1

        swipeArrowView.image = LiveKitResources.image(named: "livekit_summary_swipe_arrow")?
            .withRenderingMode(.alwaysTemplate)
        swipeArrowView.tintColor = UIColor.white.withAlphaComponent(0.72)
        swipeArrowView.contentMode = .scaleAspectFit

        swipeHintLabel.text = LiveKitResources.localizedString("tuilivekit.player.summary.swipe_more")
        swipeHintLabel.textColor = UIColor.white.withAlphaComponent(0.66)
        swipeHintLabel.font = .systemFont(ofSize: 12)
        swipeHintLabel.textAlignment = .center
        swipeHintLabel.numberOfLines = 1

        addSubview(titleLabel)
        addSubview(avatarRingView)
        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(hintLabel)
        addSubview(swipeArrowView)
        addSubview(swipeHintLabel)

        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.titleTop)
            make.height.equalTo(Layout.titleHeight)
            make.leading.trailing.equalToSuperview()
        }
        avatarRingView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.avatarRingTop)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.avatarRingSize)
        }
        avatarImageView.snp.makeConstraints { make in
            make.center.equalTo(avatarRingView)
            make.width.height.equalTo(Layout.avatarSize)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.nameTop)
            make.height.equalTo(Layout.nameHeight)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
        }
        hintLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.hintTop)
            make.height.equalTo(Layout.hintHeight)
            make.leading.trailing.equalToSuperview()
        }
        swipeHintLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-Layout.swipeHintBottom)
            make.height.equalTo(Layout.swipeHintHeight)
            make.leading.trailing.equalToSuperview()
        }
        swipeArrowView.snp.makeConstraints { make in
            make.bottom.equalTo(swipeHintLabel.snp.top).offset(-Layout.swipeArrowSpacing)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.swipeArrowSize)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

private extension SummaryView {
    enum Layout {
        static let titleTop: CGFloat = 114
        static let titleHeight: CGFloat = 34
        static let avatarRingTop: CGFloat = 211
        static let avatarRingSize: CGFloat = 86
        static let avatarSize: CGFloat = 80
        static let nameTop: CGFloat = 314
        static let nameHeight: CGFloat = 28
        static let hintTop: CGFloat = 349
        static let hintHeight: CGFloat = 21
        static let swipeArrowSize: CGFloat = 22
        static let swipeArrowSpacing: CGFloat = 5
        static let swipeHintBottom: CGFloat = 58
        static let swipeHintHeight: CGFloat = 18
    }
}
