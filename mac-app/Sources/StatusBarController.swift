import Cocoa

public protocol StatusBarControllerDelegate: AnyObject {
    func statusBarController(_ controller: StatusBarController, didRequestRewriteTo target: TargetLanguage)
    func statusBarController(_ controller: StatusBarController, didSelectTone tone: ToneMode)
    func statusBarControllerDidRequestSettings(_ controller: StatusBarController)
    func statusBarControllerDidRequestPermissions(_ controller: StatusBarController)
}

public final class StatusBarController: NSObject, NSMenuDelegate {
    public static let shared = StatusBarController()

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    public weak var delegate: StatusBarControllerDelegate?

    private var statusMenuItem: NSMenuItem!
    private var banglaMenuItem: NSMenuItem!
    private var englishMenuItem: NSMenuItem!
    private var toneMenuItems: [ToneMode: NSMenuItem] = [:]

    private var resetTimer: Timer?

    private override init() {
        super.init()
        setupStatusItem()
        buildMenu()
        updateToneCheckmarks()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.generateTemplateIcon()
            button.imagePosition = .imageLeading
            button.title = ""
            button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            button.toolTip = "BanglaWrite AI — Bangla ⌘⇧B · English ⌘⇧E"
        }
        statusItem.menu = menu
        menu.delegate = self
    }

    private func buildMenu() {
        menu.removeAllItems()
        menu.autoenablesItems = false

        // 1. App Title
        let headerItem = NSMenuItem()
        let attrTitle = NSAttributedString(
            string: "BanglaWrite AI",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        headerItem.attributedTitle = attrTitle
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        // 2. Status Indicator
        statusMenuItem = NSMenuItem(title: "● Ready", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        let readyAttr = NSAttributedString(
            string: "● Ready",
            attributes: [
                .foregroundColor: NSColor.systemGreen,
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
            ]
        )
        statusMenuItem.attributedTitle = readyAttr
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Rewrite Actions
        banglaMenuItem = NSMenuItem(
            title: "Convert Selection to Bangla",
            action: #selector(handleRewriteBangla),
            keyEquivalent: "b"
        )
        banglaMenuItem.keyEquivalentModifierMask = [.command, .shift]
        banglaMenuItem.target = self
        menu.addItem(banglaMenuItem)

        englishMenuItem = NSMenuItem(
            title: "Convert Selection to English",
            action: #selector(handleRewriteEnglish),
            keyEquivalent: "e"
        )
        englishMenuItem.keyEquivalentModifierMask = [.command, .shift]
        englishMenuItem.target = self
        menu.addItem(englishMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Tone Mode Submenu
        let toneSubmenu = NSMenu(title: "Writing Style")
        let toneParentItem = NSMenuItem(title: "Writing Style", action: nil, keyEquivalent: "")
        toneParentItem.submenu = toneSubmenu

        for mode in ToneMode.allCases {
            let item = NSMenuItem(
                title: mode.displayName,
                action: #selector(handleToneSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode
            toneSubmenu.addItem(item)
            toneMenuItems[mode] = item
        }
        menu.addItem(toneParentItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(handleSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 6. Permissions Check
        let permsItem = NSMenuItem(
            title: "Accessibility Permission...",
            action: #selector(handlePermissions),
            keyEquivalent: ""
        )
        permsItem.target = self
        menu.addItem(permsItem)

        menu.addItem(NSMenuItem.separator())

        // 7. Quit
        let quitItem = NSMenuItem(
            title: "Quit BanglaWrite AI",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - State Updates

    public func setProcessing() {
        resetTimer?.invalidate()
        resetTimer = nil
        setActionsEnabled(false)

        if let button = statusItem.button {
            button.title = " …"
        }
        statusMenuItem.attributedTitle = NSAttributedString(
            string: "⏳ Converting...",
            attributes: [
                .foregroundColor: NSColor.systemOrange,
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
            ]
        )
    }

    public func setSuccess() {
        resetTimer?.invalidate()
        setActionsEnabled(true)

        if let button = statusItem.button {
            button.title = " ✓"
        }

        resetTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setReady()
            }
        }
    }

    public func setError(message: String) {
        resetTimer?.invalidate()
        setActionsEnabled(true)

        if let button = statusItem.button {
            button.title = " !"
        }
        statusMenuItem.attributedTitle = NSAttributedString(
            string: "❌ \(message)",
            attributes: [
                .foregroundColor: NSColor.systemRed,
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
            ]
        )

        resetTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setReady()
            }
        }
    }

    public func setReady() {
        resetTimer?.invalidate()
        resetTimer = nil
        setActionsEnabled(true)

        if let button = statusItem.button {
            button.title = ""
        }
        statusMenuItem.attributedTitle = NSAttributedString(
            string: "● Ready",
            attributes: [
                .foregroundColor: NSColor.systemGreen,
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
            ]
        )
    }

    private func setActionsEnabled(_ enabled: Bool) {
        banglaMenuItem.isEnabled = enabled
        englishMenuItem.isEnabled = enabled
    }

    public func updateToneCheckmarks() {
        let activeTone = ConfigManager.shared.current.mode
        for (mode, item) in toneMenuItems {
            item.state = (mode == activeTone) ? .on : .off
        }
    }

    // MARK: - Actions

    @objc private func handleRewriteBangla() {
        delegate?.statusBarController(self, didRequestRewriteTo: .bangla)
    }

    @objc private func handleRewriteEnglish() {
        delegate?.statusBarController(self, didRequestRewriteTo: .english)
    }

    @objc private func handleToneSelected(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? ToneMode else { return }
        ConfigManager.shared.update { $0.mode = mode }
        updateToneCheckmarks()
        delegate?.statusBarController(self, didSelectTone: mode)
    }

    @objc private func handleSettings() {
        delegate?.statusBarControllerDidRequestSettings(self)
    }

    @objc private func handlePermissions() {
        delegate?.statusBarControllerDidRequestPermissions(self)
    }

    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Icon Generator

    public static func generateTemplateIcon(size: CGSize = CGSize(width: 18, height: 18)) -> NSImage {
        let img = NSImage(size: size, flipped: false) { rect in
            let text = "অ"
            let font = NSFont.boldSystemFont(ofSize: 13)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let sSize = str.size()
            let pt = CGPoint(
                x: (rect.width - sSize.width) / 2.0,
                y: (rect.height - sSize.height) / 2.0 - 0.5
            )
            str.draw(at: pt)
            return true
        }
        img.isTemplate = true
        return img
    }
}
