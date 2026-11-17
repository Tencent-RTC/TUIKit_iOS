import UIKit
import SnapKit

public final class BottomOptionSheetPanel: UIViewController {
    public struct Option {
        public let title: String
        public let isDangerous: Bool

        public init(title: String, isDangerous: Bool = false) {
            self.title = title
            self.isDangerous = isDangerous
        }
    }

    private static let panelCornerRadius: CGFloat = 16

    private static let rowHeight: CGFloat = 56

    private static let horizontalMargin: CGFloat = 8

    private static let groupSpacing: CGFloat = 8

    private static let bottomMargin: CGFloat = 8

    private static let separatorHeight: CGFloat = 0.5

    private static let titleFontSize: CGFloat = 16

    private static let dimAlpha: CGFloat = 0.4

    private static let animationDuration: TimeInterval = 0.25

    private static let maxPanelRatio: CGFloat = 0.75

    private let options: [Option]

    private let onSelect: (Int) -> Void

    private let dimView = UIControl()

    private let contentView = UIView()

    private let optionsGroupView = UIView()

    private let optionsScrollView = UIScrollView()

    private let optionsContentView = UIView()

    private let cancelButton = UIButton(type: .custom)

    public init(options: [Option], onSelect: @escaping (Int) -> Void) {
        self.options = options
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        activateConstraints()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyMaxHeightLimit()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playPresentAnimationIfNeeded()
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
        optionsScrollView.showsVerticalScrollIndicator = true
        optionsScrollView.alwaysBounceVertical = false
        optionsScrollView.contentInsetAdjustmentBehavior = .never

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
        optionsGroupView.addSubview(optionsScrollView)
        optionsScrollView.addSubview(optionsContentView)
        contentView.addSubview(cancelButton)
        buildOptionRows()
    }

    private func buildOptionRows() {
        let colors = TUIChatKitTheme.colors
        var previousRow: UIView?
        for (index, option) in options.enumerated() {
            let row = UIButton(type: .custom)
            row.tag = index
            row.setTitle(option.title, for: .normal)
            row.setTitleColor(option.isDangerous ? colors.textColorError : colors.textColorLink, for: .normal)
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
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-Self.bottomMargin)
            make.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide.snp.top)
        }
        optionsGroupView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        optionsScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        optionsContentView.snp.makeConstraints { make in
            make.edges.equalTo(optionsScrollView.contentLayoutGuide)
            make.width.equalTo(optionsScrollView.frameLayoutGuide)
        }
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(optionsGroupView.snp.bottom).offset(Self.groupSpacing)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Self.rowHeight)
        }
    }

    private func applyMaxHeightLimit() {
        let availableHeight = view.bounds.height
            - view.safeAreaInsets.top
            - view.safeAreaInsets.bottom
            - Self.bottomMargin
        let cancelAreaHeight = Self.rowHeight + Self.groupSpacing
        let maxOptionsHeight = min(
            view.bounds.height * Self.maxPanelRatio,
            availableHeight - cancelAreaHeight
        )
        guard maxOptionsHeight > 0 else { return }
        let contentHeight = CGFloat(options.count) * Self.rowHeight
        optionsGroupView.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(contentHeight).priority(.high)
            make.height.lessThanOrEqualTo(maxOptionsHeight)
        }
    }

    private func playPresentAnimationIfNeeded() {
        guard dimView.alpha == 0 else { return }
        view.layoutIfNeeded()
        contentView.transform = CGAffineTransform(translationX: 0, y: contentView.bounds.height + Self.bottomMargin)
        UIView.animate(withDuration: Self.animationDuration) {
            self.dimView.alpha = 1
            self.contentView.transform = .identity
        }
    }

    @objc private func handleOptionTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index >= 0, index < options.count else { return }
        dismissPanel { [weak self] in
            self?.onSelect(index)
        }
    }

    @objc private func handleDismiss() {
        dismissPanel(completion: nil)
    }

    private func dismissPanel(completion: (() -> Void)?) {
        UIView.animate(withDuration: Self.animationDuration) {
            self.dimView.alpha = 0
            self.contentView.transform = CGAffineTransform(
                translationX: 0,
                y: self.contentView.bounds.height + Self.bottomMargin
            )
        } completion: { _ in
            self.dismiss(animated: false) {
                completion?()
            }
        }
    }
}
