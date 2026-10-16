import AtomicXCore
import UIKit

// 从 TUILiveKit 业务库迁移而来的列表卡片。使用接入层自带资源与图片加载，避免依赖业务库内部资源包。
final class LiveSelectListItemView: UICollectionViewCell {
    static let reuseIdentifier = "LiveKitAccess.LiveSelectListItemView"

    private let coverImageView = UIImageView()
    private let gradientView = LiveSelectListCoverGradientView()
    private let liveStatusView = UIView()
    private let viewerCountLabel = UILabel()
    private let liveNameLabel = UILabel()
    private let avatarImageView = UIImageView()
    private let ownerLabel = UILabel()

    private var coverTask: URLSessionDataTask?
    private var avatarTask: URLSessionDataTask?
    private var representedLiveID = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        coverTask?.cancel()
        avatarTask?.cancel()
        coverTask = nil
        avatarTask = nil
        representedLiveID = ""
        coverImageView.image = nil
        avatarImageView.image = nil
    }

    func bind(_ liveInfo: LiveInfo) {
        representedLiveID = liveInfo.liveID
        liveNameLabel.text = liveInfo.liveName.isEmpty ? liveInfo.liveID : liveInfo.liveName
        ownerLabel.text = liveInfo.liveOwner.userName.isEmpty
            ? liveInfo.liveOwner.userID
            : liveInfo.liveOwner.userName
        viewerCountLabel.text = "\(liveInfo.totalViewerCount)"

        loadCover(liveInfo.coverURL, liveID: liveInfo.liveID)
        loadAvatar(liveInfo.liveOwner.avatarURL, liveID: liveInfo.liveID)
    }

    private func configureUI() {
        contentView.backgroundColor = .black
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true

        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.translatesAutoresizingMaskIntoConstraints = false

        gradientView.translatesAutoresizingMaskIntoConstraints = false

        liveStatusView.backgroundColor = UIColor(red: 1, green: 0.22, blue: 0.27, alpha: 1)
        liveStatusView.layer.cornerRadius = 4

        viewerCountLabel.textColor = .white
        viewerCountLabel.font = .systemFont(ofSize: 14)

        liveNameLabel.textColor = .white
        liveNameLabel.font = .boldSystemFont(ofSize: 16)
        liveNameLabel.numberOfLines = 1
        liveNameLabel.lineBreakMode = .byTruncatingTail

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 10
        avatarImageView.backgroundColor = UIColor(white: 1, alpha: 0.2)

        ownerLabel.textColor = UIColor(white: 1, alpha: 0.70)
        ownerLabel.font = .systemFont(ofSize: 12)
        ownerLabel.numberOfLines = 1
        ownerLabel.lineBreakMode = .byTruncatingTail

        let viewerStack = UIStackView(arrangedSubviews: [liveStatusView, viewerCountLabel])
        viewerStack.axis = .horizontal
        viewerStack.alignment = .center
        viewerStack.spacing = 5
        viewerStack.translatesAutoresizingMaskIntoConstraints = false

        let ownerStack = UIStackView(arrangedSubviews: [avatarImageView, ownerLabel])
        ownerStack.axis = .horizontal
        ownerStack.alignment = .center
        ownerStack.spacing = 4

        let textStack = UIStackView(arrangedSubviews: [liveNameLabel, ownerStack])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false

        [coverImageView, gradientView, viewerStack, textStack].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            coverImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: contentView.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            viewerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            viewerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            liveStatusView.widthAnchor.constraint(equalToConstant: 8),
            liveStatusView.heightAnchor.constraint(equalToConstant: 8),

            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            avatarImageView.widthAnchor.constraint(equalToConstant: 20),
            avatarImageView.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    private func loadCover(_ urlString: String, liveID: String) {
        coverTask?.cancel()
        coverImageView.image = nil
        let resolvedURL = urlString.isEmpty ? LiveListPalette.defaultCoverURL : urlString
        coverTask = LiveListImageLoader.load(urlString: resolvedURL) { [weak self] image in
            guard let self, self.representedLiveID == liveID, let image else { return }
            self.coverImageView.image = image
        }
    }

    private func loadAvatar(_ urlString: String, liveID: String) {
        avatarTask?.cancel()
        avatarImageView.image = nil
        avatarTask = LiveListImageLoader.load(urlString: urlString) { [weak self] image in
            guard let self, self.representedLiveID == liveID, let image else { return }
            self.avatarImageView.image = image
        }
    }
}

private final class LiveSelectListCoverGradientView: UIView {
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        guard let gradient = layer as? CAGradientLayer else { return }
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor,
        ]
        gradient.locations = [0, 0.55, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
