import SwiftUI
import os

private let logger = Logger(subsystem: "sh.saqoo.cclangtutor", category: "ViewModel")

@MainActor
final class CorrectionViewModel: ObservableObject {
    @Published var corrections: [Correction] = []
    @Published var pendingPrompts: [PendingPrompt] = []
    @Published var isProcessing = false
    @Published var selectedCorrectionId: UUID?

    private let storage = StorageManager.shared
    private let processor = CorrectionProcessor()
    private var notificationObserver: Any?

    init() {
        logger.info("ViewModel init")
        loadData()
        setupNotificationObserver()
        processPendingPrompts()
    }

    deinit {
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
        logger.info("Starting to process \(self.pendingPrompts.count) prompts")

        Task {
            for prompt in pendingPrompts {
                logger.info("Processing prompt: \(prompt.prompt.prefix(50))...")
                do {
                    let correction = try await processor.process(prompt)
                    logger.info("Got correction. errors=\(correction.errors.count), isPerfect=\(correction.isPerfect)")
                    try storage.appendCorrection(correction)
                    try storage.removePendingPrompt(id: prompt.id)

                    await MainActor.run {
                        self.corrections.insert(correction, at: 0)
                        self.pendingPrompts.removeAll { $0.id == prompt.id }
                        self.selectedCorrectionId = correction.id
                    }
                    logger.info("Correction saved and UI updated")
                } catch {
                    logger.error("Failed to process prompt: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                self.isProcessing = false
                logger.info("Processing complete. Total corrections: \(self.corrections.count)")
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
}
