import SwiftUI

private enum ChatStyle {
    static let assistantBubbleOpacity = 0.08
}

struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(markdownContent)
                    .font(.system(size: 14))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }

    private var markdownContent: AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            return try AttributedString(markdown: message.content, options: options)
        } catch {
            return AttributedString(message.content)
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(Color.accentColor)
        } else {
            return AnyShapeStyle(Color.secondary.opacity(ChatStyle.assistantBubbleOpacity))
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}

#Preview("User Message") {
    ChatMessageView(message: ChatMessage(
        role: .user,
        content: "Why do I need to use 'an' before 'English'?"
    ))
    .padding()
}

#Preview("Assistant Message") {
    ChatMessageView(message: ChatMessage(
        role: .assistant,
        content: "Great question! We use 'an' before words that start with a vowel sound. Even though 'English' starts with the letter 'E' (a consonant), it's pronounced with a vowel sound at the beginning."
    ))
    .padding()
}
