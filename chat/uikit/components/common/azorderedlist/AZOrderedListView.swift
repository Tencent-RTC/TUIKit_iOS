import UIKit
import SnapKit

public struct AZOrderedListItem: Identifiable, Equatable {
    public var id: String { userID }
    public let userID: String
    public let avatarURL: String?
    public let title: String?
    let extraData: Any?
    public init(userID: String, avatarURL: String? = nil, title: String? = nil, extraData: Any? = nil) {
        self.userID = userID
        self.avatarURL = avatarURL
        self.title = title
        self.extraData = extraData
    }

    public static func == (lhs: AZOrderedListItem, rhs: AZOrderedListItem) -> Bool {
        return lhs.id == rhs.id
    }
}

final class AZOrderedListView: RTCBaseView {
    var onUserInteraction: (() -> Void)?

    var headerView: UIView? {
        didSet { refreshHeaderVisibility() }
    }

    var isHeaderHidden = false {
        didSet { refreshHeaderVisibility() }
    }

    var itemTitleFontSize: CGFloat = 18

    var emptyText: String = LocalizedChatString("NoUser") {
        didSet { emptyLabel.text = emptyText }
    }

    private static let rowHeight: CGFloat = 60

    private static let sectionHeaderHeight: CGFloat = 32

    private static let sectionHeaderHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let indexBarTrailingPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let emptyLabelHorizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let emptyIllustrationWidth: CGFloat = 88

    private static let emptyIllustrationAspectRatio: CGFloat = 300.0 / 338.0

    private static let emptyTextTopSpacing: CGFloat = 14

    private let showIndexBar: Bool

    private let onItemClick: (AZOrderedListItem) -> Void

    private var sections: [AZGroupedSection] = []

    private var sectionTitles: [String] = []

    private var isEmpty: Bool { sections.isEmpty }

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.rowHeight = Self.rowHeight
        table.sectionFooterHeight = 0
        if #available(iOS 15.0, *) {
            table.sectionHeaderTopPadding = 0
        }
        table.keyboardDismissMode = .onDrag
        table.register(AZOrderedListCell.self, forCellReuseIdentifier: AZOrderedListCell.reuseIdentifier)
        return table
    }()

    private lazy var indexBar = AtomicIndexBarView()

    private lazy var emptyView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    private lazy var emptyIllustrationView: UIImageView = {
        let imageView = UIImageView(image: AtomicXChatResources.image(named: "uikit_empty_illustration"))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = LocalizedChatString("NoUser")
        label.font = FontScheme.caption2Regular
        label.textColor = TUIChatKitTheme.colors.textColorTertiary
        label.textAlignment = .center
        return label
    }()

    // MARK: - Init

    init(showIndexBar: Bool = true, onItemClick: @escaping (AZOrderedListItem) -> Void) {
        self.showIndexBar = showIndexBar
        self.onItemClick = onItemClick
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - RTCBaseView Lifecycle

    public override func constructViewHierarchy() {
        addSubview(tableView)
        addSubview(emptyView)
        emptyView.addSubview(emptyIllustrationView)
        emptyView.addSubview(emptyLabel)
        addSubview(indexBar)
    }

    public override func activateConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        emptyIllustrationView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.equalTo(Self.emptyIllustrationWidth)
            make.height.equalTo(Self.emptyIllustrationWidth).multipliedBy(Self.emptyIllustrationAspectRatio)
        }
        emptyLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyIllustrationView.snp.bottom).offset(Self.emptyTextTopSpacing)
            make.leading.trailing.bottom.equalToSuperview()
        }
        indexBar.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.indexBarTrailingPadding)
            make.centerY.equalToSuperview()
        }
    }

    public override func bindInteraction() {
        tableView.dataSource = self
        tableView.delegate = self
        indexBar.onLetterSelected = { [weak self] letter in
            self?.scrollToSection(letter)
        }
        indexBar.onDragStart = { [weak self] in
            guard let self else { return }
            self.tableView.setContentOffset(self.tableView.contentOffset, animated: false)
        }
    }

    public override func setupViewStyle() {
        let color = TUIChatKitTheme.colors.bgColorOperate
        backgroundColor = color
        tableView.backgroundColor = color
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        sizeHeaderToFit()
    }

    // MARK: - Public

    func setItems(_ items: [AZOrderedListItem]) {
        let grouped = AZOrderedListSorter.group(items)
        sections = grouped.sections
        sectionTitles = grouped.titles
        emptyView.isHidden = !isEmpty
        indexBar.setLetters(sectionTitles)
        indexBar.isHidden = !showIndexBar || isEmpty
        tableView.reloadData()
        refreshHeaderVisibility()
    }

    // MARK: - Header Layout

    private func scrollToSection(_ letter: String) {
        guard let section = sectionTitles.firstIndex(of: letter),
              section < sections.count,
              !sections[section].items.isEmpty else { return }
        tableView.scrollToRow(at: IndexPath(row: 0, section: section), at: .top, animated: false)
    }

    private func refreshHeaderVisibility() {
        tableView.tableHeaderView = isHeaderHidden ? nil : headerView
        sizeHeaderToFit()
    }

    private func sizeHeaderToFit() {
        guard let header = tableView.tableHeaderView else { return }
        let targetWidth = tableView.bounds.width
        guard targetWidth > 0 else { return }
        let fitting = header.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        if header.frame.height != fitting.height || header.frame.width != targetWidth {
            header.frame = CGRect(x: 0, y: 0, width: targetWidth, height: fitting.height)
            tableView.tableHeaderView = header
        }
    }
}

// MARK: - UITableViewDataSource

extension AZOrderedListView: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: AZOrderedListCell.reuseIdentifier,
            for: indexPath
        ) as? AZOrderedListCell else {
            return UITableViewCell()
        }
        let items = sections[indexPath.section].items
        cell.titleFontSize = itemTitleFontSize
        cell.configure(with: items[indexPath.row], showsDivider: indexPath.row < items.count - 1)
        return cell
    }

}

// MARK: - UITableViewDelegate

extension AZOrderedListView: UITableViewDelegate {

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return showIndexBar ? Self.sectionHeaderHeight : 0
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard showIndexBar else { return nil }
        let colors = TUIChatKitTheme.colors
        let container = UIView()
        container.backgroundColor = colors.bgColorInput
        let label = UILabel()
        label.text = sections[section].sectionTitle
        label.font = FontScheme.caption2Bold
        label.textColor = colors.textColorPrimary
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.sectionHeaderHorizontalPadding)
            make.centerY.equalToSuperview()
        }
        return container
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onUserInteraction?()
        onItemClick(sections[indexPath.section].items[indexPath.row])
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        onUserInteraction?()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let firstVisible = tableView.indexPathsForVisibleRows?.first,
              firstVisible.section < sectionTitles.count else { return }
        indexBar.setCurrentLetter(sectionTitles[firstVisible.section])
    }
}
