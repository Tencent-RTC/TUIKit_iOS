//
//  AudienceBottomMenuView.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/18.
//

import UIKit
import AtomicX
import SnapKit
import Combine
import AtomicXCore

class AudienceBottomMenuView: RTCBaseView {
    var cancellableSet = Set<AnyCancellable>()
    
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    
    private let maxMenuButtonNumber = 5
    private let buttonWidth: CGFloat = 36.0
    private let buttonSpacing: CGFloat = 6.0
    
    private lazy var creator = AudienceRootMenuDataCreator(manager: manager, routerManager: routerManager)
    private var allMenus: [AudienceBottomItem: AudienceButtonMenuInfo] = [:]
    private var menus = [AudienceButtonMenuInfo]()
    private var currentItems: [AudienceBottomItem] = []
    
    private lazy var likeButton: LikeButton = {
        let likeButton = LikeButton(roomId: manager.liveID)
        return likeButton
    }()
    
    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.distribution = .fillProportionally
        return view
    }()
    
    var buttons: [UIButton] = []
    
    init(manager: AudienceStore, routerManager: AudienceRouterManager) {
        self.manager = manager
        self.routerManager = routerManager
        super.init(frame: .zero)
        loadAllMenusIfNeeded()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        debugPrint("deinit \(type(of: self))")
    }
    
    override func constructViewHierarchy() {
        addSubview(stackView)
    }
    
    override func activateConstraints() {
        stackView.snp.makeConstraints { make in
            let maxWidth = buttonWidth * CGFloat(maxMenuButtonNumber) + buttonSpacing * CGFloat(maxMenuButtonNumber - 1)
            make.top.bottom.equalToSuperview()
            make.trailing.equalTo(-16)
            make.width.lessThanOrEqualTo(maxWidth)
            make.leading.equalToSuperview()
        }
    }
    
    override func setupViewStyle() {
        stackView.spacing = buttonSpacing
    }

    // MARK: - Menu Preloading

    private static let allBuiltInItems: [AudienceBottomItem] = [.gift, .coGuest, .more]

    private func loadAllMenusIfNeeded() {
        guard allMenus.isEmpty else { return }
        let menuData = creator.generateMenuData(items: Self.allBuiltInItems)
        for (index, item) in Self.allBuiltInItems.enumerated() where index < menuData.count {
            allMenus[item] = menuData[index]
        }
    }

    // MARK: - Public API

    func updateItems(_ items: [AudienceBottomItem]) {
        currentItems = items
        cancellableSet.removeAll()
        menus.removeAll()

        stackView.subviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.safeRemoveFromSuperview()
        }

        var allButtons: [UIButton] = []

        for item in items {
            switch item {
            case .like:
                stackView.addArrangedSubview(likeButton)
                likeButton.snp.makeConstraints { make in
                    make.width.equalTo(32.scale375())
                    make.height.equalTo(32.scale375())
                }
                allButtons.append(likeButton)
            case .custom(let customView):
                customView.removeFromSuperview()
                stackView.addArrangedSubview(customView)
                customView.snp.makeConstraints { make in
                    make.width.equalTo(32.scale375())
                    make.height.equalTo(32.scale375())
                }
            default:
                if let menuInfo = allMenus[item] {
                    let button = createButtonFromMenuItem(index: menus.count, item: menuInfo)
                    stackView.addArrangedSubview(button)
                    button.snp.makeConstraints { make in
                        make.width.equalTo(32.scale375())
                        make.height.equalTo(32.scale375())
                    }
                    button.addTarget(self, action: #selector(menuTapAction(sender:)), for: .touchUpInside)
                    allButtons.append(button)
                    menus.append(menuInfo)
                }
            }
        }

        buttons = allButtons
    }

    // MARK: - Semantic Action API

    func showGiftPanel() {
        allMenus[.gift]?.tapAction?(nil)
    }

    func showCoGuestPanel() {
        allMenus[.coGuest]?.tapAction?(nil)
    }
    
    func showMorePanel() {
        allMenus[.more]?.tapAction?(nil)
    }
    
    private func createButtonFromMenuItem(index: Int, item: AudienceButtonMenuInfo) -> AudienceMenuButton {
        let button = AudienceMenuButton()
        button.setupItem(item)
        button.tag = index + 1_000
        item.bindStateClosure?(button, &cancellableSet)
        return button
    }
}

// MARK: - AudienceMenuButton

class AudienceMenuButton: UIButton {
    
    private var item: AudienceButtonMenuInfo?
    private var timer: Timer?
    private var currentImageIndex = 0
    
    let rotateAnimation: CABasicAnimation = {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = Double.pi * 2
        animation.duration = 2
        animation.autoreverses = false
        animation.fillMode = .forwards
        animation.repeatCount = MAXFLOAT
        animation.isRemovedOnCompletion = false
        return animation
    }()
    
    let redDotContentView: UIView = {
        let view = UIView()
        view.backgroundColor = .redDotColor
        view.layer.cornerRadius = 10.scale375Height()
        view.layer.masksToBounds = true
        view.isHidden = true
        return view
    }()
    
    let redDotLabel: UILabel = {
        let redDot = UILabel()
        redDot.textColor = .white
        redDot.textAlignment = .center
        redDot.font = UIFont(name: "PingFangSC-Semibold", size: 12)
        return redDot
    }()
    
    init() {
        super.init(frame: .zero)
        addSubview(redDotContentView)
        redDotContentView.addSubview(redDotLabel)
        
        redDotContentView.snp.makeConstraints { make in
            make.centerY.equalTo(snp.top).offset(5.scale375Height())
            make.centerX.equalTo(snp.right).offset(-5.scale375Height())
            make.height.equalTo(20.scale375Height())
            make.width.greaterThanOrEqualTo(20.scale375Height())
        }
        
        redDotLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4.scale375())
            make.trailing.equalToSuperview().offset(-4.scale375())
            make.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        timer?.invalidate()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let imageView = imageView else { return }
        let imageViewSize: CGFloat = 32.scale375()
        let imageViewX = (bounds.width - imageViewSize) / 2
        let imageViewY = (bounds.height - imageViewSize) / 2
        imageView.frame = CGRect(
            x: imageViewX,
            y: imageViewY,
            width: imageViewSize,
            height: imageViewSize
        )
    }
    
    func setupItem(_ item: AudienceButtonMenuInfo) {
        self.item = item
        setImage(internalImage(item.normalIcon), for: .normal)
        setImage(internalImage(item.selectIcon), for: .selected)
    }
    
    func startAnimating() {
        guard let item = item, !item.animateIcon.isEmpty, timer == nil else { return }
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(switchImage), userInfo: nil, repeats: true)
    }
    
    func stopAnimating() {
        guard let item = item else { return }
        timer?.invalidate()
        timer = nil
        setImage(internalImage(item.normalIcon), for: .normal)
        currentImageIndex = 0
    }
    
    @objc func switchImage() {
        guard let item = item else { return }
        currentImageIndex = (currentImageIndex + 1) % item.animateIcon.count
        let nextImage = internalImage(item.animateIcon[currentImageIndex])
        self.setImage(nextImage, for: .normal)
    }
    
    func updateDotCount(count: Int) {
        if count == 0 {
            redDotContentView.isHidden = true
        } else {
            redDotContentView.isHidden = false
            redDotLabel.text = "\(count)"
        }
    }
    
    func startRotate() {
        layer.add(rotateAnimation, forKey: nil)
    }
    
    func endRotate() {
        layer.removeAllAnimations()
    }
}

extension AudienceBottomMenuView {
    @objc func menuTapAction(sender: AudienceMenuButton) {
        let index = sender.tag - 1_000
        guard index >= 0, index < menus.count else { return }
        let bottomMenu = menus[index]
        bottomMenu.tapAction?(sender)
    }
}
