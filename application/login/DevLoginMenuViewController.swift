//
//  DevLoginMenuViewController.swift
//  login
//

import SnapKit
import UIKit
import AtomicX

private struct LoginMenuItem {
    let title: String
    let subtitle: String
    let icon: String // SF Symbol name
    let mode: LoginMode
}

public enum ServerEnvironment: Int {
    case production = 0
    case test = 1
    
    var title: String {
        switch self {
        case .production: return LoginLocalize("Demo.TRTC.DevMenu.envProduction")
        case .test: return LoginLocalize("Demo.TRTC.DevMenu.envTest")
        }
    }
}

final class DevLoginMenuViewController: UIViewController {
    var onSelectMode: ((LoginMode) -> Void)?
    
    var onEnvironmentChanged: ((ServerEnvironment) -> Void)?
    
    private(set) var currentEnvironment: ServerEnvironment = .production
    
    // MARK: - Data
    
    private let menuItems: [LoginMenuItem] = {
        var items: [LoginMenuItem] = [
            LoginMenuItem(
                title: LoginLocalize("Demo.TRTC.DevMenu.phoneLogin"),
                subtitle: LoginLocalize("Demo.TRTC.DevMenu.phoneLoginDesc"),
                icon: "phone.fill",
                mode: .phoneVerify
            ),
            LoginMenuItem(
                title: LoginLocalize("Demo.TRTC.DevMenu.emailLogin"),
                subtitle: LoginLocalize("Demo.TRTC.DevMenu.emailLoginDesc"),
                icon: "envelope.fill",
                mode: .emailVerify
            ),
        ]
        #if LOGIN_FULL
        items.append(LoginMenuItem(
            title: LoginLocalize("Demo.TRTC.DevMenu.ioaLogin"),
            subtitle: LoginLocalize("Demo.TRTC.DevMenu.ioaLoginDesc"),
            icon: "building.2.fill",
            mode: .ioaAuth
        ))
        #endif
        items.append(contentsOf: [
            LoginMenuItem(
                title: LoginLocalize("Demo.TRTC.DevMenu.inviteCodeLogin"),
                subtitle: LoginLocalize("Demo.TRTC.DevMenu.inviteCodeLoginDesc"),
                icon: "ticket.fill",
                mode: .inviteCode
            ),
            LoginMenuItem(
                title: LoginLocalize("Demo.TRTC.DevMenu.debugLogin"),
                subtitle: LoginLocalize("Demo.TRTC.DevMenu.debugLoginDesc"),
                icon: "wrench.and.screwdriver.fill",
                mode: .debugAuth
            ),
        ])
        return items
    }()
    
    // MARK: - UI
    
    private lazy var headerView: LoginHeaderView = {
        let view = LoginHeaderView()
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        tv.separatorStyle = .none
        tv.showsVerticalScrollIndicator = false
        tv.register(LoginMenuCell.self, forCellReuseIdentifier: LoginMenuCell.reuseID)
        tv.dataSource = self
        tv.delegate = self
        tv.tableFooterView = buildTableFooterView()
        return tv
    }()
    
    private lazy var toggleContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    private lazy var autoLoginToggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = ThemeStore.shared.borderRadius.radius16
        button.clipsToBounds = true
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Medium14
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 26)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: -14)
        button.addTarget(self, action: #selector(autoLoginToggleTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var autoLoginDotView: UIView = {
        let dot = UIView()
        dot.layer.cornerRadius = ThemeStore.shared.borderRadius.radius4
        dot.isUserInteractionEnabled = false
        return dot
    }()
    
    private lazy var envToggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = ThemeStore.shared.borderRadius.radius16
        button.clipsToBounds = true
        button.titleLabel?.font = ThemeStore.shared.typographyTokens.Medium14
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 26)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: -14)
        button.addTarget(self, action: #selector(envToggleTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var envDotView: UIView = {
        let dot = UIView()
        dot.layer.cornerRadius = ThemeStore.shared.borderRadius.radius4
        dot.isUserInteractionEnabled = false
        return dot
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        constructViewHierarchy()
        activateConstraints()
        applyEnvToggleStyle(animated: false)
        applyAutoLoginToggleStyle(animated: false)
    }
    
    // MARK: - Setup
    
    private func constructViewHierarchy() {
        view.addSubview(headerView)
        view.addSubview(tableView)
    }
    
    private func activateConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(200 + statusBarHeight())
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    // MARK: - TableView Footer
    
    private func buildTableFooterView() -> UIView {
        let wrapper = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 60))
        
        let versionLabel = UILabel()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        versionLabel.text = "RTCube Lab v\(version) (\(build))"
        versionLabel.font = ThemeStore.shared.typographyTokens.Regular12
        versionLabel.textColor = ThemeStore.shared.colorTokens.textColorDisable
        versionLabel.textAlignment = .center
        
        wrapper.addSubview(versionLabel)
        versionLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        return wrapper
    }
    
    @objc private func autoLoginToggleTapped() {
        LoginEntry.shared.isAutoLoginEnabled.toggle()
        applyAutoLoginToggleStyle(animated: true)
    }
    
    private func applyAutoLoginToggleStyle(animated: Bool) {
        let style: CapsuleStyle = LoginEntry.shared.isAutoLoginEnabled
            ? .active(hex: "006EFF")
            : .inactive
        autoLoginToggleButton.applyCapsuleStyle(
            title: LoginLocalize("Demo.TRTC.DevMenu.autoLogin"),
            style: style,
            dotView: autoLoginDotView,
            animated: animated
        )
    }
    
    @objc private func envToggleTapped() {
        let newEnv: ServerEnvironment = (currentEnvironment == .production) ? .test : .production
        currentEnvironment = newEnv
        applyEnvToggleStyle(animated: true)
        onEnvironmentChanged?(newEnv)
    }
    
    private func applyEnvToggleStyle(animated: Bool) {
        let style: CapsuleStyle = (currentEnvironment == .production)
            ? .active(hex: "34C759", textHex: "2DA44E")
            : .active(hex: "FF9500", textHex: "D4780A")
        envToggleButton.applyCapsuleStyle(
            title: currentEnvironment.title,
            style: style,
            dotView: envDotView,
            animated: animated
        )
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension DevLoginMenuViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LoginMenuCell.reuseID, for: indexPath) as! LoginMenuCell
        let item = menuItems[indexPath.row]
        cell.configure(title: item.title, subtitle: item.subtitle, icon: item.icon)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 76
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        
        let titleLabel = UILabel()
        titleLabel.text = LoginLocalize("Demo.TRTC.DevMenu.selectLoginMethod")
        titleLabel.font = ThemeStore.shared.typographyTokens.Medium18
        titleLabel.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        
        header.addSubview(titleLabel)
        header.addSubview(toggleContainer)
        toggleContainer.addArrangedSubview(autoLoginToggleButton)
        toggleContainer.addArrangedSubview(envToggleButton)
        autoLoginToggleButton.addSubview(autoLoginDotView)
        envToggleButton.addSubview(envDotView)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(30)
            make.centerY.equalToSuperview()
        }
        
        toggleContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.height.equalTo(32)
        }
        
        autoLoginToggleButton.snp.makeConstraints { make in
            make.height.equalTo(32)
        }
        
        autoLoginDotView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(12)
            make.width.height.equalTo(8)
        }
        
        envToggleButton.snp.makeConstraints { make in
            make.height.equalTo(32)
        }
        
        envDotView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(12)
            make.width.height.equalTo(8)
        }
        
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 64
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) -> Void {        tableView.deselectRow(at: indexPath, animated: true)
        let item = menuItems[indexPath.row]
        onSelectMode?(item.mode)
    }
}

// MARK: - LoginMenuCell

private final class LoginMenuCell: UITableViewCell {
    static let reuseID = "LoginMenuCell"
    
    private let iconBgView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.withAlphaComponent(0.1)
        view.layer.cornerRadius = 18
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Medium16
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = ThemeStore.shared.colorTokens.textColorTertiary
        return label
    }()
    
    private let arrowImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = ThemeStore.shared.colorTokens.textColorDisable
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            iv.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        }
        return iv
    }()
    
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        view.layer.cornerRadius = ThemeStore.shared.borderRadius.radius12
        view.clipsToBounds = true
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        contentView.addSubview(cardView)
        cardView.addSubview(iconBgView)
        iconBgView.addSubview(iconImageView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(arrowImageView)
        
        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        iconBgView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconBgView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualTo(arrowImageView.snp.leading).offset(-8)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.trailing.lessThanOrEqualTo(arrowImageView.snp.leading).offset(-8)
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(title: String, subtitle: String, icon: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            iconImageView.image = UIImage(systemName: icon, withConfiguration: config)
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.15) {
            self.cardView.alpha = highlighted ? 0.6 : 1.0
            self.cardView.transform = highlighted
                ? CGAffineTransform(scaleX: 0.98, y: 0.98)
                : .identity
        }
    }
}

private enum CapsuleStyle {
    case active(hex: String, textHex: String? = nil)
    case inactive
    
    var dotColor: UIColor {
        switch self {
        case .active(let hex, _): return UIColor(hex)
        case .inactive: return ThemeStore.shared.colorTokens.textColorDisable
        }
    }
    
    var backgroundColor: UIColor {
        switch self {
        case .active(let hex, _): return UIColor(hex).withAlphaComponent(0.1)
        case .inactive: return ThemeStore.shared.colorTokens.bgColorDefault
        }
    }
    
    var textColor: UIColor {
        switch self {
        case .active(let hex, let textHex):
            return UIColor(textHex ?? hex)
        case .inactive:
            return ThemeStore.shared.colorTokens.textColorTertiary
        }
    }
    
    var borderColor: UIColor {
        switch self {
        case .active(let hex, _): return UIColor(hex).withAlphaComponent(0.3)
        case .inactive: return ThemeStore.shared.colorTokens.strokeColorSecondary
        }
    }
}

private extension UIButton {
    func applyCapsuleStyle(title: String, style: CapsuleStyle, dotView: UIView, animated: Bool) {
        let applyBlock = {
            self.setTitle(title, for: .normal)
            self.setTitleColor(style.textColor, for: .normal)
            self.backgroundColor = style.backgroundColor
            self.layer.borderWidth = 1
            self.layer.borderColor = style.borderColor.cgColor
            dotView.backgroundColor = style.dotColor
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: applyBlock)
        } else {
            applyBlock()
        }
    }
}
