import UIKit

/// Native sheet owned by the Access App, independent of TUILiveKit UI and stores.
final class LogShareViewController: UITableViewController {
    private var files: [LogShareFiles.Entry] = []
    private var busy = false
    private var active = true
    private let worker = DispatchQueue(label: "LiveKitAccess.LogShare", qos: .userInitiated)
    private let formatter = DateFormatter()

    init() {
        super.init(style: .insetGrouped)
        formatter.dateStyle = .short
        formatter.timeStyle = .short
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = text("title")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                          target: self, action: #selector(close))
        loadFiles()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            active = false
        }
    }

    private func text(_ key: String) -> String {
        NSLocalizedString("livekit_access.logs.\(key)", comment: "")
    }

    private func setBusy(_ value: Bool) {
        busy = value
        if value { navigationItem.prompt = nil }
        tableView.isUserInteractionEnabled = !value
        if value {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func loadFiles() {
        setBusy(true)
        worker.async { [weak self] in
            let result = Result { try LogShareFiles.scan() }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active else { return }
                self.setBusy(false)
                switch result {
                case .success(let files):
                    self.files = files
                    self.tableView.reloadData()
                    self.showBackground(files.isEmpty ? self.text("empty") : nil)
                case .failure:
                    self.showBackground(self.text("read_failed"))
                }
            }
        }
    }

    private func showBackground(_ message: String?) {
        let label = UILabel()
        label.text = message
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        tableView.backgroundView = message == nil ? nil : label
    }

    override func numberOfSections(in tableView: UITableView) -> Int { files.isEmpty ? 0 : 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : files.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 1 ? text("single") : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? text("scope") : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        cell.accessoryType = .disclosureIndicator
        if indexPath.section == 0 {
            cell.textLabel?.text = text("archive")
            cell.textLabel?.textColor = .systemBlue
            cell.detailTextLabel?.text = String(format: text("count"), files.count)
        } else {
            let file = files[indexPath.row]
            cell.textLabel?.text = file.url.lastPathComponent
            cell.detailTextLabel?.text = "\(formatter.string(from: file.modified)) · \(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !busy else { return }
        let entries = indexPath.section == 0 ? files : [files[indexPath.row]]
        let archive = indexPath.section == 0
        setBusy(true)
        worker.async { [weak self] in
            let result = Result { try LogShareFiles.prepare(entries, archive: archive) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active, self.viewIfLoaded?.window != nil else {
                    if case .success(let export) = result { export.remove() }
                    return
                }
                self.setBusy(false)
                switch result {
                case .success(let export):
                    self.share(export, source: indexPath)
                case .failure:
                    let alert = UIAlertController(title: self.text("failed"), message: self.text("retry"), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("livekit_access.ok", comment: ""), style: .default) { [weak self] _ in
                        self?.loadFiles()
                    })
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func share(_ export: LogShareFiles.Export, source: IndexPath) {
        let activity = UIActivityViewController(activityItems: [export.file], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = tableView
        activity.popoverPresentationController?.sourceRect = tableView.rectForRow(at: source)
        activity.completionWithItemsHandler = { [weak self] _, _, _, error in
            export.remove()
            guard error != nil else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active else { return }
                self.navigationItem.prompt = self.text("failed")
            }
        }
        present(activity, animated: true)
    }

    @objc private func close() {
        active = false
        dismiss(animated: true)
    }
}
