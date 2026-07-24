import AppKit

final class WindowListViewController: NSViewController {
    private let service = WindowCatalogService()
    private let activator = WindowActivator()

    private var allWindows: [WindowSnapshot] = []
    private var visibleWindows: [WindowSnapshot] = []

    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let footerLabel = NSTextField(labelWithString: "")

    var onRequestClose: (() -> Void)?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 480))
        setupLayout()
        refresh()
    }

    func refresh() {
        allWindows = service.fetchWindows()
        applyFilter()
    }

    private func setupLayout() {
        searchField.placeholderString = "Search by app or window title"
        searchField.target = self
        searchField.action = #selector(searchChanged)

        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = "App"
        appColumn.width = 180

        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Window"
        titleColumn.width = 260

        let screenColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("screen"))
        screenColumn.title = "Display"
        screenColumn.width = 120

        tableView.addTableColumn(appColumn)
        tableView.addTableColumn(titleColumn)
        tableView.addTableColumn(screenColumn)
        tableView.headerView = NSTableHeaderView()
        tableView.rowHeight = 30
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(activateSelectedWindow)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        footerLabel.textColor = .secondaryLabelColor
        footerLabel.font = .systemFont(ofSize: 11)

        let stack = NSStackView(views: [searchField, scrollView, footerLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func searchChanged() {
        applyFilter()
    }

    private func applyFilter() {
        let term = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if term.isEmpty {
            visibleWindows = allWindows
        } else {
            visibleWindows = allWindows.filter {
                $0.appName.localizedCaseInsensitiveContains(term) || $0.windowTitle.localizedCaseInsensitiveContains(term)
            }
        }

        footerLabel.stringValue = "Showing \(visibleWindows.count) windows"
        tableView.reloadData()
    }

    @objc private func activateSelectedWindow() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < visibleWindows.count else { return }

        let selection = visibleWindows[selectedRow]
        activator.activateWindow(selection)
        onRequestClose?()
    }
}

extension WindowListViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleWindows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < visibleWindows.count, let tableColumn else { return nil }
        let item = visibleWindows[row]
        let id = tableColumn.identifier.rawValue

        if id == "app" {
            let cell = NSTableCellView()
            let iconView = NSImageView(frame: NSRect(x: 2, y: 7, width: 16, height: 16))
            iconView.image = item.icon
            iconView.imageScaling = .scaleProportionallyUpOrDown

            let textField = NSTextField(labelWithString: item.appName)
            textField.frame = NSRect(x: 24, y: 5, width: tableColumn.width - 28, height: 20)
            textField.lineBreakMode = .byTruncatingTail

            cell.addSubview(iconView)
            cell.addSubview(textField)
            return cell
        }

        if id == "title" {
            let textField = NSTextField(labelWithString: item.windowTitle)
            textField.lineBreakMode = .byTruncatingTail
            return textField
        }

        let textField = NSTextField(labelWithString: item.screenName)
        textField.textColor = .secondaryLabelColor
        textField.lineBreakMode = .byTruncatingTail
        return textField
    }
}
