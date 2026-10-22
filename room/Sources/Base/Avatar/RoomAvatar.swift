import UIKit

///
public final class RoomAvatar: UIView {

    public var text: String? {
        didSet { applyFallback() }
    }

    public var image: UIImage? {
        didSet {
            imageView.image = image
            applyFallback()
        }
    }

    public var url: String? {
        didSet {
            guard oldValue != url else { return }
            let target = url
            image = nil
            RoomImageLoader.load(url: target) { [weak self] loaded in
                guard let self, self.url == target else { return }
                self.image = loaded
            }
        }
    }

    private let backdropView = UIView()
    private let imageView = UIImageView()
    private let fallbackLabel = UILabel()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true

        backdropView.backgroundColor = UIColor.roomKitAccent
        imageView.contentMode = .scaleAspectFill
        fallbackLabel.textAlignment = .center
        fallbackLabel.textColor = UIColor.roomKitFgOnAccent
        fallbackLabel.adjustsFontSizeToFitWidth = true
        fallbackLabel.minimumScaleFactor = 0.5
        fallbackLabel.isHidden = true

        addSubview(backdropView)
        addSubview(imageView)
        addSubview(fallbackLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: 32, height: 32)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        layer.cornerRadius = side / 2
        backdropView.frame = bounds
        imageView.frame = bounds
        fallbackLabel.frame = bounds
        fallbackLabel.font = .boldSystemFont(ofSize: fontSize(side: side))
    }

    private func applyFallback() {
        fallbackLabel.text = initialText()
        fallbackLabel.isHidden = image != nil || (fallbackLabel.text ?? "").isEmpty
    }

    private func fontSize(side: CGFloat) -> CGFloat {
        max(side * 0.375, 10)
    }

    private func initialText() -> String {
        guard let source = text?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty else {
            return ""
        }
        guard let first = source.first else { return "" }
        if let scalar = first.unicodeScalars.first, scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
            return String(first)
        }
        if first.isLetter {
            return first.uppercased()
        }
        return String(first)
    }
}
