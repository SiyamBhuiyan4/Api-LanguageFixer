import Cocoa
import ApplicationServices

public final class PermissionsManager {
    public static let shared = PermissionsManager()

    private static let accessibilityPrefURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    private init() {}

    /// Checks if Accessibility permission is granted.
    public func isAccessibilityGranted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Preferences directly to Privacy -> Accessibility.
    @discardableResult
    public func openAccessibilityPreferences() -> Bool {
        guard let url = URL(string: Self.accessibilityPrefURL) else { return false }
        return NSWorkspace.shared.open(url)
    }
}
