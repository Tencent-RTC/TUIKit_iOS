import UIKit
import QuickLook
import SnapKit
import AtomicXCore

final class MessageFileContentView: UIView, MessageContentView {
    private static let bubbleWidth: CGFloat = 237

    private static let bubblePadding = CGFloat(SpacingScheme.iconIconSpacing)

    private static let iconTextGap = CGFloat(SpacingScheme.smallSpacing)

    private static let iconSize: CGFloat = 40

    private static let footerTopMargin: CGFloat = 6

    private static let footerItemGap: CGFloat = 6

    private static let downloadButtonSize: CGFloat = 20

    private static let nameMaxLines = 1

    private static let progressPercentMax = 100

    private var message: MessageInfo?

    private let bubbleView = UIView()

    private let iconView = UIImageView()

    private let nameLabel = UILabel()

    private let footerRow = UIStackView()

    private let contentCenterGuide = UILayoutGuide()

    private let sizeLabel = UILabel()

    private let statusLabel = UILabel()

    private let downloadButton = UIButton(type: .custom)

    private var previewDataSource: FilePreviewDataSource?

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        bindInteraction()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - MessageContentView

    func bind(message: MessageInfo, context: MessageContentContext) {
        self.message = message
        guard case .file(let payload) = message.messagePayload else { return }

        let colors = ChatUIKitTheme.colors
        let isSelf = context.isSelf
        iconView.image = AtomicXChatResources.image(named: Self.fileTypeIcon(for: payload.fileName ?? ""))
        nameLabel.text = payload.fileName ?? LocalizedChatString("UnknownFile")
        nameLabel.textColor = isSelf ? colors.textColorAntiPrimary : colors.textColorPrimary
        let footerColor = isSelf ? colors.textColorAntiSecondary : colors.textColorSecondary
        sizeLabel.textColor = footerColor
        statusLabel.textColor = footerColor
        sizeLabel.text = Self.formatFileSize(Int64(payload.fileSize))

        refreshDownloadState(message: message)
    }

    func updateProgress(message: MessageInfo) {
        self.message = message
        refreshDownloadState(message: message)
    }

    // MARK: - Local Helpers (FilePreviewManager 在 AtomicX 内为 internal，此处本地实现)

    private func constructViewHierarchy() {
        addSubview(bubbleView)
        bubbleView.addSubview(iconView)
        bubbleView.addSubview(nameLabel)
        footerRow.addArrangedSubview(sizeLabel)
        footerRow.addArrangedSubview(statusLabel)
        footerRow.addArrangedSubview(downloadButton)
        bubbleView.addSubview(footerRow)
        bubbleView.addLayoutGuide(contentCenterGuide)
    }

    private func activateConstraints() {
        bubbleView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(Self.bubbleWidth)
        }
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.bubblePadding)
            make.top.equalToSuperview().offset(Self.bubblePadding)
            make.width.height.equalTo(Self.iconSize)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Self.iconTextGap)
            make.trailing.equalToSuperview().offset(-Self.bubblePadding)
            make.top.equalTo(iconView.snp.top).priority(.high)
        }
        footerRow.axis = .horizontal
        footerRow.spacing = Self.footerItemGap
        footerRow.alignment = .center
        footerRow.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalToSuperview().offset(-Self.bubblePadding)
            make.top.equalTo(nameLabel.snp.bottom).offset(Self.footerTopMargin)
            make.bottom.equalToSuperview().offset(-Self.bubblePadding).priority(.high)
        }
        downloadButton.snp.makeConstraints { make in
            make.width.height.equalTo(Self.downloadButtonSize)
        }
        contentCenterGuide.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.top)
            make.bottom.equalTo(sizeLabel.snp.bottom)
            make.centerY.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        iconView.contentMode = .scaleAspectFit
        nameLabel.font = FontScheme.caption2Regular
        nameLabel.numberOfLines = Self.nameMaxLines
        nameLabel.lineBreakMode = .byTruncatingMiddle
        sizeLabel.font = FontScheme.caption3Regular
        statusLabel.font = FontScheme.caption3Regular
        sizeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        downloadButton.setImage(AtomicXChatResources.image(named: "message_file_download"), for: .normal)
    }

    private func bindInteraction() {
        bubbleView.isUserInteractionEnabled = true
        bubbleView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleBubbleTap)))
        downloadButton.addTarget(self, action: #selector(handleDownloadTap), for: .touchUpInside)
    }

    private func refreshDownloadState(message: MessageInfo) {
        guard case .file(let payload) = message.messagePayload else { return }
        let isDownloaded = !(payload.filePath?.isEmpty ?? true)
        let progress = message.downloadMediaProgress > 0 ? message.downloadMediaProgress : message.uploadMediaProgress
        let isDownloading = !isDownloaded && progress > 0 && progress < Self.progressPercentMax
        statusLabel.text = isDownloading ? "\(progress)%" : ""
        downloadButton.isHidden = isDownloaded || isDownloading
    }

    @objc private func handleBubbleTap() {
        guard case .file(let payload)? = message?.messagePayload else { return }

        guard let filePath = payload.filePath, !filePath.isEmpty,
              FileManager.default.fileExists(atPath: filePath) else {
            handleDownloadTap()
            return
        }
        presentPreview(filePath: filePath)
    }

    @objc private func handleDownloadTap() {
        guard let message = message else { return }
        MessageActionStore.create(message: message).downloadMedia(quality: nil) { _ in }
    }

    private func presentPreview(filePath: String) {
        let dataSource = FilePreviewDataSource(fileURL: URL(fileURLWithPath: filePath))
        previewDataSource = dataSource
        let controller = QLPreviewController()
        controller.dataSource = dataSource
        findViewController()?.present(controller, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let viewController = next as? UIViewController {
                return viewController
            }
            responder = next
        }
        return nil
    }

    private static func fileTypeIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "message_file_type_pdf"
        case "ppt", "pptx", "key", "keynote": return "message_file_type_ppt"
        case "doc", "docx": return "message_file_type_word"
        case "xls", "xlsx", "csv", "numbers": return "message_file_type_excel"
        case "txt", "log", "md", "rtf": return "message_file_type_txt"
        case "zip", "rar", "7z", "tar", "gz", "bz2": return "message_file_type_zip"
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic", "heif": return "message_file_type_img"
        default: return "message_file_type_unknown"
        }
    }

    private static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

private final class FilePreviewDataSource: NSObject, QLPreviewControllerDataSource {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return fileURL as QLPreviewItem
    }
}
