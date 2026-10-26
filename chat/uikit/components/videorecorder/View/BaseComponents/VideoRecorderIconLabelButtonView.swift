import UIKit

final class VideoRecorderIconLabelButtonView: UIButton {
    var iconSize: CGSize = .zero {
        didSet {
            setNeedsLayout()
        }
    }

    var iconLabelGap: CGFloat = 0 {
        didSet {
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let titleSize = titleRect(forContentRect: .zero).size
        return CGSize(width: max(iconSize.width, titleSize.width),
                      height: iconSize.height + iconLabelGap + titleSize.height)
    }

    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        return CGRect(x: contentRect.midX - iconSize.width / 2, y: contentRect.minY,
                      width: iconSize.width, height: iconSize.height)
    }

    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        let imageRect = imageRect(forContentRect: contentRect)
        let size = currentAttributedTitle?.size() ?? .zero
        return CGRect(x: contentRect.midX - size.width / 2, y: imageRect.maxY + iconLabelGap,
                      width: size.width, height: size.height)
    }
}
