import AtomicXCore
import Combine
import SnapKit
import UIKit

final class CreateC2CConversationViewControllerImpl: RTCBaseView {
    var onUserSelected: ((AZOrderedListItem) -> Void)?

    private lazy var listView = AZOrderedListView(showIndexBar: true) { [weak self] item in
        self?.onUserSelected?(item)
    }

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var cancellables = Set<AnyCancellable>()

    init() {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func constructViewHierarchy() {
        addSubview(listView)
        addSubview(loadingIndicator)
    }

    public override func activateConstraints() {
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    public override func bindInteraction() {
        subscribeFriendList()
        loadFriendList()
    }

    private func subscribeFriendList() {
        ContactStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \ContactState.friendList))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] friendList in
                self?.applyFriendList(friendList)
            }
            .store(in: &cancellables)
    }

    private func loadFriendList() {
        let current = ContactStore.shared.state.value.friendList
        if !current.isEmpty {
            applyFriendList(current)
        } else {
            loadingIndicator.startAnimating()
        }
        ContactStore.shared.loadFriends(completion: { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
            }
        })
    }

    private func applyFriendList(_ friendList: [ContactInfo]) {
        loadingIndicator.stopAnimating()
        listView.setItems(ConversationCreateSupport.orderedListItems(from: friendList))
    }
}
