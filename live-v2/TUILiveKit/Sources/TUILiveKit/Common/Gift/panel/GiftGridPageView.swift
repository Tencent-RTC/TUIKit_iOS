import SnapKit
import UIKit

final class GiftGridPageView: UIView {
    typealias GiftItem = GiftUIStore.GiftItem

    enum SelectionState {
        case none
        case selected(String)
        case combo(String)
    }

    var onCellTapped: ((GiftItem) -> Void)?
    var onComboSend: ((GiftItem) -> Void)?
    var onComboExpired: (() -> Void)?

    private(set) var gifts: [GiftItem] = []
    private(set) var selection: SelectionState = .none

    private let scrollView = UIScrollView()
    private var cells: [GiftCellView] = []
    private var comboButtons: [GiftComboButton] = []
    private let columns: Int = 4
    private let cellSpacing: CGFloat = 4
    private let rowSpacing: CGFloat = 2
    private let horizontalPadding: CGFloat = 10
    private let rowHeight: CGFloat = 104

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func update(gifts: [GiftItem]) {
        self.gifts = gifts
        ensureCells(count: gifts.count)
        applyAll()
    }

    func setSelection(_ selection: SelectionState) {
        self.selection = selection
        applyAll()
    }

    func clearSelection() {
        setSelection(.none)
    }

    private func ensureCells(count: Int) {
        while cells.count < count {
            let index = cells.count
            let cell = GiftCellView()
            cell.onTap = { [weak self, weak cell] in
                guard let self, let cell, let giftID = cell.giftID,
                      let gift = self.gifts.first(where: { $0.id == giftID }) else { return }
                self.onCellTapped?(gift)
            }
            let combo = GiftComboButton()
            combo.isHidden = true
            combo.onSendOnce = { [weak self, weak combo] in
                guard let self, let combo, let giftID = combo.giftID,
                      let gift = self.gifts.first(where: { $0.id == giftID }) else { return }
                self.onComboSend?(gift)
            }
            combo.onExpired = { [weak self] in
                self?.onComboExpired?()
            }
            scrollView.addSubview(cell)
            scrollView.addSubview(combo)
            cells.append(cell)
            comboButtons.append(combo)
            _ = index
        }
    }

    private func applyAll() {
        for (index, cell) in cells.enumerated() {
            if index >= gifts.count {
                cell.isHidden = true
                comboButtons[index].isHidden = true
                comboButtons[index].end()
                continue
            }
            let gift = gifts[index]
            let combo = comboButtons[index]

            switch selection {
            case .none:
                cell.isHidden = false
                combo.isHidden = true
                if combo.giftID != nil { combo.end() }
                cell.configure(gift: gift, state: .normal)
            case .selected(let selectedID):
                if gift.id == selectedID {
                    cell.isHidden = false
                    combo.isHidden = true
                    if combo.giftID != nil { combo.end() }
                    cell.configure(gift: gift, state: .selected)
                } else {
                    cell.isHidden = false
                    combo.isHidden = true
                    if combo.giftID != nil { combo.end() }
                    cell.configure(gift: gift, state: .normal)
                }
            case .combo(let comboID):
                if gift.id == comboID {
                    cell.isHidden = true
                    combo.isHidden = false
                    if combo.giftID != gift.id {
                        combo.begin(with: gift)
                    }
                } else {
                    cell.isHidden = false
                    combo.isHidden = true
                    if combo.giftID != nil { combo.end() }
                    cell.configure(gift: gift, state: .normal)
                }
            }
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let totalSpacing = cellSpacing * CGFloat(columns - 1)
        let availableWidth = bounds.width - horizontalPadding * 2 - totalSpacing
        let cellWidth = floor(availableWidth / CGFloat(columns))
        let cellHeight = rowHeight

        var visibleIndex = 0
        var maxBottom: CGFloat = 0
        for (index, cell) in cells.enumerated() {
            guard index < gifts.count else {
                cell.frame = .zero
                comboButtons[index].frame = .zero
                continue
            }
            let row = visibleIndex / columns
            let column = visibleIndex % columns
            let x = horizontalPadding + CGFloat(column) * (cellWidth + cellSpacing)
            let y = CGFloat(row) * (cellHeight + rowSpacing) + 6
            let frame = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
            cell.frame = frame
            comboButtons[index].frame = frame
            maxBottom = max(maxBottom, y + cellHeight)
            visibleIndex += 1
        }
        let totalHeight = maxBottom + 14
        scrollView.contentSize = CGSize(width: bounds.width, height: totalHeight)
    }
}
