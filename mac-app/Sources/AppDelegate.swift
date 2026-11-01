import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate, StatusBarControllerDelegate {

    private lazy var statusBar = StatusBarController.shared
    private let hotkey = HotkeyManager.shared
    private let textEngine = TextEngine.shared
    private let apiClient = APIClient.shared
    private let feedback = FeedbackManager.shared
    private let permissions = PermissionsManager.shared

    private var isRewriting = false

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce menu-bar accessory policy (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        installMainMenu()
        statusBar.delegate = self

        // Observe config updates to refresh menu state
        NotificationCenter.default.addObserver(
            forName: .banglaWriteConfigDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.statusBar.updateToneCheckmarks()
        }

        setupHotkeys()

        // Settings shows the setup still needed: the API key and the Accessibility permission.
        let config = ConfigManager.shared.current
        let keyMissing = config.provider.requiresAPIKey
            && config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if keyMissing || !permissions.isAccessibilityGranted(prompt: false) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SettingsWindowController.shared.show()
            }
        }
    }

    /// Opening the app again while it runs shows Settings, since it has no Dock icon.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }

    /// Closing Settings must not stop the app; it runs until the user quits.
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotkey.unregister()
    }

    /// Never visible for a menu bar app, but AppKit routes key equivalents through it.
    /// Without an Edit menu, Cmd+V can't paste an API key into the Settings fields.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit BanglaWrite AI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupHotkeys() {
        let failed = hotkey.registerShortcuts(
            bangla: { [weak self] in self?.startRewrite(target: .bangla) },
            english: { [weak self] in self?.startRewrite(target: .english) }
        )
        if !failed.isEmpty {
            let names = failed.joined(separator: " and ")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                HUDController.shared.showError("\(names) couldn't be registered. Another app may be using it.")
            }
        }
    }

    private func startRewrite(target: TargetLanguage) {
        Task { @MainActor [weak self] in
            await self?.executeRewrite(target: target)
        }
    }

    // MARK: - Core Rewrite Pipeline

    @MainActor
    public func executeRewrite(target: TargetLanguage) async {
        guard !isRewriting else { return }
        isRewriting = true
        defer { isRewriting = false }

        guard permissions.isAccessibilityGranted(prompt: false) else {
            fail("Accessibility permission is needed. Turn it on in Settings.", opensSettings: true)
            return
        }

        statusBar.setProcessing()
        HUDController.shared.showWorking(target: target)

        // Capture while the user's app is still focused
        let sourceApp = textEngine.frontmostProcessID
        let editability = textEngine.focusedTargetEditability()

        guard let selectedText = await textEngine.captureSelectedText(),
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fail("Select some text first, then press the shortcut.", opensSettings: false)
            return
        }

        let config = ConfigManager.shared.current
        let result: String
        do {
            result = try await apiClient.rewrite(
                text: selectedText,
                mode: config.mode,
                target: target,
                config: config
            )
        } catch {
            let message = error.localizedDescription
            var opensSettings = false
            if let appError = error as? BanglaWriteError {
                switch appError {
                case .missingOrInvalidAPIKey, .invalidAPIKey, .modelNotFound, .englishNeedsAI, .rateLimited:
                    opensSettings = true
                default:
                    break
                }
            }
            fail(message, opensSettings: opensSettings)
            return
        }

        // The user may have moved to another app during the request. Never paste there.
        if textEngine.frontmostProcessID != sourceApp {
            finish()
            HUDController.shared.showResult(result, note: "You switched apps, so nothing was replaced.")
            return
        }

        switch editability {
        case .editable:
            await textEngine.replaceSelectedText(with: result)
            HUDController.shared.showReplaced(target: target)
        case .readOnly:
            HUDController.shared.showResult(result, note: "This text can't be edited here.")
        case .unknown:
            await textEngine.replaceSelectedText(with: result)
            HUDController.shared.showResult(result, note: "Replaced. If the text didn't change, copy it from here.")
        }
        finish()
    }

    @MainActor
    private func finish() {
        statusBar.setSuccess()
        feedback.playSuccessSound()
    }

    @MainActor
    private func fail(_ message: String, opensSettings: Bool) {
        statusBar.setError(message: message)
        feedback.playErrorSound()
        HUDController.shared.showError(message, showsSettingsButton: opensSettings)
    }

    // MARK: - StatusBarControllerDelegate

    public func statusBarController(_ controller: StatusBarController, didRequestRewriteTo target: TargetLanguage) {
        startRewrite(target: target)
    }

    public func statusBarController(_ controller: StatusBarController, didSelectTone tone: ToneMode) {
        // Handled via ConfigManager observer
    }

    public func statusBarControllerDidRequestSettings(_ controller: StatusBarController) {
        SettingsWindowController.shared.show()
    }

    public func statusBarControllerDidRequestPermissions(_ controller: StatusBarController) {
        SettingsWindowController.shared.show()
    }
}
