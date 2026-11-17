extension ContactListConfig {
    var _showNewContacts: Bool {
        showNewContacts ?? true
    }

    var _showGroupApplications: Bool {
        showGroupApplications ?? true
    }

    var _showMyGroups: Bool {
        showMyGroups ?? true
    }

    var _showBlacklist: Bool {
        showBlacklist ?? true
    }

    var _showSearchBar: Bool {
        showSearchBar ?? true
    }

    var _itemCustomizer: ContactListItemCustomizer? {
        itemCustomizer
    }
}
