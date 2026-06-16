import AlbumPickerCore
import Photos
import UIKit

public typealias AlbumPickerLanguage = AlbumPickerCore.AlbumPickerCoreLanguage.Language

public typealias AlbumPickerCompressQuality = AlbumPickerCore.CompressQuality

public enum AlbumMediaType {
    case image
    case video
}

public enum AlbumPickerStyle {
    case likeWeChat
    case likeWhatsApp
}

public enum AlbumPickerMediaFilter {
    case imageOnly
    case videoOnly
    case imageAndVideo
}

public class AlbumMedia {
    public let id: UInt64
    public var asset: PHAsset?
    public var mediaPath: String?
    public var mediaType: AlbumMediaType = .image
    public var videoThumbnailPath: String?
    public var duration: Int64 = 0

    public init(
        id: UInt64,
        asset: PHAsset? = nil,
        mediaPath: String? = nil,
        mediaType: AlbumMediaType = .image,
        videoThumbnailPath: String? = nil,
        duration: Int64 = 0
    ) {
        self.id = id
        self.asset = asset
        self.mediaPath = mediaPath
        self.mediaType = mediaType
        self.videoThumbnailPath = videoThumbnailPath
        self.duration = duration
    }
}

public struct AlbumPickerConfig {
    public var maxSelectionCount: Int?
    public var itemsPerRow: Int?
    public var showsCameraItem: Bool = false
    public var style: AlbumPickerStyle = .likeWeChat
    public var mediaFilter: AlbumPickerMediaFilter = .imageAndVideo
    public var language: AlbumPickerLanguage?
    public var compressQuality: AlbumPickerCompressQuality = .standard
    public var maxVideoDurationInSeconds = 600
    public var maxOutputFileSizeInMB = 100
    
    public init(
        maxSelectionCount: Int? = nil,
        itemsPerRow: Int? = nil,
        showsCameraItem: Bool = false,
        style: AlbumPickerStyle = .likeWeChat,
        mediaFilter: AlbumPickerMediaFilter = .imageAndVideo,
        language: AlbumPickerLanguage? = nil,
        compressQuality: AlbumPickerCompressQuality = .standard
    ) {
        self.maxSelectionCount = maxSelectionCount
        self.itemsPerRow = itemsPerRow
        self.showsCameraItem = showsCameraItem
        self.style = style
        self.mediaFilter = mediaFilter
        self.language = language
        self.compressQuality = compressQuality
    }
}

public struct AlbumPickerTheme {
    public var currentPrimaryColor: UIColor?
    public var backgroundColor: UIColor?
    public var backgroundColorSecondary: UIColor?
    public var textColor: UIColor?
    public var textColorSecondary: UIColor?
    public var confirmButtonIcon: UIImage?
    public var bigFontSize: CGFloat?
    public var normalFontSize: CGFloat?
    public var smallFontSize: CGFloat?
    public var bigRadius: CGFloat?
    public var normalRadius: CGFloat?
    public var smallRadius: CGFloat?

    public init(
        currentPrimaryColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        backgroundColorSecondary: UIColor? = nil,
        textColor: UIColor? = nil,
        textColorSecondary: UIColor? = nil,
        confirmButtonIcon: UIImage? = nil,
        bigFontSize: CGFloat? = nil,
        normalFontSize: CGFloat? = nil,
        smallFontSize: CGFloat? = nil,
        bigRadius: CGFloat? = nil,
        normalRadius: CGFloat? = nil,
        smallRadius: CGFloat? = nil
    ) {
        self.currentPrimaryColor = currentPrimaryColor
        self.backgroundColor = backgroundColor
        self.backgroundColorSecondary = backgroundColorSecondary
        self.textColor = textColor
        self.textColorSecondary = textColorSecondary
        self.confirmButtonIcon = confirmButtonIcon
        self.bigFontSize = bigFontSize
        self.normalFontSize = normalFontSize
        self.smallFontSize = smallFontSize
        self.bigRadius = bigRadius
        self.normalRadius = normalRadius
        self.smallRadius = smallRadius
    }
}

public protocol AlbumPickerDelegate: AnyObject {
    func onPickConfirm(pickedAlbumMedias: [AlbumMedia], textMessage: String?)
    func onMediaProcessing(albumMedia: AlbumMedia, progress: Float, error: Bool)
    func onMediaProcessed()
    func onCancel()
}

public class AlbumPickerView: UIView {
    public weak var delegate: AlbumPickerDelegate?
    private var isInitialized = false

    public func initialize(config: AlbumPickerConfig, theme: AlbumPickerTheme) {
        guard !isInitialized else { return }
        isInitialized = true

        print("AlbumPicker version: \(AlbumPickerBundleHelper.version)")

        theme.applyToCoreTheme()
        if let language = config.language {
            AlbumPickerCoreLanguage.shared.current = language
        }

        let store = AlbumPickerStore()
        store.config = AlbumPickerStoreConfig(
            maxSelectionCount: config.maxSelectionCount ?? 9,
            maxVideoDurationInSeconds: config.maxVideoDurationInSeconds,
            maxOutputFileSizeInMB: config.maxOutputFileSizeInMB,
            compressQuality: config.compressQuality
        )
        let previewView: UIView
        let mainView: UIView

        switch config.style {
        case .likeWhatsApp:
            let whatsAppPreview = WhatsAppAlbumPickerPreviewView(store: store)
            let whatsAppMain = WhatsAppAlbumPickerMainView(
                store: store, previewView: whatsAppPreview,
                config: config, delegate: delegate
            )
            whatsAppMain.setup()
            previewView = whatsAppPreview
            mainView = whatsAppMain

        case .likeWeChat:
            let weChatPreview = WeChatAlbumPickerPreviewView(store: store)
            let weChatMain = WeChatAlbumPickerMainView(
                store: store, previewView: weChatPreview,
                config: config, delegate: delegate
            )
            weChatMain.setup()
            previewView = weChatPreview
            mainView = weChatMain
        }

        backgroundColor = AlbumPickerCoreTheme.shared.backgroundColor
        addSubview(mainView)
        mainView.snp.makeConstraints { $0.edges.equalToSuperview() }

        previewView.isHidden = true
        addSubview(previewView)
        previewView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}
