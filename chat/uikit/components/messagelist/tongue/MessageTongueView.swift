import UIKit
import SnapKit

final class MessageTongueView: UIControl {
    private enum Style {
        static let minWidth: CGFloat = 94
        static let height: CGFloat = 35
        static let cornerRadius: CGFloat = 7
        static let horizontalPadding: CGFloat = 10
        static let iconWidth: CGFloat = 12
        static let iconHeight: CGFloat = 11
        static let iconTextSpacing: CGFloat = 6
        static let shadowOpacity: Float = 0.12
        static let shadowRadius: CGFloat = 6
        static let shadowOffset = CGSize(width: 0, height: 2)
        static let iconViewportWidth: CGFloat = 24
        static let iconViewportHeight: CGFloat = 22
    }

    private let iconView = UIImageView()

    private let textLabel = UILabel()

    private let stack = UIStackView()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configure

    func configure(entry: MessageListFloatingEntry) {
        textLabel.text = Self.text(for: entry)
        iconView.transform = CGAffineTransform(
            rotationAngle: MessageListFloatingEntryPolicy.iconRotationDegrees(entry) * .pi / 180
        )
    }

    private func buildUI() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.floatingColorDefault
        layer.cornerRadius = Style.cornerRadius
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Style.shadowOpacity
        layer.shadowRadius = Style.shadowRadius
        layer.shadowOffset = Style.shadowOffset

        iconView.image = Self.makeDoubleArrowImage()
        iconView.tintColor = colors.textColorLink
        iconView.contentMode = .scaleAspectFit

        textLabel.font = FontScheme.caption2Regular
        textLabel.textColor = colors.textColorLink
        textLabel.textAlignment = .center

        stack.axis = .horizontal
        stack.spacing = Style.iconTextSpacing
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(textLabel)
        addSubview(stack)

        iconView.snp.makeConstraints { make in
            make.width.equalTo(Style.iconWidth)
            make.height.equalTo(Style.iconHeight)
        }
        stack.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(Style.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Style.horizontalPadding)
        }
        snp.makeConstraints { make in
            make.height.equalTo(Style.height)
            make.width.greaterThanOrEqualTo(Style.minWidth)
        }
    }

    private static func makeDoubleArrowImage() -> UIImage {
        let size = CGSize(width: Style.iconWidth, height: Style.iconHeight)
        let transform = CGAffineTransform(scaleX: Style.iconWidth / Style.iconViewportWidth, y: Style.iconHeight / Style.iconViewportHeight)

        let lowerChevron = UIBezierPath()
        lowerChevron.move(to: CGPoint(x: 11.9802, y: 18.72669))
        lowerChevron.addLine(to: CGPoint(x: 1.6453, y: 9.69699))
        lowerChevron.addLine(to: CGPoint(x: 0, y: 11.53559))
        lowerChevron.addLine(to: CGPoint(x: 11.977, y: 22))
        lowerChevron.addLine(to: CGPoint(x: 24, y: 11.53729))
        lowerChevron.addLine(to: CGPoint(x: 22.3582, y: 9.69529))
        lowerChevron.close()

        let upperChevron = UIBezierPath()
        upperChevron.move(to: CGPoint(x: 24, y: 1.842))
        upperChevron.addLine(to: CGPoint(x: 22.3582, y: 0))
        upperChevron.addLine(to: CGPoint(x: 11.9802, y: 9.0314))
        upperChevron.addLine(to: CGPoint(x: 1.6453, y: 0.0017))
        upperChevron.addLine(to: CGPoint(x: 0, y: 1.8406))
        upperChevron.addLine(to: CGPoint(x: 11.977, y: 12.305))
        upperChevron.close()

        lowerChevron.apply(transform)
        upperChevron.apply(transform)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            UIColor.white.setFill()
            lowerChevron.fill()
            upperChevron.fill()
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    private static func text(for entry: MessageListFloatingEntry) -> String {
        switch entry {
        case .backToLatest:
            return LocalizedChatString("ChatBackToLatestLocation")
        case .newMessages(let count, _):
            return String(format: LocalizedChatString("ChatNewMessages"), "\(count)")
        case .mention(let target):
            switch target.kind {
            case .atAll:
                return LocalizedChatString("MentionAtAllTag")
            case .atMe:
                return LocalizedChatString("MentionAtMeTag")
            }
        case .backToQuote:
            return LocalizedChatString("ChatBackToQuoteLocation")
        }
    }
}
