import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sh.saqoo.cclangtutor", category: "ViewModel")

@MainActor
final class CorrectionViewModel: ObservableObject {
    @Published var corrections: [Correction] = []
    @Published var pendingPrompts: [PendingPrompt] = []
    @Published var isProcessing = false
    @Published var selectedCorrectionId: UUID?
    @Published var isSendingChat = false

    private let storage = StorageManager.shared
    private let processor = CorrectionProcessor()
    private let chatProcessor = ChatProcessor()
    nonisolated(unsafe) private var notificationObserver: Any?

    init() {
        logger.info("ViewModel init")
        loadData()
        setupNotificationObserver()
        processPendingPrompts()
    }

    nonisolated deinit {
        if let observer = notificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private func setupNotificationObserver() {
        logger.info("Setting up notification observer for: \(CCLangTutorNotification.newPrompt.rawValue)")
        notificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: CCLangTutorNotification.newPrompt,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            logger.info("Received newPrompt notification")
            DispatchQueue.main.async {
                self?.loadData()
                self?.processPendingPrompts()
            }
        }
    }

    func loadData() {
        corrections = storage.loadCorrections()
        pendingPrompts = storage.loadPendingPrompts()
        logger.info("Loaded data: \(self.corrections.count) corrections, \(self.pendingPrompts.count) pending")

        if selectedCorrectionId == nil, let first = corrections.first {
            selectedCorrectionId = first.id
        }
    }

    func processPendingPrompts() {
        logger.info("processPendingPrompts called. isProcessing=\(self.isProcessing), pendingCount=\(self.pendingPrompts.count)")
        guard !isProcessing, !pendingPrompts.isEmpty else {
            logger.info("Skipping process: isProcessing=\(self.isProcessing), isEmpty=\(self.pendingPrompts.isEmpty)")
            return
        }

        isProcessing = true
        let promptsToProcess = pendingPrompts
        logger.info("Starting to process \(promptsToProcess.count) prompts")

        Task { @MainActor in
            defer {
                self.isProcessing = false
                logger.info("Processing complete. Total corrections: \(self.corrections.count)")

                // Check for new prompts that arrived during processing
                self.loadData()
                if !self.pendingPrompts.isEmpty {
                    logger.info("Found \(self.pendingPrompts.count) new pending prompts, processing...")
                    self.processPendingPrompts()
                }
            }

            for prompt in promptsToProcess {
                logger.info("Processing prompt: \(prompt.prompt.prefix(50))...")
                do {
                    let correction = try await processor.process(prompt)
                    logger.info("Got correction. errors=\(correction.errors.count), isPerfect=\(correction.isPerfect)")
                    try storage.appendCorrection(correction)
                    try storage.removePendingPrompt(id: prompt.id)

                    self.corrections.insert(correction, at: 0)
                    self.pendingPrompts.removeAll { $0.id == prompt.id }
                    self.selectedCorrectionId = correction.id
                    logger.info("Correction saved and UI updated")
                } catch {
                    logger.error("Failed to process prompt: \(error.localizedDescription)")
                    // Remove failed prompt to prevent infinite retry
                    try? storage.removePendingPrompt(id: prompt.id)
                    self.pendingPrompts.removeAll { $0.id == prompt.id }
                }
            }
        }
    }

    func deleteCorrection(_ correction: Correction) {
        corrections.removeAll { $0.id == correction.id }
        try? storage.saveCorrections(corrections)
        logger.info("Deleted correction: \(correction.id)")
    }

    func clearAllCorrections() {
        corrections.removeAll()
        try? storage.saveCorrections(corrections)
        logger.info("Cleared all corrections")
    }

    // MARK: - Chat

    func sendChatMessage(_ message: String, for correction: Correction) {
        guard !isSendingChat else { return }

        isSendingChat = true

        // Add user message immediately
        let userMessage = ChatMessage(role: .user, content: message)
        updateCorrectionWithMessage(userMessage, correctionId: correction.id)

        Task { @MainActor in
            defer { self.isSendingChat = false }

            do {
                // Get current correction state
                guard let currentCorrection = corrections.first(where: { $0.id == correction.id }) else {
                    logger.error("Correction not found: \(correction.id)")
                    return
                }

                let response = try await chatProcessor.sendMessage(
                    message,
                    correction: currentCorrection,
                    previousMessages: Array(currentCorrection.chatMessages.dropLast()) // Exclude the just-added user message
                )

                let assistantMessage = ChatMessage(role: .assistant, content: response)
                updateCorrectionWithMessage(assistantMessage, correctionId: correction.id)
                logger.info("Chat response saved")
            } catch {
                logger.error("Chat error: \(error.localizedDescription)")
                let errorMessage = ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)")
                updateCorrectionWithMessage(errorMessage, correctionId: correction.id)
            }
        }
    }

    private func updateCorrectionWithMessage(_ message: ChatMessage, correctionId: UUID) {
        guard let index = corrections.firstIndex(where: { $0.id == correctionId }) else {
            return
        }

        corrections[index].chatMessages.append(message)
        try? storage.updateCorrection(corrections[index])
    }
}
