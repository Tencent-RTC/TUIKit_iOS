public struct ContactListConfig {
    public var showNewContacts: Bool? = nil
    public var showGroupApplications: Bool? = nil
    public var showMyGroups: Bool? = nil
    public var showBlacklist: Bool? = nil
    public var showSearchBar: Bool? = nil
    public var itemCustomizer: ContactListItemCustomizer? = nil

    public init(showNewContacts: Bool? = nil,
                showGroupApplications: Bool? = nil,
                showMyGroups: Bool? = nil,
                showBlacklist: Bool? = nil,
                showSearchBar: Bool? = nil,
                itemCustomizer: ContactListItemCustomizer? = nil) {
        self.showNewContacts = showNewContacts
        self.showGroupApplications = showGroupApplications
        self.showMyGroups = showMyGroups
        self.showBlacklist = showBlacklist
        self.showSearchBar = showSearchBar
        self.itemCustomizer = itemCustomizer
    }
}
