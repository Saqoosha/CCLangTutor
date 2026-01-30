import SwiftUI

struct CorrectionDetailView: View {
    let correction: Correction
    @EnvironmentObject var viewModel: CorrectionViewModel
    @State private var chatInputText = ""
    @State private var lastChatMessageCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header with status
                        headerSection
                            .id("top")

                        // Advice section (when score < 100)
                        if let advice = correction.advice, correction.score < 100 {
                            adviceSection(advice)
                        }

                        // Main diff view
                        diffSection

                        // Detailed errors
                        if !correction.errors.isEmpty {
                            errorsSection
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // Chat section
                        ChatView(correction: correction)
                    }
                    .padding(24)
                }
                .onChange(of: correction.id) {
                    proxy.scrollTo("top", anchor: .top)
                    chatInputText = ""
                    lastChatMessageCount = correction.chatMessages.count
                }
                .onChange(of: correction.chatMessages.count) { oldCount, newCount in
                    // Only scroll if a new message was added (not on selection change)
                    if newCount > lastChatMessageCount {
                        // Find the last user message and scroll to it at top
                        if let lastUserMessage = correction.chatMessages.last(where: { $0.role == .user }) {
                            withAnimation {
                                proxy.scrollTo(lastUserMessage.id, anchor: .top)
                            }
                        }
                    }
                    lastChatMessageCount = newCount
                }
                .onAppear {
                    lastChatMessageCount = correction.chatMessages.count
                }
            }

            // Fixed input bar at bottom
            ChatInputView(
                inputText: $chatInputText,
                isSending: viewModel.isSendingChat
            ) {
                sendMessage()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(formattedDate)
        .overlay(alignment: .bottom) {
            if let message = viewModel.ignoredRuleAddedMessage {
                Text(message)
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                viewModel.ignoredRuleAddedMessage = nil
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: viewModel.ignoredRuleAddedMessage)
    }

    private func sendMessage() {
        let text = chatInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatInputText = ""
        viewModel.sendChatMessage(text, for: correction)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusGradient)
                    .frame(width: 56, height: 56)

                Text("\(correction.score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.title2.weight(.semibold))

                Text(statusSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Advice Section

    private func adviceSection(_ advice: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(.purple)

            Text(advice)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.purple.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Diff Section

    @ViewBuilder
    private var diffSection: some View {
        if correction.isPerfect {
            // Perfect: show original text only (no comparison needed)
            Text(correction.original)
                .font(.title3)
                .textSelection(.enabled)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.green.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.green.opacity(0.2), lineWidth: 1)
                        )
                )
        } else {
            // Has corrections: show before/after comparison
            VStack(alignment: .leading, spacing: 16) {
                // Original
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red.opacity(0.8))
                        Text("Original")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(correction.original)
                        .font(.title3)
                        .textSelection(.enabled)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.red.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.red.opacity(0.2), lineWidth: 1)
                                )
                        )
                }

                // Arrow
                HStack {
                    Spacer()
                    Image(systemName: "arrow.down")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Spacer()
                }

                // Corrected
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green.opacity(0.8))
                        Text("Corrected")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(correction.corrected)
                        .font(.title3)
                        .textSelection(.enabled)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.green.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.green.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }

    // MARK: - Errors Section

    private var errorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
                Text("What to improve")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                ForEach(Array(correction.errors.enumerated()), id: \.element.id) { index, error in
                    ErrorCardView(
                        error: error,
                        index: index + 1,
                        isAddingIgnoredRule: viewModel.isAddingIgnoredRule,
                        onIgnoreRule: { viewModel.ignoreRule(error) }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusGradient: LinearGradient {
        switch correction.score {
        case 90...100:
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 70..<90:
            return LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.red, .red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var statusTitle: String {
        switch correction.score {
        case 100:
            return "Perfect!"
        case 90..<100:
            return "Excellent"
        case 80..<90:
            return "Great"
        case 70..<80:
            return "Good"
        case 60..<70:
            return "Fair"
        default:
            return "Needs Work"
        }
    }

    private var statusSubtitle: String {
        if correction.isPerfect {
            return "Your English is flawless"
        } else {
            let count = correction.errors.count
            return "\(count) correction\(count == 1 ? "" : "s") suggested"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: correction.timestamp)
    }
}

struct ErrorCardView: View {
    let error: CorrectionError
    let index: Int
    var isAddingIgnoredRule: Bool = false
    var onIgnoreRule: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Index badge
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.orange.gradient))

            VStack(alignment: .leading, spacing: 10) {
                // Before → After
                HStack(spacing: 10) {
                    Text(error.original)
                        .strikethrough()
                        .foregroundStyle(.red)

                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)

                    Text(error.corrected)
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                }
                .font(.title3.monospaced())

                // Explanation
                Text(error.explanation)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            // Ignore rule button
            if let onIgnoreRule = onIgnoreRule {
                Button {
                    onIgnoreRule()
                } label: {
                    if isAddingIgnoredRule {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Ignore")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isAddingIgnoredRule)
                .focusable(false)
                .help("Don't show this type of correction again")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

#Preview {
    CorrectionDetailView(correction: Correction(
        sessionId: "test",
        original: "i want english teacher",
        corrected: "I want an English teacher.",
        errors: [
            CorrectionError(
                original: "i",
                corrected: "I",
                explanation: "Always capitalize the pronoun 'I'"
            ),
            CorrectionError(
                original: "english",
                corrected: "English",
                explanation: "Language names should be capitalized"
            )
        ],
        isPerfect: false,
        score: 75
    ))
}
