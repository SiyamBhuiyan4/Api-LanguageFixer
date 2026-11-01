import Cocoa

public final class FeedbackManager {
    public static let shared = FeedbackManager()

    private init() {}

    public func playSuccessSound() {
        if ConfigManager.shared.current.soundEnabled {
            NSSound(named: NSSound.Name("Tink"))?.play()
        }
    }

    public func playErrorSound() {
        if ConfigManager.shared.current.soundEnabled {
            if let sound = NSSound(named: NSSound.Name("Basso")) {
                sound.play()
            } else {
                NSSound.beep()
            }
        }
    }
}
