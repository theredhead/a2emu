import Cocoa
import UniformTypeIdentifiers

private final class SnapshotBackground: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
    }
}

private final class SnapshotCard: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("SnapshotCard")
    private let preview = NSImageView()
    private let name = NSTextField(labelWithString: "")
    private let date = NSTextField(labelWithString: "")

    override func loadView() {
        let card = NSBox()
        card.boxType = .custom
        card.cornerRadius = 10
        card.borderWidth = 2
        card.fillColor = .controlBackgroundColor
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.wantsLayer = true
        preview.layer?.backgroundColor = NSColor.black.cgColor
        name.font = .systemFont(ofSize: 13, weight: .semibold)
        name.lineBreakMode = .byTruncatingTail
        date.font = .systemFont(ofSize: 11)
        date.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [preview, name, date])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            preview.widthAnchor.constraint(equalTo: stack.widthAnchor),
            preview.heightAnchor.constraint(equalToConstant: 152),
            name.widthAnchor.constraint(equalTo: stack.widthAnchor),
            date.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        view = card
        updateSelection()
    }

    func configure(_ snapshot: PlayerSnapshot, at url: URL) {
        name.stringValue = snapshot.title
        date.stringValue = DateFormatter.localizedString(
            from: snapshot.createdAt, dateStyle: .medium, timeStyle: .medium)
        preview.image = NSImage(contentsOf: url.appendingPathComponent(PlayerSnapshot.previewName))
        view.toolTip = snapshot.gameName + " · " + date.stringValue
    }

    override var isSelected: Bool { didSet { updateSelection() } }

    private func updateSelection() {
        (view as? NSBox)?.borderColor = isSelected ? .controlAccentColor : .clear
    }
}

/// A dated preview grid; loading validates package integrity before touching the emulator.
final class SnapshotBrowser: NSWindowController, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private weak var player: AppDelegate?
    private let collection = NSCollectionView()
    private let status = NSTextField(labelWithString: "")
    private let restore = NSButton(title: "Restore Snapshot", target: nil, action: nil)
    private let remove = NSButton(title: "Delete…", target: nil, action: nil)
    private var snapshots: [(URL, PlayerSnapshot)] = []

    init(player: AppDelegate) {
        self.player = player
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 610),
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.contentView = SnapshotBackground(frame: NSRect(x: 0, y: 0, width: 850, height: 610))
        window.title = "Saved Snapshots — " + PlayerManifest.displayName
        window.minSize = NSSize(width: 590, height: 420)
        super.init(window: window)
        let save = NSButton(title: "Save Snapshot…", target: self, action: #selector(saveSnapshot(_:)))
        let importButton = NSButton(title: "Import…", target: self, action: #selector(importSnapshot(_:)))
        let reveal = NSButton(title: "Show in Finder", target: self, action: #selector(revealSnapshots(_:)))
        restore.target = self
        restore.action = #selector(restoreSnapshot(_:))
        remove.target = self
        remove.action = #selector(deleteSnapshot(_:))
        for button in [save, importButton, reveal, restore, remove] { button.bezelStyle = .rounded }
        let heading = NSTextField(labelWithString: "Your saved moments")
        heading.font = .systemFont(ofSize: 24, weight: .bold)
        let help = NSTextField(
            wrappingLabelWithString:
                "Choose a snapshot to return to that moment. Each snapshot includes its own disk state.")
        help.textColor = .secondaryLabelColor
        let actions = NSStackView(views: [save, importButton, reveal])
        actions.spacing = 10
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 246, height: 226)
        layout.minimumInteritemSpacing = 14
        layout.minimumLineSpacing = 14
        layout.sectionInset = NSEdgeInsets(top: 8, left: 0, bottom: 12, right: 0)
        collection.frame = NSRect(x: 0, y: 0, width: 802, height: 350)
        collection.autoresizingMask = [.width]
        collection.collectionViewLayout = layout
        collection.isSelectable = true
        collection.allowsMultipleSelection = false
        collection.backgroundColors = [.windowBackgroundColor]
        collection.register(SnapshotCard.self, forItemWithIdentifier: SnapshotCard.identifier)
        collection.dataSource = self
        collection.delegate = self
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = collection
        let footer = NSStackView(views: [status, remove, restore])
        footer.spacing = 10
        status.textColor = .secondaryLabelColor
        status.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [heading, help, actions, scroll, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -20),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 230),
        ])
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("Use init(player:)") }

    func reload() {
        guard let player = player else { return }
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: player.snapshotsDirectory, withIntermediateDirectories: true)
            var urls = try manager.contentsOfDirectory(
                at: player.snapshotsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            if player.machine.startupSnapshot == true,
                let startup = Bundle.main.resourceURL?.appendingPathComponent("Startup.a2snapshot")
            {
                urls.append(startup)
            }
            snapshots = urls.filter { $0.pathExtension == PlayerSnapshot.fileExtension }.compactMap { url in
                guard let bytes = try? Data(contentsOf: url.appendingPathComponent("Snapshot.json")),
                    bytes.count < 1_048_576,
                    let snapshot = try? JSONDecoder().decode(PlayerSnapshot.self, from: bytes)
                else { return nil }
                var displayURL = url
                if url.deletingLastPathComponent() == player.snapshotsDirectory,
                    UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil
                {
                    let named = player.snapshotsDirectory.appendingPathComponent(snapshot.fileName)
                    if !manager.fileExists(atPath: named.path),
                        (try? manager.moveItem(at: url, to: named)) != nil
                    {
                        displayURL = named
                        player.setSnapshotFinderIcon(at: named)
                    }
                }
                return (displayURL, snapshot)
            }.sorted { $0.1.createdAt > $1.1.createdAt }
            collection.selectionIndexPaths = []
            collection.reloadData()
            status.stringValue =
                snapshots.isEmpty
                ? "No snapshots yet. Save your first moment." : "\(snapshots.count) saved snapshots"
            updateButtons()
        } catch { showError(error) }
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        snapshots.count
    }

    func collectionView(
        _ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item =
            collectionView.makeItem(withIdentifier: SnapshotCard.identifier, for: indexPath) as! SnapshotCard
        let (url, snapshot) = snapshots[indexPath.item]
        item.configure(snapshot, at: url)
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateButtons()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateButtons()
    }

    private var selectedURL: URL? {
        guard let index = collection.selectionIndexPaths.first?.item, snapshots.indices.contains(index) else {
            return nil
        }
        return snapshots[index].0
    }

    private func updateButtons() {
        restore.isEnabled = selectedURL != nil
        remove.isEnabled = selectedURL?.deletingLastPathComponent() == player?.snapshotsDirectory
    }

    @objc private func saveSnapshot(_ sender: Any?) {
        guard let player = player else { return }
        let alert = NSAlert()
        alert.messageText = "Save Snapshot"
        alert.informativeText = "Give this moment a name. Its disks and a preview will be saved with it."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let name = NSTextField(string: "Saved game")
        name.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = name
        alert.window.initialFirstResponder = name
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let title = name.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        status.stringValue = "Saving snapshot…"
        window?.displayIfNeeded()
        do {
            let url = try player.saveSnapshot(title: title)
            reload()
            if let index = snapshots.firstIndex(where: { $0.0 == url }) {
                collection.selectionIndexPaths = [IndexPath(item: index, section: 0)]
                updateButtons()
            }
        } catch { showError(error) }
    }

    @objc private func restoreSnapshot(_ sender: Any?) {
        guard let url = selectedURL, let player = player else { return }
        status.stringValue = "Restoring snapshot…"
        window?.displayIfNeeded()
        do {
            try player.restoreSnapshot(at: url)
            player.setEmulationPaused(false)
            window?.close()
            player.mainwin_info.x_win?.makeKeyAndOrderFront(nil)
        } catch { showError(error) }
    }

    @objc private func importSnapshot(_ sender: Any?) {
        guard let player = player else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = [UTType(exportedAs: "nl.theredhead.a2emu.snapshot")]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let snapshot = try PlayerSnapshot.read(at: url)
            guard snapshot.diskFiles == player.machine.diskFiles else {
                throw PlayerManifest.failure("This snapshot uses a different set of disks.")
            }
            let destination = player.snapshotsDirectory.appendingPathComponent(
                snapshot.fileName)
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw PlayerManifest.failure("This snapshot is already in your library.")
            }
            try FileManager.default.copyItem(at: url, to: destination)
            player.setSnapshotFinderIcon(at: destination)
            reload()
        } catch { showError(error) }
    }

    @objc private func revealSnapshots(_ sender: Any?) {
        guard let player = player else { return }
        NSWorkspace.shared.open(player.snapshotsDirectory)
    }

    @objc private func deleteSnapshot(_ sender: Any?) {
        guard let url = selectedURL, url.deletingLastPathComponent() == player?.snapshotsDirectory else {
            return
        }
        let alert = NSAlert()
        alert.messageText = "Move this snapshot to the Trash?"
        alert.informativeText = "Your running game and its working disks will be kept."
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            reload()
        } catch { showError(error) }
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Snapshot could not be completed"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
