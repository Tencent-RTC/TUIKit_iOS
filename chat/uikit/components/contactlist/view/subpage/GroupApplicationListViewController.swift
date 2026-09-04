import UIKit
import Combine
import SnapKit
import AtomicXCore

final class GroupApplicationListViewController: UIViewController {
    private let viewModel = GroupApplicationListViewModel()

    private var applications: [GroupApplicationInfo] = []

    private var cancellables = Set<AnyCancellable>()

    private static let listTopInset: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let emptyFontSize: CGFloat = 17

    private static let estimatedRowHeight: CGFloat = 80

    private static let navigationBarHeight: CGFloat = 44

    private static let toastDuration: TimeInterval = 3

    private lazy var navigationBar = SubPageNavigationBar(title: LocalizedChatString("ContactsGroupApplicationTitle"))

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = Self.estimatedRowHeight
        table.contentInset = UIEdgeInsets(top: Self.listTopInset, left: 0, bottom: 0, right: 0)
        table.register(GroupApplicationCell.self, forCellReuseIdentifier: GroupApplicationCell.reuseIdentifier)
        return table
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = LocalizedChatString("ContactNoGroupApplication")
        label.font = .systemFont(ofSize: Self.emptyFontSize)
        label.textColor = TUIChatKitTheme.colors.textColorSecondary
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHierarchy()
        setupStyle()
        bindViewModel()
        viewModel.loadData()
    }

    private func setupHierarchy() {
        navigationBar.onClose = { [weak self] in
            self?.dismiss(animated: true)
        }
        view.addSubview(navigationBar)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        navigationBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.navigationBarHeight)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        emptyLabel.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        tableView.dataSource = self
    }

    private func setupStyle() {
        view.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        tableView.backgroundColor = TUIChatKitTheme.colors.bgColorOperate
    }

    private func bindViewModel() {
        viewModel.$applications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self = self else { return }
                self.applications = list
                self.emptyLabel.isHidden = !list.isEmpty
                self.tableView.isHidden = list.isEmpty
                self.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    private func accept(_ application: GroupApplicationInfo) {
        viewModel.accept(application) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    WindowToastManager.shared.show(LocalizedChatString("GroupApplicationAccepted"), type: .success, duration: Self.toastDuration)
                case .failure:
                    WindowToastManager.shared.show(LocalizedChatString("GroupApplicationAcceptFailed"), type: .error, duration: Self.toastDuration)
                }
            }
        }
    }

    private func refuse(_ application: GroupApplicationInfo) {
        viewModel.refuse(application) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    WindowToastManager.shared.show(LocalizedChatString("GroupApplicationDeclined"), type: .success, duration: Self.toastDuration)
                case .failure:
                    WindowToastManager.shared.show(LocalizedChatString("GroupApplicationDeclineFailed"), type: .error, duration: Self.toastDuration)
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension GroupApplicationListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return applications.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: GroupApplicationCell.reuseIdentifier,
            for: indexPath
        ) as? GroupApplicationCell else {
            return UITableViewCell()
        }
        let application = applications[indexPath.row]
        cell.configure(
            with: application,
            onAccept: { [weak self] in self?.accept(application) },
            onRefuse: { [weak self] in self?.refuse(application) }
        )
        return cell
    }
}
