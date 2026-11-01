import Cocoa
import UniformTypeIdentifiers

private let builderIntl = BuilderIntl()
private let commonIntl = CommonIntl()

/// A completed dialog choice; creation remains an application/storage responsibility.
struct BlankDiskSelection {
    let image: BlankDiskImage
    let format: BlankDiskFormat
    let url: URL
    let addToPlayer: Bool
}

/// Owns the capacity/format dialog and its control lifetimes; it never creates or overwrites disk data.
final class BlankDiskCreationPanel: NSObject {
    private var blankDiskFormatMenu: NSPopUpButton?

    @objc func blankDiskCapacityChanged(_ sender: NSPopUpButton) {
        guard let formats = blankDiskFormatMenu else { return }

        let image = BlankDiskImage.allCases[sender.indexOfSelectedItem]
        for format in BlankDiskFormat.allCases {
            formats.item(at: format.rawValue)?.isEnabled = image.supports(format)
        }
        if !image.supports(BlankDiskFormat.allCases[formats.indexOfSelectedItem]) {
            formats.selectItem(at: BlankDiskFormat.proDOS.rawValue)
        }
    }

    func choose(allowAdding: Bool) -> BlankDiskSelection? {
        let alert = NSAlert()
        alert.messageText = builderIntl.blankDiskTitle
        alert.informativeText =
            builderIntl.blankDiskExplanation
        alert.addButton(withTitle: commonIntl.continueAction)
        alert.addButton(withTitle: commonIntl.cancel)
        let options = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 112))
        let capacity = NSPopUpButton(frame: NSRect(x: 104, y: 82, width: 296, height: 28))
        capacity.addItems(withTitles: BlankDiskImage.allCases.map { $0.label })
        capacity.selectItem(at: 1)
        capacity.target = self
        capacity.action = #selector(blankDiskCapacityChanged(_:))
        options.addSubview(capacity)
        let capacityLabel = NSTextField(labelWithString: builderIntl.diskCapacity)
        capacityLabel.frame = NSRect(x: 0, y: 82, width: 100, height: 24)
        ControlLayout.align(capacityLabel, with: capacity)
        options.addSubview(capacityLabel)
        let format = NSPopUpButton(frame: NSRect(x: 104, y: 44, width: 296, height: 28))
        format.addItems(withTitles: BlankDiskFormat.allCases.map { $0.label })
        format.menu?.autoenablesItems = false
        blankDiskFormatMenu = format
        defer { blankDiskFormatMenu = nil }
        blankDiskCapacityChanged(capacity)
        options.addSubview(format)
        let formatLabel = NSTextField(labelWithString: builderIntl.diskFormat)
        formatLabel.frame = NSRect(x: 0, y: 44, width: 100, height: 24)
        ControlLayout.align(formatLabel, with: format)
        options.addSubview(formatLabel)
        let add = NSButton(checkboxWithTitle: builderIntl.addToPlayerDisks, target: nil, action: nil)
        add.frame = NSRect(x: 0, y: 0, width: 340, height: 28)
        add.isEnabled = allowAdding
        add.state = allowAdding ? .on : .off
        add.toolTip =
            allowAdding ? nil : builderIntl.snapshotDiskSetHint
        options.addSubview(add)
        alert.accessoryView = options
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let image = BlankDiskImage.allCases[capacity.indexOfSelectedItem]
        let filesystem = BlankDiskFormat.allCases[format.indexOfSelectedItem]
        let fileExtension = image.fileExtension(for: filesystem)
        let panel = NSSavePanel()
        panel.title = builderIntl.saveBlankDiskImage
        panel.nameFieldStringValue = builderIntl.untitledDisk(fileExtension: fileExtension)
        panel.allowedContentTypes = [UTType(filenameExtension: fileExtension) ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return BlankDiskSelection(image: image, format: filesystem, url: url, addToPlayer: add.state == .on)
    }
}
