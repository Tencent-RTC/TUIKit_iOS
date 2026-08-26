import UIKit
import SnapKit
import Kingfisher

final class MediaZoomCell: UICollectionViewCell {
    static let reuseID = "MediaZoomCell"

    private static let minimumZoomScale: CGFloat = 1

    private static let maximumZoomScale: CGFloat = 3

    private static let playButtonSize: CGFloat = 60

    private static let playIconPointSize: CGFloat = 60

    private static let imageElementType = 0

    private static let videoElementType = 1

    var onImageTap: (() -> Void)?

    var onPlayVideo: (() -> Void)?

    var onDownloadVideo: (() -> Void)?

    private var element: ImageElement?

    private var isDownloading = false

    private let scrollView = UIScrollView()

    private let imageView = UIImageView()

    private let playButton = UIButton(type: .custom)

    private let spinner = UIActivityIndicatorView(style: .large)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configure

    func configure(element: ImageElement, isDownloading: Bool) {
        self.element = element
        self.isDownloading = isDownloading
        scrollView.setZoomScale(Self.minimumZoomScale, animated: false)
        loadImage(path: element.imagePath)
        updateVideoControls(element: element, isDownloading: isDownloading)
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        scrollView.setZoomScale(Self.minimumZoomScale, animated: false)
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        playButton.isHidden = true
        spinner.stopAnimating()
        onImageTap = nil
        onPlayVideo = nil
        onDownloadVideo = nil
    }

    private func buildUI() {
        contentView.backgroundColor = .clear

        scrollView.delegate = self
        scrollView.minimumZoomScale = Self.minimumZoomScale
        scrollView.maximumZoomScale = Self.maximumZoomScale
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true

        playButton.tintColor = .white
        spinner.color = .white
        spinner.hidesWhenStopped = true

        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)
        contentView.addSubview(playButton)
        contentView.addSubview(spinner)

        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        imageView.snp.makeConstraints { $0.edges.equalToSuperview(); $0.size.equalTo(scrollView) }
        playButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Self.playButtonSize)
        }
        spinner.snp.makeConstraints { $0.center.equalToSuperview() }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tap)
        playButton.addTarget(self, action: #selector(handlePlayButton), for: .touchUpInside)
    }

    private func loadImage(path: String) {
        imageView.kf.cancelDownloadTask()
        guard !path.isEmpty else {
            imageView.image = nil
            imageView.backgroundColor = UIColor.black
            return
        }
        if path.hasPrefix("http://") || path.hasPrefix("https://"), let url = URL(string: path) {
            imageView.kf.setImage(with: url)
        } else if FileManager.default.fileExists(atPath: path) {
            imageView.image = UIImage(contentsOfFile: path)
        } else {
            imageView.image = nil
        }
    }

    private func updateVideoControls(element: ImageElement, isDownloading: Bool) {
        guard element.type == Self.videoElementType else {
            playButton.isHidden = true
            spinner.stopAnimating()
            return
        }
        if isDownloading {
            playButton.isHidden = true
            spinner.startAnimating()
            return
        }
        spinner.stopAnimating()
        playButton.isHidden = false
        let hasVideo = !(element.videoPath ?? "").isEmpty
        let iconName = hasVideo ? "play.circle.fill" : "arrow.down.circle.fill"
        let config = UIImage.SymbolConfiguration(pointSize: Self.playIconPointSize)
        playButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
    }

    @objc private func handleTap() {
        guard let element = element else { return }
        if element.type == Self.imageElementType {
            onImageTap?()
        } else {
            triggerVideoAction(element: element)
        }
    }

    @objc private func handlePlayButton() {
        guard let element = element, element.type == Self.videoElementType else { return }
        triggerVideoAction(element: element)
    }

    private func triggerVideoAction(element: ImageElement) {
        if !(element.videoPath ?? "").isEmpty {
            onPlayVideo?()
        } else if !isDownloading {
            onDownloadVideo?()
        }
    }
}

// MARK: - UIScrollViewDelegate (缩放)

extension MediaZoomCell: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}
