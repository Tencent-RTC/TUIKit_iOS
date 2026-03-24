import UIKit
import SnapKit
import AtomicXCore

/**
 * Business scenario: feature list page
 *
 * Displays entry cards for four progressive stages:
 * 1. BasicStreaming - Basic push/pull streaming
 * 2. Interactive - Real-time interaction
 * 3. CoGuest - Audience connection
 * 4. LivePK - Live PK battle
 */
class FeatureListViewController: UIViewController {

    // MARK: - Data Model

    struct FeatureItem {
        let titleKey: String
        let descriptionKey: String
        let icon: String
        let stage: FeatureStage
    }

    enum FeatureStage {
        case basicStreaming
        case interactive
        case coGuest
        case livePK
    }

    // MARK: - Properties

    private let features: [FeatureItem] = [
        FeatureItem(
            titleKey: "stage.basicStreaming",
            descriptionKey: "stage.basicStreaming.desc",
            icon: "video.fill",
            stage: .basicStreaming
        ),
        FeatureItem(
            titleKey: "stage.interactive",
            descriptionKey: "stage.interactive.desc",
            icon: "gift.fill",
            stage: .interactive
        ),
        FeatureItem(
            titleKey: "stage.coGuest",
            descriptionKey: "stage.coGuest.desc",
            icon: "person.2.fill",
            stage: .coGuest
        ),
        FeatureItem(
            titleKey: "stage.livePK",
            descriptionKey: "stage.livePK.desc",
            icon: "flame.fill",
            stage: .livePK
        )
    ]

    // MARK: - UI Components

    private lazy var collectionView: UICollectionView = {
        let layout = createLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(FeatureCell.self, forCellWithReuseIdentifier: FeatureCell.reuseIdentifier)
        collectionView.register(SectionHeaderView.self,
                               forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                               withReuseIdentifier: SectionHeaderView.reuseIdentifier)
        return collectionView
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        navigationItem.title = "featureList.title".localized

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { sectionIndex, environment in
            // Step 1: Create the card item
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(120)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            // Step 2: Create the group
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(120)
            )
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

            // Step 3: Create the section
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 16
            section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

            // Step 4: Add the header
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(44)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]

            return section
        }
    }

    // MARK: - Actions

    private func navigateToStage(_ stage: FeatureStage) {
        // Use an action sheet to choose the role
        let alert = UIAlertController(
            title: "roleSelect.title".localized,
            message: "roleSelect.subtitle".localized,
            preferredStyle: .actionSheet
        )

        // Host option: use live_{userID} directly as the room ID without input
        let anchorAction = UIAlertAction(title: "\(Role.anchor.titleKey.localized)", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let liveID = self.generateAnchorLiveID()
            self.navigateToFunctionPage(role: .anchor, stage: stage, liveID: liveID)
        }
        alert.addAction(anchorAction)

        // Audience option: show a room ID input alert
        let audienceAction = UIAlertAction(title: "\(Role.audience.titleKey.localized)", style: .default) { [weak self] _ in
            self?.showLiveIDInput(role: .audience, stage: stage)
        }
        alert.addAction(audienceAction)

        // Cancel
        let cancelAction = UIAlertAction(title: "common.cancel".localized, style: .cancel)
        alert.addAction(cancelAction)

        present(alert, animated: true)
    }

    /// Get the host's room ID by directly using the currently logged-in userID
    private func generateAnchorLiveID() -> String {
        return LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
    }

    /// Show a room ID input alert (audience only)
    private func showLiveIDInput(role: Role, stage: FeatureStage) {
        let title = "liveIDInput.title.audience".localized
        let message = "liveIDInput.message.audience".localized

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        // Add a text field
        alert.addTextField { textField in
            textField.placeholder = "liveIDInput.placeholder".localized
            textField.keyboardType = .numberPad
            textField.clearButtonMode = .whileEditing
        }

        // Confirm button
        let confirmAction = UIAlertAction(title: "common.confirm".localized, style: .default) { [weak self] _ in
            guard let liveID = alert.textFields?.first?.text, !liveID.isEmpty else {
                self?.showEmptyLiveIDAlert(role: role, stage: stage)
                return
            }
            self?.navigateToFunctionPage(role: role, stage: stage, liveID: liveID)
        }
        alert.addAction(confirmAction)

        // Cancel button
        let cancelAction = UIAlertAction(title: "common.cancel".localized, style: .cancel)
        alert.addAction(cancelAction)

        present(alert, animated: true)
    }

    /// Show a prompt indicating that the room ID cannot be empty
    private func showEmptyLiveIDAlert(role: Role, stage: FeatureStage) {
        let alert = UIAlertController(
            title: "common.warning".localized,
            message: "liveIDInput.error.empty".localized,
            preferredStyle: .alert
        )
        let retryAction = UIAlertAction(title: "common.confirm".localized, style: .default) { [weak self] _ in
            self?.showLiveIDInput(role: role, stage: stage)
        }
        alert.addAction(retryAction)
        present(alert, animated: true)
    }

    private func navigateToFunctionPage(role: Role, stage: FeatureStage, liveID: String) {
        switch stage {
        case .basicStreaming:
            let vc = BasicStreamingViewController(role: role, liveID: liveID)
            navigationController?.pushViewController(vc, animated: true)

        case .interactive:
            let vc = InteractiveViewController(role: role, liveID: liveID)
            navigationController?.pushViewController(vc, animated: true)

        case .coGuest:
            let vc = MultiConnectViewController(role: role, liveID: liveID)
            navigationController?.pushViewController(vc, animated: true)

        case .livePK:
            let vc = LivePKViewController(role: role, liveID: liveID)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - UICollectionViewDataSource

extension FeatureListViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return features.count
    }

    func collectionView(_ collectionView: UICollectionView,
                       cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FeatureCell.reuseIdentifier,
            for: indexPath
        ) as? FeatureCell else {
            return UICollectionViewCell()
        }

        let feature = features[indexPath.item]
        cell.configure(title: feature.titleKey.localized,
                      description: feature.descriptionKey.localized,
                      icon: feature.icon,
                      index: indexPath.item)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                       viewForSupplementaryElementOfKind kind: String,
                       at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SectionHeaderView.reuseIdentifier,
                for: indexPath
              ) as? SectionHeaderView else {
            return UICollectionReusableView()
        }

        header.configure(title: "featureList.section.header".localized)
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension FeatureListViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let feature = features[indexPath.item]
        navigateToStage(feature.stage)
    }
}

// MARK: - FeatureCell

private class FeatureCell: UICollectionViewCell {

    static let reuseIdentifier = "FeatureCell"

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()

    private let arrowView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let indexLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = .systemBlue
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(indexLabel)
        containerView.addSubview(iconView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(arrowView)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        indexLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(16)
            make.width.height.equalTo(20)
        }

        iconView.snp.makeConstraints { make in
            make.leading.equalTo(indexLabel.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(16)
            make.trailing.equalTo(arrowView.snp.leading).offset(-8)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-16)
        }

        arrowView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(12)
            make.height.equalTo(20)
        }
    }

    func configure(title: String, description: String, icon: String, index: Int) {
        titleLabel.text = title
        descriptionLabel.text = description
        iconView.image = UIImage(systemName: icon)
        indexLabel.text = "\(index + 1)"

        // Use different colors for different stages
        let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemRed]
        indexLabel.backgroundColor = colors[index % colors.count]
        iconView.tintColor = colors[index % colors.count]
    }
}

// MARK: - SectionHeaderView

private class SectionHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "SectionHeaderView"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title
    }
}
