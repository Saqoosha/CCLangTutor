import SwiftUI

struct ChatView: View {
    let correction: Correction
    @EnvironmentObject var viewModel: CorrectionViewModel

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chat header
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(.blue)
                Text("Ask about this correction")
                    .font(.headline)
            }

            // Messages
            if !correction.chatMessages.isEmpty {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(correction.chatMessages) { message in
                        ChatMessageView(message: message)
                    }
                }
            } else {
                Text("Have questions about this correction? Ask away!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }
}

struct ChatInputView: View {
    @Binding var inputText: String
    let isSending: Bool
    let onSend: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask a question...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onSubmit {
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending {
                        onSend()
                    }
                }

            Button(action: onSend) {
                if isSending {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    VStack {
        ChatView(correction: Correction(
            sessionId: "test",
            original: "i want english teacher",
            corrected: "I want an English teacher.",
            errors: [
                CorrectionError(
                    original: "i",
                    corrected: "I",
                    explanation: "Always capitalize the pronoun 'I'"
                )
            ],
            isPerfect: false,
            chatMessages: [
                ChatMessage(role: .user, content: "Why do I need to capitalize 'I'?"),
                ChatMessage(role: .assistant, content: "In English, the pronoun 'I' is always capitalized, regardless of its position in a sentence. This is a unique rule that applies only to 'I' - other pronouns like 'me', 'you', 'he', 'she' are not capitalized unless they start a sentence.")
            ]
        ))
        .environmentObject(CorrectionViewModel())

        ChatInputView(inputText: .constant(""), isSending: false) { }
    }
}
