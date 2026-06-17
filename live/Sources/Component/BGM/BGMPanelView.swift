//
//  BGMPanelView.swift
//  TUILiveKit
//
//  BGM panel aligned with TUILiveKit v2.9.0 MusicView.
//

import UIKit
import SnapKit
import AtomicX

class BGMPanelView: RTCBaseView {

    private let store: BGMStore

    // MARK: - Subviews

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 16, weight: .medium)
        label.textColor = .g7
        label.text = .bgmPanelTitle
        label.textAlignment = .center
        return label
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(BGMItemCell.self, forCellReuseIdentifier: BGMItemCell.identifier)
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.rowHeight = 56
        tv.showsVerticalScrollIndicator = false
        tv.dataSource = self
        return tv
    }()

    // MARK: - Init

    init(store: BGMStore) {
        self.store = store
        super.init(frame: .zero)
        self.store.onStateChanged = { [weak self] in
            self?.tableView.reloadData()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - RTCBaseView

    override func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(tableView)
    }

    override func activateConstraints() {
        snp.makeConstraints { make in
            make.height.equalTo(340.scale375Height())
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20.scale375())
            make.centerX.equalToSuperview()
            make.height.equalTo(24.scale375())
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20.scale375())
            make.leading.trailing.equalToSuperview().inset(16.scale375())
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-16.scale375())
        }
    }

    override func setupViewStyle() {
        backgroundColor = .g2
        layer.cornerRadius = 20
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
}

// MARK: - UITableViewDataSource

extension BGMPanelView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return store.musicList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BGMItemCell.identifier, for: indexPath) as! BGMItemCell
        let item = store.musicList[indexPath.row]
        cell.configure(item: item, isPlaying: store.isPlaying(item))
        cell.onStartPlay = { [weak self] bgmItem in
            self?.store.startPlay(bgmItem)
        }
        cell.onStopPlay = { [weak self] bgmItem in
            self?.store.stopPlay(bgmItem)
        }
        return cell
    }
}

// MARK: - Localized Strings

private extension String {
    static let bgmPanelTitle = internalLocalized("common_music")
}
