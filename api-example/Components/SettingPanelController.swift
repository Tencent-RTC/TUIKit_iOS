import UIKit
import SnapKit

/**
 * Generic settings panel container - half-screen sheet presentation
 *
 * Responsibilities: manage the panel presentation style, animations, and lifecycle
 * Design: accept any UIView as content and present it as a native half-screen sheet via iOS 16+ sheetPresentationController
 *
 * Reuse notes:
 * - BasicStreaming stage: SettingPanelController + DeviceSettingView
 * - Interactive stage: SettingPanelController + TabbedSettingView([DeviceSettingView, BeautySettingView,...])
 * - the container remains unchanged, and only a new content view needs to be added
 */
class SettingPanelController: UIViewController {

    // MARK: - Properties

    private let contentView: UIView
    private let panelTitle: String
    /// custom panel height (nil uses the default.medium())
    private var customHeight: CGFloat?
    /// custom panel background color (`nil` uses `.systemBackground`)
    private let panelBackgroundColor: UIColor?

    // MARK: - UI Components

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .tertiaryLabel
        return button
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    // MARK: - Init

    init(title: String, contentView: UIView, backgroundColor: UIColor? = nil) {
        self.panelTitle = title
        self.contentView = contentView
        self.panelBackgroundColor = backgroundColor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPanelUI()
        setupActions()
    }

    // MARK: - Setup

    private func setupPanelUI() {
        let bgColor = panelBackgroundColor ?? .systemBackground
        view.backgroundColor = bgColor

        // Based on the background brightness, automatically adapt the title and close button colors
        let isDarkBackground = bgColor.isLight == false
        titleLabel.textColor = isDarkBackground ? .white : .label
        closeButton.tintColor = isDarkBackground ? UIColor.white.withAlphaComponent(0.6) : .tertiaryLabel
        separatorView.backgroundColor = isDarkBackground ? UIColor.white.withAlphaComponent(0.15) : .separator

        // title bar
        view.addSubview(titleLabel)
        view.addSubview(closeButton)
        view.addSubview(separatorView)
        view.addSubview(contentView)

        titleLabel.text = panelTitle

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.centerX.equalToSuperview()
        }

        closeButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-16)
            make.width.height.equalTo(30)
        }

        separatorView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }

        // content area
        contentView.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Public API

    /// Present the panel as a half-screen sheet on the specified view controller
    /// - Parameters:
    /// - viewController: parent controller
    /// - height: custom panel height (nil uses the default.medium())
    func show(in viewController: UIViewController, height: CGFloat? = nil) {
        self.customHeight = height
        modalPresentationStyle = .pageSheet

        if let sheet = sheetPresentationController {
            if let height = height {
                sheet.detents = [.custom { _ in height }]
            } else {
                sheet.detents = [.medium()]
            }
            sheet.preferredCornerRadius = 16
        }

        viewController.present(self, animated: true)
    }
}

// MARK: - UIColor Helper

private extension UIColor {
    /// Determine whether the color is light (based on perceived luminance)
    var isLight: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        // Use the W3C relative luminance formula
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.5
    }
}
