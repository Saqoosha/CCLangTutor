import Foundation

final class StorageManager {
    static let shared = StorageManager()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    var appSupportURL: URL {
        let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CCLangTutor", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    var pendingURL: URL {
        appSupportURL.appendingPathComponent("pending.json")
    }

    var correctionsURL: URL {
        appSupportURL.appendingPathComponent("corrections.json")
    }

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Pending Prompts

    func loadPendingPrompts() -> [PendingPrompt] {
        guard let data = try? Data(contentsOf: pendingURL),
              let store = try? decoder.decode(PendingPromptStore.self, from: data) else {
            return []
        }
        return store.pending
    }

    func savePendingPrompts(_ prompts: [PendingPrompt]) throws {
        let store = PendingPromptStore(pending: prompts)
        let data = try encoder.encode(store)
        try data.write(to: pendingURL, options: .atomic)
    }

    func appendPendingPrompt(_ prompt: PendingPrompt) throws {
        // Use file locking to prevent race conditions when multiple CLI instances run simultaneously
        let lockURL = appSupportURL.appendingPathComponent(".pending.lock")
        fileManager.createFile(atPath: lockURL.path, contents: nil)

        let lockFd = open(lockURL.path, O_RDWR)
        guard lockFd >= 0 else {
            throw NSError(domain: "StorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open lock file"])
        }
        defer { close(lockFd) }

        // Acquire exclusive lock (blocking)
        guard flock(lockFd, LOCK_EX) == 0 else {
            throw NSError(domain: "StorageManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to acquire lock"])
        }
        defer { flock(lockFd, LOCK_UN) }

        var prompts = loadPendingPrompts()
        prompts.append(prompt)
        try savePendingPrompts(prompts)
    }

    func removePendingPrompt(id: UUID) throws {
        var prompts = loadPendingPrompts()
        prompts.removeAll { $0.id == id }
        try savePendingPrompts(prompts)
    }

    // MARK: - Corrections

    func loadCorrections() -> [Correction] {
        guard let data = try? Data(contentsOf: correctionsURL),
              let store = try? decoder.decode(CorrectionStore.self, from: data) else {
            return []
        }
        return store.corrections
    }

    func saveCorrections(_ corrections: [Correction]) throws {
        let store = CorrectionStore(corrections: corrections)
        let data = try encoder.encode(store)
        try data.write(to: correctionsURL, options: .atomic)
    }

    func appendCorrection(_ correction: Correction) throws {
        var corrections = loadCorrections()
        corrections.insert(correction, at: 0) // newest first
        try saveCorrections(corrections)
    }

    func updateCorrection(_ correction: Correction) throws {
        var corrections = loadCorrections()
        if let index = corrections.firstIndex(where: { $0.id == correction.id }) {
            corrections[index] = correction
            try saveCorrections(corrections)
        }
    }
}
