import AppKit
import UniformTypeIdentifiers

private struct ConversionItem {
    let url: URL
    var status = NSLocalizedString("Ready", comment: "")
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSOpenSavePanelDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private var window: NSWindow!
    private var items: [ConversionItem] = []
    private var busy = false
    private var destination: URL?
    private let scanToggle = NSButton(checkboxWithTitle: NSLocalizedString("Scan documents from photos", comment: ""), target: nil, action: nil)
    private let table = NSTableView()
    private let addButton = NSButton(title: NSLocalizedString("Add files…", comment: ""), target: nil, action: #selector(addFiles))
    private let clearButton = NSButton(title: NSLocalizedString("Clear list", comment: ""), target: nil, action: #selector(clearFiles))
    private let convertButton = NSButton(title: NSLocalizedString("Save PDFs…", comment: ""), target: nil, action: #selector(convertFiles))
    private let revealButton = NSButton(title: NSLocalizedString("Open output folder", comment: ""), target: nil, action: #selector(revealFolder))
    private let statusLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Add files to convert to PDF.", comment: ""))
    private let detailLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Word, Excel, PowerPoint, text, images, and PDFs.", comment: ""))
    private let progress = NSProgressIndicator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        createMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "pdf Converter"
        window.delegate = self
        window.minSize = NSSize(width: 660, height: 510)
        window.isReleasedWhenClosed = false
        let root = NSView()
        window.contentView = root

        let title = NSTextField(labelWithString: NSLocalizedString("Convert files to PDF", comment: ""))
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        let description = NSTextField(wrappingLabelWithString: NSLocalizedString("Choose your files, then select an output folder.", comment: ""))
        description.font = .systemFont(ofSize: 13)

        for button in [addButton, clearButton, convertButton, revealButton] {
            button.target = self
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.setContentHuggingPriority(.required, for: .horizontal)
        }
        addButton.keyEquivalent = "o"
        addButton.keyEquivalentModifierMask = .command
        convertButton.keyEquivalent = "\r"
        convertButton.keyEquivalentModifierMask = []
        let spacer = NSView()
        let actions = NSStackView(views: [addButton, clearButton, spacer, scanToggle])
        actions.orientation = .horizontal
        actions.spacing = 8

        let fileColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        fileColumn.title = NSLocalizedString("Source file", comment: "")
        fileColumn.width = 340
        fileColumn.minWidth = 220
        let resultColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        resultColumn.title = NSLocalizedString("Conversion result", comment: "")
        resultColumn.width = 360
        resultColumn.minWidth = 220
        table.addTableColumn(fileColumn)
        table.addTableColumn(resultColumn)
        table.delegate = self
        table.dataSource = self
        table.rowHeight = 34
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.allowsColumnReordering = false
        table.setAccessibilityLabel(NSLocalizedString("Files to convert", comment: ""))
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.maximumNumberOfLines = 3
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        progress.style = .bar
        progress.isIndeterminate = false
        progress.isHidden = true

        let bottomSpacer = NSView()
        let bottom = NSStackView(views: [revealButton, bottomSpacer, convertButton])
        bottom.orientation = .horizontal
        bottom.spacing = 12
        let footnote = NSTextField(labelWithString: NSLocalizedString("Each file produces one PDF. Your original files are preserved.", comment: ""))
        footnote.font = .systemFont(ofSize: 12)

        for view in [title, description, actions, scroll, statusLabel, detailLabel, progress, bottom, footnote] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
            view.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 26).isActive = true
            view.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -26).isActive = true
        }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            description.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 7),
            actions.topAnchor.constraint(equalTo: description.bottomAnchor, constant: 22),
            actions.heightAnchor.constraint(equalToConstant: 34),
            scroll.topAnchor.constraint(equalTo: actions.bottomAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -14),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            statusLabel.bottomAnchor.constraint(equalTo: detailLabel.topAnchor, constant: -6),
            detailLabel.heightAnchor.constraint(equalToConstant: 46),
            detailLabel.bottomAnchor.constraint(equalTo: progress.topAnchor, constant: -8),
            progress.heightAnchor.constraint(equalToConstant: 6),
            progress.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -13),
            bottom.heightAnchor.constraint(equalToConstant: 34),
            bottom.bottomAnchor.constraint(equalTo: footnote.topAnchor, constant: -14),
            footnote.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20)
        ])
        refreshButtons()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showCredits() {
        if let url = Bundle.main.url(forResource: "CREDITS", withExtension: "txt") {
            NSWorkspace.shared.open(url)
        }
    }

    private func createMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let credits = appMenu.addItem(withTitle: NSLocalizedString("Third-party credits", comment: ""), action: #selector(showCredits), keyEquivalent: "")
        credits.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: NSLocalizedString("Quit pdf Converter", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: NSLocalizedString("Cut", comment: ""), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: NSLocalizedString("Copy", comment: ""), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: NSLocalizedString("Paste", comment: ""), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: NSLocalizedString("Select all", comment: ""), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        if url.hasDirectoryPath { return true }
        return PDFConverter.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    @objc private func addFiles() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("Choose files to convert to PDF", comment: "")
        panel.prompt = NSLocalizedString("Add", comment: "")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = PDFConverter.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.delegate = self
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self = self else { return }
            for url in panel.urls {
                guard !self.items.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else { continue }
                self.items.append(ConversionItem(url: url))
            }
            self.table.reloadData()
            self.statusLabel.stringValue = String(format: NSLocalizedString("Files in queue: %@", comment: ""), String(describing: self.items.count))
            self.detailLabel.stringValue = NSLocalizedString("Click Save PDFs to choose the output folder.", comment: "")
            self.refreshButtons()
        }
    }

    @objc private func clearFiles() {
        guard !busy else { return }
        items.removeAll()
        table.reloadData()
        statusLabel.stringValue = NSLocalizedString("Add files to convert to PDF.", comment: "")
        detailLabel.stringValue = NSLocalizedString("Word, Excel, PowerPoint, text, images, and PDFs.", comment: "")
        progress.isHidden = true
        refreshButtons()
    }

    @objc private func convertFiles() {
        guard !busy, !items.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("Choose an output folder", comment: "")
        panel.prompt = NSLocalizedString("Save here", comment: "")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = destination
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let folder = panel.url, let self = self else { return }
            self.beginConversion(to: folder)
        }
    }

    private func beginConversion(to folder: URL) {
        let engine = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/LibreOffice.app/Contents/MacOS/soffice")
        let scanImages = scanToggle.state == .on
        let inputs = items.map(\.url)
        busy = true
        destination = folder
        for index in items.indices { items[index].status = NSLocalizedString("Waiting", comment: "") }
        table.reloadData()
        progress.minValue = 0
        progress.maxValue = Double(inputs.count)
        progress.doubleValue = 0
        progress.isHidden = false
        detailLabel.stringValue = folder.path
        refreshButtons()

        DispatchQueue.global(qos: .userInitiated).async {
            var successCount = 0
            for (index, input) in inputs.enumerated() {
                DispatchQueue.main.async {
                    self.items[index].status = NSLocalizedString("Converting…", comment: "")
                    self.statusLabel.stringValue = String(format: NSLocalizedString("Converting file %@ of %@: %@", comment: ""), String(describing: index + 1), String(describing: inputs.count), String(describing: input.lastPathComponent))
                    self.table.reloadData()
                    self.table.scrollRowToVisible(index)
                }
                let result: String
                do {
                    let output = try autoreleasepool { try PDFConverter.convert(input, to: folder, engine: engine, scanImages: scanImages) }
                    result = String(format: NSLocalizedString("Saved: %@", comment: ""), String(describing: output.lastPathComponent))
                    successCount += 1
                } catch {
                    result = String(format: NSLocalizedString("Failed: %@", comment: ""), String(describing: error.localizedDescription))
                }
                DispatchQueue.main.async {
                    self.items[index].status = result
                    self.table.reloadData()
                    self.progress.doubleValue = Double(index + 1)
                }
            }
            let successes = successCount
            DispatchQueue.main.async {
                self.busy = false
                let failures = inputs.count - successes
                self.statusLabel.stringValue = String(format: NSLocalizedString("Finished. %@ succeeded, %@ failed.", comment: ""), String(describing: successes), String(describing: failures))
                self.detailLabel.stringValue = failures == 0
                    ? String(format: NSLocalizedString("PDFs saved in %@", comment: ""), String(describing: folder.path))
                    : NSLocalizedString("Select a failed row for details. Successful conversions have been saved.", comment: "")
                self.refreshButtons()
                NSAccessibility.post(element: self.statusLabel, notification: .valueChanged)
            }
        }
    }

    @objc private func revealFolder() {
        guard let folder = destination else { return }
        NSWorkspace.shared.open(folder)
    }

    private func refreshButtons() {
        scanToggle.isEnabled = !busy
        addButton.isEnabled = !busy
        clearButton.isEnabled = !busy && !items.isEmpty
        convertButton.isEnabled = !busy && !items.isEmpty
        revealButton.isEnabled = !busy && destination != nil
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let value = tableColumn?.identifier.rawValue == "file" ? item.url.lastPathComponent : item.status
        let text = NSTextField(labelWithString: value)
        text.font = .systemFont(ofSize: 13)
        text.lineBreakMode = .byTruncatingMiddle
        text.toolTip = tableColumn?.identifier.rawValue == "file" ? item.url.path : item.status
        let cell = NSTableCellView()
        cell.textField = text
        cell.addSubview(text)
        text.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 7),
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -7),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !busy, items.indices.contains(table.selectedRow) else { return }
        let item = items[table.selectedRow]
        detailLabel.stringValue = "\(item.url.lastPathComponent): \(item.status)"
        detailLabel.toolTip = detailLabel.stringValue
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        applicationShouldTerminate(NSApp) == .terminateNow
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard busy else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Conversion in progress", comment: "")
        alert.informativeText = NSLocalizedString("Wait for the conversion to finish before closing the app.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Go back", comment: ""))
        alert.runModal()
        return .terminateCancel
    }
}

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
