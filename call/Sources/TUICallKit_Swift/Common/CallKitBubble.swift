import SnapKit
import UIKit

class CallKitBubble: UIView {

    let stackView = UIStackView()

    private let arrowView = UIView()
    private var arrowLeading: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = CallKitTheme.bubbleBackground
        layer.cornerRadius = 14
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 10)

        stackView.axis = .vertical
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0))
        }

        let arrowSize = CGSize(width: 18, height: 11)
        let path = UIBezierPath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: arrowSize.width, y: 0))
        path.addLine(to: CGPoint(x: arrowSize.width / 2, y: arrowSize.height))
        path.close()
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        arrowView.layer.mask = mask
        arrowView.backgroundColor = CallKitTheme.bubbleBackground
        addSubview(arrowView)
        arrowView.snp.makeConstraints { make in
            arrowLeading = make.leading.equalToSuperview().constraint
            make.top.equalTo(snp.bottom).offset(-1)
            make.size.equalTo(arrowSize)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setArrowCenterX(_ offset: CGFloat) {
        arrowLeading?.update(offset: offset - 9)
    }
}
