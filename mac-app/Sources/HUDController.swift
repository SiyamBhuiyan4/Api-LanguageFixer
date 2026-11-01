import Cocoa
import SwiftUI

/// The small floating card shown near the top of the screen. It never takes
/// keyboard focus, so the paste still lands in the user's app.
public final class HUDController {
    public static let shared = HUDController()

    final class Model: ObservableObject {
        enum State {
            case working(String)
            case success(String)
            case result(text: String, note: String)
            case error(message: String, showsSettings: Bool)
        }
        @Published var state: State = .working("")
        @Published var copied = false
    }

    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }

    private let width: CGFloat = 400
    private let model = Model()
    private var dismissTimer: Timer?

    private lazy var panel: Panel = {
        let panel = Panel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = ClickThroughHostingView(
            rootView: HUDView(
                model: model,
                width: width,
                onCopy: { [weak self] text in self?.copy(text) },
                onSettings: { [weak self] in
                    self?.hide()
                    SettingsWindowController.shared.show()
                },
                onDismiss: { [weak self] in self?.hide() }
            )
        )
        return panel
    }()

    private init() {}

    public func showWorking(target: TargetLanguage) {
        present(.working("Converting to \(target.displayName)…"), dismissAfter: nil)
    }

    public func showReplaced(target: TargetLanguage) {
        present(.success("Done. Press ⌘Z in your app to undo."), dismissAfter: 2.0)
    }

    public func showResult(_ text: String, note: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        present(.result(text: trimmed, note: note), dismissAfter: 15.0)
    }

    public func showError(_ message: String, showsSettingsButton: Bool = false) {
        present(.error(message: message, showsSettings: showsSettingsButton), dismissAfter: showsSettingsButton ? 12.0 : 5.0)
    }

    public func hide() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        panel.orderOut(nil)
    }

    private func copy(_ text: String) {
        TextEngine.shared.copyToClipboard(text)
        model.copied = true
        scheduleDismiss(after: 1.2)
    }

    private func present(_ state: Model.State, dismissAfter delay: TimeInterval?) {
        model.copied = false
        model.state = state

        // Let SwiftUI apply the new state before measuring it.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let content = self.panel.contentView else { return }
            content.layoutSubtreeIfNeeded()
            let size = content.fittingSize
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 14)
                self.panel.setFrame(NSRect(origin: origin, size: size), display: true)
            }
            self.panel.orderFrontRegardless()
        }

        dismissTimer?.invalidate()
        dismissTimer = nil
        if let delay = delay {
            scheduleDismiss(after: delay)
        }
    }

    private func scheduleDismiss(after delay: TimeInterval) {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
}

// MARK: - View

struct HUDView: View {
    @ObservedObject var model: HUDController.Model
    let width: CGFloat
    let onCopy: (String) -> Void
    let onSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(width: width, alignment: .leading)
            .background(VisualEffectBackground(material: .hudWindow))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .working(let message):
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(message).font(.system(size: 13, weight: .medium))
            }
        case .success(let message):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(BrandColor.green)
                Text(message).font(.system(size: 13, weight: .medium))
            }
        case .result(let text, let note):
            VStack(alignment: .leading, spacing: 8) {
                Text(note)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                ScrollView {
                    Text(text)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .fixedSize(horizontal: false, vertical: text.count < 200)
                HStack {
                    Spacer()
                    Button("Close", action: onDismiss)
                    Button(model.copied ? "Copied" : "Copy") { onCopy(text) }
                        .buttonStyle(.borderedProminent)
                        .tint(BrandColor.green)
                }
                .controlSize(.small)
            }
        case .error(let message, let showsSettings):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(BrandColor.red)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showsSettings {
                    Button("Settings", action: onSettings).controlSize(.small)
                }
            }
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// Colors from the Bangladesh flag. Both read clearly in light and dark mode.
enum BrandColor {
    static let green = Color(red: 0.0, green: 0.56, blue: 0.40)
    static let deepGreen = Color(red: 0.0, green: 0.38, blue: 0.27)
    static let red = Color(red: 0.87, green: 0.20, blue: 0.24)
}
