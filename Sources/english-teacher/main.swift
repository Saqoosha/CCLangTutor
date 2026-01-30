import Foundation

// Simple file logger for debugging
func log(_ message: String) {
    let logFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("CCLangTutor")
        .appendingPathComponent("hook.log")
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFile)
        }
    }
}

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
    log("english-teacher started")

    // Read JSON from stdin
    let inputData = FileHandle.standardInput.readDataToEndOfFile()

    guard !inputData.isEmpty else {
        log("No input data, exiting")
        exit(0)
    }

    log("Received \(inputData.count) bytes")

    // Parse input
    let decoder = JSONDecoder()
    guard let input = try? decoder.decode(HookInput.self, from: inputData),
          let prompt = input.prompt,
          !prompt.isEmpty else {
        // Invalid input, exit silently
        exit(0)
    }

    let sessionId = input.sessionId ?? "unknown"

    // Skip system-generated messages (not human prompts)
    let systemTags = [
        "<task-notification>",
        "<system-reminder>",
        "<local-command-caveat>",
        "<command-name>",
        "<function_results>",
    ]
    for tag in systemTags {
        if prompt.contains(tag) {
            log("Skipping system message containing \(tag)")
            exit(0)
        }
    }

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
        log("Saving prompt: \(textToCorrect.prefix(50))...")
        try StorageManager.shared.appendPendingPrompt(pendingPrompt)
        log("Saved to pending.json")
    } catch {
        log("Failed to save: \(error.localizedDescription)")
        fputs("Failed to save pending prompt: \(error)\n", stderr)
        exit(1)
    }

    // Launch app in background (no activation)
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = ["-g", "-a", "CCLangTutor"]
    try? task.run()

    // Send distributed notification
    log("Sending notification")
    DistributedNotificationCenter.default().postNotificationName(
        CCLangTutorNotification.newPrompt,
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )

    log("Done")
    exit(0)
}

main()
