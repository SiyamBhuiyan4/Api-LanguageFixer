import Cocoa
import SwiftUI

public final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = SettingsWindowController()

    let model = SettingsModel()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: SettingsView.width, height: SettingsView.height),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "BanglaWrite AI"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        model.load()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Model

final class SettingsModel: ObservableObject {
    enum Status: Equatable {
        case none
        case working(String)
        case success(String)
        case failure(String)
    }

    @Published var provider: LLMProvider = .gemini
    @Published var apiKey = ""
    @Published var model = ""
    @Published var endpoint = ""
    @Published var temperature = 0.3
    @Published var tone: ToneMode = .sameVoice
    @Published var soundEnabled = true
    @Published var showKey = false
    @Published var status: Status = .none
    @Published var availableModels: [String] = []
    @Published var accessibilityGranted = false

    /// Unsaved entries for each provider, so switching providers doesn't lose a typed key.
    private var drafts: [String: ProviderConfig] = [:]
    private var loadedProvider: LLMProvider = .gemini

    /// Current Gemini text models, shown until the key can fetch its own list.
    static let suggestedGeminiModels = ["gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-flash-latest"]

    var modelChoices: [String] {
        guard provider == .gemini else { return [] }
        return availableModels.isEmpty ? Self.suggestedGeminiModels : availableModels
    }

    var isBusy: Bool {
        if case .working = status { return true }
        return false
    }

    func load() {
        let config = ConfigManager.shared.current
        drafts = config.providerConfigs
        provider = config.provider
        loadedProvider = config.provider
        apiKey = config.apiKey
        model = config.model
        endpoint = config.endpoint
        temperature = config.temperature
        tone = config.mode
        soundEnabled = config.soundEnabled
        showKey = false
        status = .none
        availableModels = []
        refreshPermission()
    }

    func providerChanged(to newProvider: LLMProvider) {
        guard newProvider != loadedProvider else { return }
        drafts[loadedProvider.rawValue] = ProviderConfig(apiKey: apiKey, endpoint: endpoint, model: model)
        let target = drafts[newProvider.rawValue]
        apiKey = target?.apiKey ?? ""
        endpoint = target?.endpoint ?? newProvider.defaultEndpoint
        model = target?.model ?? newProvider.defaultModel
        loadedProvider = newProvider
        availableModels = []
        status = .none
    }

    func refreshPermission() {
        let granted = PermissionsManager.shared.isAccessibilityGranted(prompt: false)
        if granted != accessibilityGranted {
            accessibilityGranted = granted
        }
    }

    func requestPermission() {
        // Prompting adds the app to the Accessibility list; the pane is where it gets turned on.
        _ = PermissionsManager.shared.isAccessibilityGranted(prompt: true)
        PermissionsManager.shared.openAccessibilityPreferences()
    }

    private func draftConfig() -> BanglaWriteConfig {
        var config = ConfigManager.shared.current
        config.provider = provider
        config.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        config.model = trimmedModel.isEmpty ? provider.defaultModel : trimmedModel
        config.endpoint = trimmedEndpoint.isEmpty ? provider.defaultEndpoint : trimmedEndpoint
        config.temperature = (temperature * 100).rounded() / 100
        config.mode = tone
        config.soundEnabled = soundEnabled
        return config
    }

    func test() {
        let config = draftConfig()
        status = .working("Testing \(config.model)…")
        Task { @MainActor in
            do {
                let message = try await APIClient.shared.testConnection(config: config)
                self.status = .success(message)
                await self.fetchModels(config: config)
            } catch {
                self.status = .failure(error.localizedDescription)
                // A key can be valid while the chosen model isn't: still offer the models it can use.
                if case BanglaWriteError.modelNotFound = error {
                    await self.fetchModels(config: config)
                }
            }
        }
    }

    @MainActor
    private func fetchModels(config: BanglaWriteConfig) async {
        guard config.provider == .gemini else { return }
        if let models = try? await APIClient.shared.listGeminiModels(config: config), !models.isEmpty {
            availableModels = models
        }
    }

    func save() {
        let draft = draftConfig()
        drafts[draft.provider.rawValue] = ProviderConfig(apiKey: draft.apiKey, endpoint: draft.endpoint, model: draft.model)
        let savedDrafts = drafts
        ConfigManager.shared.update { config in
            config = draft
            config.providerConfigs = savedDrafts
            config.configVersion = BanglaWriteConfig.currentConfigVersion
        }
        apiKey = draft.apiKey
        model = draft.model
        endpoint = draft.endpoint
        status = .success("Saved. New settings are active now.")
    }
}

// MARK: - Views

struct SettingsView: View {
    static let width: CGFloat = 560
    static let height: CGFloat = 720

    @ObservedObject var model: SettingsModel
    @State private var showAdvanced = false

    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    shortcutsCard
                    aiCard
                    permissionCard
                    preferencesCard
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
            footer
        }
        .frame(width: Self.width, height: Self.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(permissionTimer) { _ in model.refreshPermission() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("অ")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 54, height: 54)
                .background(
                    LinearGradient(colors: [BrandColor.green, BrandColor.deepGreen], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("BanglaWrite AI").font(.system(size: 20, weight: .bold))
                Text("Runs in the menu bar until you quit it.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            readinessPill
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 16)
    }

    private var isReady: Bool {
        let hasKey = !model.provider.requiresAPIKey
            || !ConfigManager.shared.current.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return model.accessibilityGranted && hasKey
    }

    private var readinessPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isReady ? BrandColor.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(isReady ? "Ready" : "Setup needed").font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.07))
        .clipShape(Capsule())
    }

    private var shortcutsCard: some View {
        SettingsCard(title: "Select text, then press") {
            ShortcutRow(
                keys: ["⌘", "⇧", "B"],
                title: "Bangla",
                detail: "Fixes grammar and adds । and commas, in your own accent."
            )
            Divider()
            ShortcutRow(
                keys: ["⌘", "⇧", "E"],
                title: "English",
                detail: "Turns Banglish into English and fixes grammar and prepositions."
            )
        }
    }

    private var aiCard: some View {
        SettingsCard(title: "AI connection") {
            FieldRow(label: "Provider") {
                Picker("", selection: $model.provider) {
                    ForEach(LLMProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .onChange(of: model.provider) { model.providerChanged(to: $0) }
            }

            if model.provider != .offline {
                if model.provider.requiresAPIKey {
                    FieldRow(label: "API key") {
                        HStack(spacing: 6) {
                            Group {
                                if model.showKey {
                                    TextField("Paste your API key", text: $model.apiKey)
                                } else {
                                    SecureField("Paste your API key", text: $model.apiKey)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            Button {
                                model.showKey.toggle()
                            } label: {
                                Image(systemName: model.showKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .help(model.showKey ? "Hide key" : "Show key")
                        }
                    }
                    if model.provider == .gemini, let url = URL(string: "https://aistudio.google.com/apikey") {
                        FieldRow(label: "") {
                            Link("Get a Gemini API key from Google AI Studio", destination: url)
                                .font(.system(size: 11))
                        }
                    }
                }

                FieldRow(label: "Model") {
                    HStack(spacing: 6) {
                        TextField("Model name", text: $model.model)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        if !model.modelChoices.isEmpty {
                            Menu("Choose") {
                                ForEach(model.modelChoices, id: \.self) { name in
                                    Button(name) { model.model = name }
                                }
                            }
                            .fixedSize()
                        }
                    }
                }

                DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                    VStack(spacing: 10) {
                        FieldRow(label: "Endpoint") {
                            TextField("Endpoint URL", text: $model.endpoint)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }
                        FieldRow(label: "Creativity") {
                            HStack {
                                Slider(value: $model.temperature, in: 0...1)
                                Text(String(format: "%.2f", model.temperature))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.system(size: 12))
            }
        }
    }

    private var permissionCard: some View {
        SettingsCard(title: "Permission") {
            HStack(spacing: 10) {
                Image(systemName: model.accessibilityGranted ? "checkmark.seal.fill" : "lock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(model.accessibilityGranted ? BrandColor.green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.accessibilityGranted ? "Accessibility is on" : "Accessibility is off")
                        .font(.system(size: 13, weight: .semibold))
                    Text(model.accessibilityGranted
                         ? "The app can read and replace your selected text."
                         : "Needed to read and replace your selected text.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !model.accessibilityGranted {
                    Button("Turn On…") { model.requestPermission() }
                }
            }
        }
    }

    private var preferencesCard: some View {
        SettingsCard(title: "Preferences") {
            FieldRow(label: "Writing style") {
                Picker("", selection: $model.tone) {
                    ForEach(ToneMode.allCases, id: \.self) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .labelsHidden()
            }
            FieldRow(label: "Sound") {
                Toggle("Play a sound when finished", isOn: $model.soundEnabled)
                    .font(.system(size: 12))
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                statusView
                Spacer()
                Button("Quit App") { NSApp.terminate(nil) }
                if model.provider != .offline {
                    Button("Test") { model.test() }
                        .disabled(model.isBusy)
                }
                Button("Save") { model.save() }
                    .keyboardShortcut(.defaultAction)
                    .tint(BrandColor.green)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.status {
        case .none:
            EmptyView()
        case .working(let message):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(message).font(.system(size: 11)).foregroundColor(.secondary)
            }
        case .success(let message):
            statusText(message, symbol: "checkmark.circle.fill", color: BrandColor.green)
        case .failure(let message):
            statusText(message, symbol: "xmark.octagon.fill", color: BrandColor.red)
        }
    }

    private func statusText(_ message: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: symbol).foregroundColor(color)
            Text(message)
                .font(.system(size: 11))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
            )
        }
    }
}

private struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 84, alignment: .trailing)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ShortcutRow: View {
    let keys: [String]
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
