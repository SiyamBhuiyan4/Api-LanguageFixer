import Foundation

public extension Notification.Name {
    static let banglaWriteConfigDidChange = Notification.Name("BanglaWriteConfigDidChangeNotification")
}

public final class ConfigManager {
    public static let shared = ConfigManager()

    private let userDefaultsKey = "com.banglawrite.config"
    private let fileManager = FileManager.default

    private var configDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".banglawrite", isDirectory: true)
    }

    private var configFileURL: URL {
        configDirectoryURL.appendingPathComponent("config.json", isDirectory: false)
    }

    private let lockQueue = DispatchQueue(label: "com.banglawrite.config.lock", attributes: .concurrent)
    private var cachedConfig: BanglaWriteConfig

    private init() {
        self.cachedConfig = .default
        self.cachedConfig = loadFromDiskOrDefaults()
    }

    public var current: BanglaWriteConfig {
        lockQueue.sync { cachedConfig }
    }

    public func update(_ modify: (inout BanglaWriteConfig) -> Void) {
        lockQueue.sync(flags: .barrier) {
            modify(&cachedConfig)
            saveToDiskAndDefaults(cachedConfig)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .banglaWriteConfigDidChange, object: self.current)
        }
    }

    // MARK: - Private Persistence Methods

    private func loadFromDiskOrDefaults() -> BanglaWriteConfig {
        let filePath = configFileURL.path

        // 1. Try reading ~/.banglawrite/config.json
        if fileManager.fileExists(atPath: filePath) {
            // Verify and auto-repair 0600 permissions
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
               let perms = attrs[.posixPermissions] as? NSNumber {
                if (perms.uint16Value & 0o777) != 0o600 {
                    _ = chmod(filePath, S_IRUSR | S_IWUSR)
                }
            }

            if let data = try? Data(contentsOf: configFileURL),
               let decoded = try? JSONDecoder().decode(BanglaWriteConfig.self, from: data) {
                return decoded
            }
        }

        // 2. Try UserDefaults fallback
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(BanglaWriteConfig.self, from: data) {
            saveToDisk(decoded)
            return decoded
        }

        // 3. Default
        let defaultConfig = BanglaWriteConfig.default
        saveToDiskAndDefaults(defaultConfig)
        return defaultConfig
    }

    private func saveToDiskAndDefaults(_ config: BanglaWriteConfig) {
        // 1. UserDefaults
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }

        // 2. ~/.banglawrite/config.json with 0600 permissions
        saveToDisk(config)
    }

    private func saveToDisk(_ config: BanglaWriteConfig) {
        let dirPath = configDirectoryURL.path
        if !fileManager.fileExists(atPath: dirPath) {
            try? fileManager.createDirectory(at: configDirectoryURL, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700 // Directory: rwx------
            ])
            _ = chmod(dirPath, S_IRWXU)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }

        // Atomic write via temp file
        let tempURL = configDirectoryURL.appendingPathComponent("config.json.tmp.\(UUID().uuidString)")
        let tempPath = tempURL.path
        let finalPath = configFileURL.path

        if fileManager.createFile(atPath: tempPath, contents: data, attributes: [
            .posixPermissions: 0o600
        ]) {
            _ = chmod(tempPath, S_IRUSR | S_IWUSR)
            if rename(tempPath, finalPath) != 0 {
                try? fileManager.removeItem(at: tempURL)
            } else {
                _ = chmod(finalPath, S_IRUSR | S_IWUSR)
            }
        }
    }
}
