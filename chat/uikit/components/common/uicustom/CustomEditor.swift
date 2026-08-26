import Foundation

public protocol CustomItem {
    var ID: String { get }
}

public final class CustomEditor<Item: CustomItem> {
    public private(set) var items: [Item]

    private var didBuild = false

    public init(items: [Item]) {
        self.items = items
    }

    public func add(_ item: Item) {
        prepareMutation()
        precondition(!item.ID.isEmpty, "CustomEditor: item ID must not be empty")
        precondition(!items.contains { $0.ID == item.ID }, "CustomEditor: duplicated item ID \(item.ID)")
        items.append(item)
    }

    @discardableResult
    public func remove(_ ID: String) -> Bool {
        prepareMutation()
        let count = items.count
        items.removeAll { $0.ID == ID }
        return items.count != count
    }

    public func replace(_ ID: String, _ transform: (Item) -> Item) {
        prepareMutation()
        guard let index = items.firstIndex(where: { $0.ID == ID }) else { return }
        let replacement = transform(items[index])
        precondition(replacement.ID == ID, "CustomEditor: replacement must keep the same ID")
        items[index] = replacement
    }

    public func insertBefore(_ anchorID: String, _ item: Item) {
        prepareMutation()
        precondition(!item.ID.isEmpty, "CustomEditor: item ID must not be empty")
        precondition(!items.contains { $0.ID == item.ID }, "CustomEditor: duplicated item ID \(item.ID)")
        guard let index = items.firstIndex(where: { $0.ID == anchorID }) else { return }
        items.insert(item, at: index)
    }

    public func insertAfter(_ anchorID: String, _ item: Item) {
        prepareMutation()
        precondition(!item.ID.isEmpty, "CustomEditor: item ID must not be empty")
        precondition(!items.contains { $0.ID == item.ID }, "CustomEditor: duplicated item ID \(item.ID)")
        guard let index = items.firstIndex(where: { $0.ID == anchorID }) else { return }
        items.insert(item, at: index + 1)
    }

    public func moveBefore(_ ID: String, _ anchorID: String) {
        prepareMutation()
        guard ID != anchorID,
              let from = items.firstIndex(where: { $0.ID == ID }),
              let to = items.firstIndex(where: { $0.ID == anchorID }) else { return }
        let item = items.remove(at: from)
        let target = items.firstIndex(where: { $0.ID == anchorID }) ?? to
        items.insert(item, at: target)
    }

    public func moveAfter(_ ID: String, _ anchorID: String) {
        prepareMutation()
        guard ID != anchorID,
              let from = items.firstIndex(where: { $0.ID == ID }),
              let to = items.firstIndex(where: { $0.ID == anchorID }) else { return }
        let item = items.remove(at: from)
        let target = items.firstIndex(where: { $0.ID == anchorID }) ?? (to - 1)
        items.insert(item, at: target + 1)
    }

    public func clear() {
        prepareMutation()
        items.removeAll()
    }

    public func build() -> [Item] {
        didBuild = true
        return items
    }

    private func prepareMutation() {
        precondition(!didBuild, "CustomEditor: cannot mutate after build()")
    }
}
