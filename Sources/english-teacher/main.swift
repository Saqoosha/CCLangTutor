import Foundation

// Hook input structure
struct HookInput: Decodable {
    let sessionId: String?
    let prompt: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case prompt
    }
}

func main() {
    // Read JSON from stdin
    let inputData = FileHandle.standardInput.readDataToEndOfFile()

    guard !inputData.isEmpty else {
        // No input, exit silently
        exit(0)
    }

    // Parse input
    let decoder = JSONDecoder()
    guard let input = try? decoder.decode(HookInput.self, from: inputData),
          let prompt = input.prompt,
          !prompt.isEmpty else {
        // Invalid input, exit silently
        exit(0)
    }

    let sessionId = input.sessionId ?? "unknown"

    // Handle slash commands
    var textToCorrect = prompt
    if prompt.hasPrefix("/") {
        // Extract command and args
        let parts = prompt.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count <= 1 {
            // Slash command without args, skip entirely
            exit(0)
        }
        // Use only the args part for correction
        textToCorrect = String(parts[1])
    }

    // Create pending prompt
    let pendingPrompt = PendingPrompt(
        sessionId: sessionId,
        prompt: textToCorrect
    )

    // Save to pending.json
    do {
        try StorageManager.shared.appendPendingPrompt(pendingPrompt)
    } catch {
        // Failed to save, exit silently
        fputs("Failed to save pending prompt: \(error)\n", stderr)
        exit(1)
    }

    // Launch app in background (no activation)
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = ["-g", "-a", "CCLangTutor"]
    try? task.run()

    // Send distributed notification
    DistributedNotificationCenter.default().postNotificationName(
        CCLangTutorNotification.newPrompt,
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )

    exit(0)
}

main()
