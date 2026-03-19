import UIKit

class SmartCellularSwitchRecommendationView: UIView {
    
    var onKeepWiFi: (() -> Void)?
    var onEnableSmartCellular: (() -> Void)?
    
    private var isViewReady: Bool = false
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = UIColor("#000000")
        label.textAlignment = .center
        label.text = CallKitLocalization.localized("SmartCellular.title")
        return label
    }()
    
    private let wifiContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private let wifiIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = createWiFiPoorIcon()
        return imageView
    }()
    
    private let wifiLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor("#333333")
        label.textAlignment = .center
        label.text = CallKitLocalization.localized("SmartCellular.wifiPoor")
        return label
    }()
    
    private let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = createArrowIcon()
        return imageView
    }()
    
    private let cellularContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private let cellularIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = createCellularGoodIcon()
        return imageView
    }()
    
    private let cellularLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor("#333333")
        label.textAlignment = .center
        label.text = CallKitLocalization.localized("SmartCellular.cellularGood")
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor("#666666")
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = CallKitLocalization.localized("SmartCellular.description")
        return label
    }()
    
    private let improveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(CallKitLocalization.localized("SmartCellular.improve"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.backgroundColor = UIColor("#006EFF")
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        return button
    }()
    
    private let keepWiFiButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(CallKitLocalization.localized("SmartCellular.keepWifi"), for: .normal)
        button.setTitleColor(UIColor("#333333"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.backgroundColor = UIColor("#F5F5F5")
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if isViewReady { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    private func constructViewHierarchy() {
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(wifiContainer)
        containerView.addSubview(arrowImageView)
        containerView.addSubview(cellularContainer)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(improveButton)
        containerView.addSubview(keepWiFiButton)
        
        wifiContainer.addSubview(wifiIconView)
        wifiContainer.addSubview(wifiLabel)
        
        cellularContainer.addSubview(cellularIconView)
        cellularContainer.addSubview(cellularLabel)
    }
    
    private func activateConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        wifiContainer.translatesAutoresizingMaskIntoConstraints = false
        wifiIconView.translatesAutoresizingMaskIntoConstraints = false
        wifiLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        cellularContainer.translatesAutoresizingMaskIntoConstraints = false
        cellularIconView.translatesAutoresizingMaskIntoConstraints = false
        cellularLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        improveButton.translatesAutoresizingMaskIntoConstraints = false
        keepWiFiButton.translatesAutoresizingMaskIntoConstraints = false
        
        let screenHeight = UIScreen.main.bounds.height
        let containerHeight = screenHeight * 2.0 / 5.0
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: containerHeight),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            wifiContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            wifiContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            wifiContainer.widthAnchor.constraint(equalToConstant: 90),
            
            wifiIconView.topAnchor.constraint(equalTo: wifiContainer.topAnchor),
            wifiIconView.centerXAnchor.constraint(equalTo: wifiContainer.centerXAnchor),
            wifiIconView.widthAnchor.constraint(equalToConstant: 50),
            wifiIconView.heightAnchor.constraint(equalToConstant: 50),
            
            wifiLabel.topAnchor.constraint(equalTo: wifiIconView.bottomAnchor, constant: 6),
            wifiLabel.leadingAnchor.constraint(equalTo: wifiContainer.leadingAnchor),
            wifiLabel.trailingAnchor.constraint(equalTo: wifiContainer.trailingAnchor),
            wifiLabel.bottomAnchor.constraint(equalTo: wifiContainer.bottomAnchor),
            
            arrowImageView.centerYAnchor.constraint(equalTo: wifiIconView.centerYAnchor),
            arrowImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 35),
            arrowImageView.heightAnchor.constraint(equalToConstant: 25),
            
            cellularContainer.topAnchor.constraint(equalTo: wifiContainer.topAnchor),
            cellularContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            cellularContainer.widthAnchor.constraint(equalToConstant: 90),
            
            cellularIconView.topAnchor.constraint(equalTo: cellularContainer.topAnchor),
            cellularIconView.centerXAnchor.constraint(equalTo: cellularContainer.centerXAnchor),
            cellularIconView.widthAnchor.constraint(equalToConstant: 50),
            cellularIconView.heightAnchor.constraint(equalToConstant: 50),
            
            cellularLabel.topAnchor.constraint(equalTo: cellularIconView.bottomAnchor, constant: 6),
            cellularLabel.leadingAnchor.constraint(equalTo: cellularContainer.leadingAnchor),
            cellularLabel.trailingAnchor.constraint(equalTo: cellularContainer.trailingAnchor),
            cellularLabel.bottomAnchor.constraint(equalTo: cellularContainer.bottomAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: wifiContainer.bottomAnchor, constant: 20),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            improveButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            improveButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            improveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            improveButton.heightAnchor.constraint(equalToConstant: 44),
            
            keepWiFiButton.topAnchor.constraint(equalTo: improveButton.bottomAnchor, constant: 10),
            keepWiFiButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            keepWiFiButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            keepWiFiButton.heightAnchor.constraint(equalToConstant: 44),
            keepWiFiButton.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    private func bindInteraction() {
        improveButton.addTarget(self, action: #selector(improveButtonTapped), for: .touchUpInside)
        keepWiFiButton.addTarget(self, action: #selector(keepWiFiButtonTapped), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func improveButtonTapped() {
        onEnableSmartCellular?()
        dismiss()
    }
    
    @objc private func keepWiFiButtonTapped() {
        onKeepWiFi?()
        dismiss()
    }
    
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        if !containerView.frame.contains(location) {
            dismiss()
        }
    }
    
    func show(in view: UIView? = nil) {
        guard let targetView = view ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            return
        }
        
        frame = targetView.bounds
        targetView.addSubview(self)
        
        containerView.transform = CGAffineTransform(translationX: 0, y: bounds.height * 2.0 / 5.0)
        alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.containerView.transform = .identity
            self.alpha = 1
        }
    }
    
    func dismiss() {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.bounds.height * 2.0 / 5.0)
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
    
    private static func createWiFiPoorIcon() -> UIImage {
        let size = CGSize(width: 60, height: 60)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            let centerX = size.width / 2
            let centerY = size.height / 2 + 5
            
            ctx.setLineWidth(4)
            ctx.setLineCap(.round)
            
            ctx.setStrokeColor((UIColor("#FFB3BA")).cgColor)
            ctx.addArc(center: CGPoint(x: centerX, y: centerY),
                      radius: 20,
                      startAngle: .pi * 0.75,
                      endAngle: .pi * 0.25,
                      clockwise: false)
            ctx.strokePath()
            
            ctx.setStrokeColor((UIColor("#FFB3BA")).cgColor)
            ctx.addArc(center: CGPoint(x: centerX, y: centerY),
                      radius: 13,
                      startAngle: .pi * 0.75,
                      endAngle: .pi * 0.25,
                      clockwise: false)
            ctx.strokePath()
            
            ctx.setStrokeColor((UIColor("#FF4D4F")).cgColor)
            ctx.addArc(center: CGPoint(x: centerX, y: centerY),
                      radius: 6,
                      startAngle: .pi * 0.75,
                      endAngle: .pi * 0.25,
                      clockwise: false)
            ctx.strokePath()
            
            ctx.setFillColor((UIColor("#FF4D4F")).cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 2, y: centerY + 8, width: 4, height: 4))
            
            let warningSize: CGFloat = 16
            let warningX = size.width - warningSize - 2
            let warningY: CGFloat = 2
            
            ctx.setFillColor((UIColor("#FF4D4F")).cgColor)
            ctx.fillEllipse(in: CGRect(x: warningX, y: warningY, width: warningSize, height: warningSize))
            
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: warningX + warningSize/2 - 1, y: warningY + 3, width: 2, height: 7))
            ctx.fillEllipse(in: CGRect(x: warningX + warningSize/2 - 1, y: warningY + 11, width: 2, height: 2))
        }
    }
    
    private static func createCellularGoodIcon() -> UIImage {
        let size: CGSize = CGSize(width: 60, height: 60)
        let renderer: UIGraphicsImageRenderer = UIGraphicsImageRenderer(size: size)
        let image: UIImage = renderer.image { context in
            let ctx: CGContext = context.cgContext
            let barWidth: CGFloat = 6.0
            let barSpacing: CGFloat = 4.0
            let maxHeight: CGFloat = 40.0
            let totalBarWidth: CGFloat = barWidth * 5.0 + barSpacing * 4.0
            let startX: CGFloat = (size.width - totalBarWidth) / 2.0
            let startY: CGFloat = (size.height + maxHeight) / 2.0
            let baseColor: UIColor = UIColor("#52C41A")
            let cgFillColor: CGColor = baseColor.cgColor
            ctx.setFillColor(cgFillColor)
            for i in 0..<5 {
                let indexFloat: CGFloat = CGFloat(i)
                let heightRatio: CGFloat = CGFloat(i + 1) / 5.0
                let barHeight: CGFloat = maxHeight * heightRatio
                let offsetX: CGFloat = indexFloat * (barWidth + barSpacing)
                let x: CGFloat = startX + offsetX
                let y: CGFloat = startY - barHeight
                
                let barRect: CGRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                let path: UIBezierPath = UIBezierPath(roundedRect: barRect, cornerRadius: 2)
                ctx.addPath(path.cgPath)
                ctx.fillPath()
            }
        }
        return image
    }
    
    private static func createArrowIcon() -> UIImage {
        let size = CGSize(width: 40, height: 30)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            ctx.setStrokeColor((UIColor("#999999")).cgColor)
            ctx.setLineWidth(3)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            ctx.move(to: CGPoint(x: 5, y: size.height / 2))
            ctx.addLine(to: CGPoint(x: size.width - 12, y: size.height / 2))
            
            ctx.move(to: CGPoint(x: size.width - 12, y: size.height / 2 - 6))
            ctx.addLine(to: CGPoint(x: size.width - 5, y: size.height / 2))
            ctx.addLine(to: CGPoint(x: size.width - 12, y: size.height / 2 + 6))
            
            ctx.strokePath()
        }
    }
}
