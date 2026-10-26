import SnapKit
import UIKit

final class AIAgentPickerSheet: UIViewController {
    private static let panelCornerRadius: CGFloat = 16

    private static let rowHeight: CGFloat = 56

    private static let horizontalMargin: CGFloat = 8

    private static let groupSpacing: CGFloat = 8

    private static let bottomMargin: CGFloat = 8

    private static let separatorHeight: CGFloat = 0.5

    private static let titleFontSize: CGFloat = 16

    private static let dimAlpha: CGFloat = 0.4

    private static let animationDuration: TimeInterval = 0.25

    private let agentNames: [String]

    private let onSelect: (Int) -> Void

    private let dimView = UIControl()

    private let contentView = UIView()

    private let optionsGroupView = UIView()

    private let optionsContentView = UIView()

    private let cancelButton = UIButton(type: .custom)

    init(agentNames: [String], onSelect: @escaping (Int) -> Void) {
        self.agentNames = agentNames
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        activateConstraints()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playPresentAnimation()
    }

    private func setupViews() {
        let colors = TUIChatKitTheme.colors
        view.backgroundColor = .clear
        dimView.backgroundColor = UIColor.black.withAlphaComponent(Self.dimAlpha)
        dimView.alpha = 0
        dimView.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)

        optionsGroupView.backgroundColor = colors.bgColorOperate
        optionsGroupView.layer.cornerRadius = Self.panelCornerRadius
        optionsGroupView.clipsToBounds = true

        cancelButton.backgroundColor = colors.bgColorOperate
        cancelButton.layer.cornerRadius = Self.panelCornerRadius
        cancelButton.clipsToBounds = true
        cancelButton.setTitle(LocalizedChatString("Cancel"), for: .normal)
        cancelButton.setTitleColor(colors.textColorLink, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: Self.titleFontSize, weight: .semibold)
        cancelButton.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)

        view.addSubview(dimView)
        view.addSubview(contentView)
        contentView.addSubview(optionsGroupView)
        optionsGroupView.addSubview(optionsContentView)
        contentView.addSubview(cancelButton)
        buildOptionRows()
    }

    private func buildOptionRows() {
        let colors = TUIChatKitTheme.colors
        var previousRow: UIView?
        for (index, name) in agentNames.enumerated() {
            let row = UIButton(type: .custom)
            row.tag = index
            row.setTitle(name, for: .normal)
            row.setTitleColor(colors.textColorLink, for: .normal)
            row.titleLabel?.font = .systemFont(ofSize: Self.titleFontSize)
            row.addTarget(self, action: #selector(handleOptionTapped(_:)), for: .touchUpInside)
            optionsContentView.addSubview(row)
            row.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(Self.rowHeight)
                if let previousRow = previousRow {
                    make.top.equalTo(previousRow.snp.bottom)
                } else {
                    make.top.equalToSuperview()
                }
            }
            if index > 0 {
                let separator = UIView()
                separator.backgroundColor = colors.strokeColorPrimary
                optionsContentView.addSubview(separator)
                separator.snp.makeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.top.equalTo(row.snp.top)
                    make.height.equalTo(Self.separatorHeight)
                }
            }
            previousRow = row
        }
        if let lastRow = previousRow {
            optionsContentView.snp.makeConstraints { make in
                make.bottom.equalTo(lastRow.snp.bottom)
            }
        }
    }

    private func activateConstraints() {
        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Self.horizontalMargin)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-Self.bottomMargin)
        }
        optionsGroupView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        optionsContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(optionsGroupView.snp.bottom).offset(Self.groupSpacing)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.rowHeight)
            make.bottom.equalToSuperview()
        }
    }

    private func playPresentAnimation() {
        contentView.transform = CGAffineTransform(translationX: 0, y: contentView.bounds.height)
        UIView.animate(withDuration: Self.animationDuration) {
            self.dimView.alpha = 1
            self.contentView.transform = .identity
        }
    }

    @objc private func handleOptionTapped(_ sender: UIButton) {
        let index = sender.tag
        dismiss(animated: false) { [onSelect] in
            onSelect(index)
        }
    }

    @objc private func handleDismiss() {
        dismiss(animated: false)
    }
}
