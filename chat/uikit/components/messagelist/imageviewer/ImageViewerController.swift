import UIKit
import SnapKit
import Kingfisher
import Photos

final class ImageViewerController: UIViewController {
    private static let closeButtonSize: CGFloat = 48

    private static let closeIconPointSize: CGFloat = 17

    private static let closeButtonTopMargin = CGFloat(SpacingScheme.smallSpacing)

    private static let closeButtonLeadingMargin = CGFloat(SpacingScheme.smallSpacing)

    private static let saveButtonSize: CGFloat = 48

    private static let saveButtonTrailingMargin = CGFloat(SpacingScheme.bubbleSpacing)

    private static let saveButtonBottomMargin = CGFloat(SpacingScheme.smallSpacing)

    private static let loadMoreLeadingThreshold = 1

    private static let loadMoreTrailingThreshold = 2

    private static let videoPlaceholderWidth = 1920

    private static let videoPlaceholderHeight = 1080

    private static let jpegCompressionQuality: CGFloat = 1

    private static let toastShortDuration: TimeInterval = 2

    private static let videoElementType = 1

    private var elements: [ImageElement]

    private var currentIndex: Int

    private var hasPositionedInitialIndex = false

    private let provider: ImageViewerDataProvider

    private var downloadingIndices = Set<Int>()

    private lazy var collectionView: UICollectionView = {
        let layout = FlippableFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.isPagingEnabled = true
        collection.showsHorizontalScrollIndicator = false
        collection.backgroundColor = .clear
        collection.contentInsetAdjustmentBehavior = .never
        collection.register(MediaZoomCell.self, forCellWithReuseIdentifier: MediaZoomCell.reuseID)
        return collection
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .custom)
        if let closeImage = AtomicXChatResources.image(named: "image_viewer_close_icon") {
            button.setImage(closeImage, for: .normal)
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: Self.closeIconPointSize, weight: .regular)
            button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
            button.tintColor = .white
        }
        button.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        return button
    }()

    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(AtomicXChatResources.image(named: "image_viewer_save_button"), for: .normal)
        button.addTarget(self, action: #selector(handleSave), for: .touchUpInside)
        return button
    }()

    private var isSavingMedia = false

    // MARK: - Init

    init(elements: [ImageElement], initialIndex: Int, provider: ImageViewerDataProvider) {
        self.elements = elements
        self.currentIndex = max(0, min(initialIndex, max(elements.count - 1, 0)))
        self.provider = provider
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        view.addSubview(closeButton)
        view.addSubview(saveButton)
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(Self.closeButtonTopMargin)
            make.leading.equalToSuperview().offset(Self.closeButtonLeadingMargin)
            make.width.height.equalTo(Self.closeButtonSize)
        }
        saveButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide).inset(Self.saveButtonTrailingMargin)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(Self.saveButtonBottomMargin)
            make.width.height.equalTo(Self.saveButtonSize)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize = collectionView.bounds.size
        if !hasPositionedInitialIndex, currentIndex > 0, !elements.isEmpty, collectionView.bounds.width > 0 {
            hasPositionedInitialIndex = true
            scrollToIndex(currentIndex, animated: false)
        }
    }

    // MARK: - Actions

    private func scrollToIndex(_ index: Int, animated: Bool) {
        guard index >= 0, index < elements.count else { return }
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: animated)
    }

    private func currentPageIndex() -> Int {
        let width = collectionView.bounds.width
        guard width > 0 else { return currentIndex }
        let rawPage = Int(round(collectionView.contentOffset.x / width))
        if collectionView.effectiveUserInterfaceLayoutDirection == .rightToLeft {
            return max(0, elements.count - 1 - rawPage)
        }
        return rawPage
    }

    private func checkLoadMore() {
        if currentIndex <= Self.loadMoreLeadingThreshold {
            loadMore(isOlder: true)
        }
        if currentIndex >= elements.count - Self.loadMoreTrailingThreshold {
            loadMore(isOlder: false)
        }
    }

    private func loadMore(isOlder: Bool) {
        provider.loadMore(isOlder: isOlder) { [weak self] newElements in
            guard let self = self, !newElements.isEmpty else { return }
            if isOlder {
                self.elements = newElements + self.elements
                self.currentIndex += newElements.count
                self.collectionView.reloadData()
                self.collectionView.layoutIfNeeded()
                self.scrollToIndex(self.currentIndex, animated: false)
            } else {
                self.elements = self.elements + newElements
                self.collectionView.reloadData()
            }
        }
    }

    private func playVideo(at index: Int) {
        guard index >= 0, index < elements.count, let videoPath = elements[index].videoPath, !videoPath.isEmpty else { return }
        let isLocal = FileManager.default.fileExists(atPath: videoPath)
        let videoData = VideoData(
            uri: videoPath,
            localPath: isLocal ? videoPath : nil,
            width: Self.videoPlaceholderWidth,
            height: Self.videoPlaceholderHeight
        )
        dismiss(animated: false) {
            VideoPlayer.shared.playWithUIKit(videoData: videoData, onDismiss: nil)
        }
    }

    private func downloadVideo(at index: Int) {
        guard index >= 0, index < elements.count, !downloadingIndices.contains(index) else { return }
        downloadingIndices.insert(index)
        reloadItem(at: index)
        provider.downloadVideo(at: index) { [weak self] videoPath in
            guard let self = self else { return }
            self.downloadingIndices.remove(index)
            if let videoPath = videoPath, !videoPath.isEmpty, index < self.elements.count {
                let old = self.elements[index]
                self.elements[index] = ImageElement(type: old.type, imagePath: old.imagePath, videoPath: videoPath)
                self.reloadItem(at: index)
                self.playVideo(at: index)
            } else {
                self.reloadItem(at: index)
                WindowToastManager.shared.show(LocalizedChatString("VideoDownloadFailed"), type: .error, duration: Self.toastShortDuration)
            }
        }
    }

    private func reloadItem(at index: Int) {
        guard index >= 0, index < elements.count else { return }
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }

    @objc private func handleSave() {
        guard !isSavingMedia, elements.indices.contains(currentIndex) else { return }
        let element = elements[currentIndex]
        isSavingMedia = true
        saveButton.isEnabled = false
        requestPhotoAddPermission { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.finishSave(success: false)
                return
            }
            if element.type == Self.videoElementType {
                self.saveVideo(element: element, index: self.currentIndex)
            } else {
                self.saveImage(element: element)
            }
        }
    }

    private func requestPhotoAddPermission(completion: @escaping (Bool) -> Void) {
        let handler: (PHAuthorizationStatus) -> Void = { status in
            DispatchQueue.main.async {
                completion(status == .authorized || status == .limited)
            }
        }
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: handler)
        } else {
            PHPhotoLibrary.requestAuthorization(handler)
        }
    }

    private func saveImage(element: ImageElement) {
        let path = element.imagePath
        if FileManager.default.fileExists(atPath: path), let data = FileManager.default.contents(atPath: path) {
            writePhotoData(data)
            return
        }
        guard let url = URL(string: path), url.scheme?.hasPrefix("http") == true else {
            finishSave(success: false)
            return
        }
        ImageDownloader.default.downloadImage(with: url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let imageResult):
                    if let data = imageResult.image.pngData() ?? imageResult.image.jpegData(compressionQuality: Self.jpegCompressionQuality) {
                        self.writePhotoData(data)
                    } else {
                        self.finishSave(success: false)
                    }
                case .failure:
                    self.finishSave(success: false)
                }
            }
        }
    }

    private func saveVideo(element: ImageElement, index: Int) {
        if let path = element.videoPath, FileManager.default.fileExists(atPath: path) {
            writeVideoFile(URL(fileURLWithPath: path))
            return
        }
        provider.downloadVideo(at: index) { [weak self] videoPath in
            guard let self = self else { return }
            guard let videoPath = videoPath, !videoPath.isEmpty else {
                self.finishSave(success: false)
                return
            }
            if FileManager.default.fileExists(atPath: videoPath) {
                self.writeVideoFile(URL(fileURLWithPath: videoPath))
            } else if let url = URL(string: videoPath), url.scheme?.hasPrefix("http") == true {
                self.downloadRemoteVideo(url: url)
            } else {
                self.finishSave(success: false)
            }
        }
    }

    private func downloadRemoteVideo(url: URL) {
        URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let tempURL = tempURL else {
                    self.finishSave(success: false)
                    return
                }
                self.writeVideoFile(tempURL)
            }
        }.resume()
    }

    private func writePhotoData(_ data: Data) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }) { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.finishSave(success: success)
            }
        }
    }

    private func writeVideoFile(_ fileURL: URL) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: fileURL, options: nil)
        }) { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.finishSave(success: success)
            }
        }
    }

    private func finishSave(success: Bool) {
        isSavingMedia = false
        saveButton.isEnabled = true
        let key = success ? "ImageViewerSaveSuccess" : "ImageViewerSaveFailed"
        WindowToastManager.shared.show(LocalizedChatString(key), type: success ? .success : .error, duration: Self.toastShortDuration)
    }

    @objc private func handleClose() {
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension ImageViewerController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return elements.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaZoomCell.reuseID, for: indexPath) as? MediaZoomCell else {
            return UICollectionViewCell()
        }
        let index = indexPath.item
        cell.configure(element: elements[index], isDownloading: downloadingIndices.contains(index))
        cell.onImageTap = { [weak self] in self?.dismiss(animated: true) }
        cell.onPlayVideo = { [weak self] in self?.playVideo(at: index) }
        cell.onDownloadVideo = { [weak self] in self?.downloadVideo(at: index) }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension ImageViewerController: UICollectionViewDelegate {

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        currentIndex = currentPageIndex()
        checkLoadMore()
    }
}

private final class FlippableFlowLayout: UICollectionViewFlowLayout {
    override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        return true
    }
}
