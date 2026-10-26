extension ContactListConfig {
    public init(showNewContacts: Bool? = nil,
                showGroupApplications: Bool? = nil,
                showMyGroups: Bool? = nil,
                showBlacklist: Bool? = nil,
                showSearchBar: Bool? = nil,
                itemCustomizer: ContactListItemCustomizer? = nil) {
        self.userShowNewContacts = showNewContacts
        self.userShowGroupApplications = showGroupApplications
        self.userShowMyGroups = showMyGroups
        self.userShowBlacklist = showBlacklist
        self.userShowSearchBar = showSearchBar
        self.userItemCustomizer = itemCustomizer
    }

    public var showNewContacts: Bool {
        get { userShowNewContacts ?? true }
        set { userShowNewContacts = newValue }
    }

    public var showGroupApplications: Bool {
        get { userShowGroupApplications ?? true }
        set { userShowGroupApplications = newValue }
    }

    public var showMyGroups: Bool {
        get { userShowMyGroups ?? true }
        set { userShowMyGroups = newValue }
    }

    public var showBlacklist: Bool {
        get { userShowBlacklist ?? true }
        set { userShowBlacklist = newValue }
    }

    public var showSearchBar: Bool {
        get { userShowSearchBar ?? true }
        set { userShowSearchBar = newValue }
    }

    public var itemCustomizer: ContactListItemCustomizer? {
        get { userItemCustomizer }
        set { userItemCustomizer = newValue }
    }
}
