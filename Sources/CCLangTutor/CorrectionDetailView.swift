import SwiftUI

struct CorrectionDetailView: View {
    let correction: Correction
    @State private var showCopiedToast = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header with status
                    headerSection
                        .id("top")

                    // Main diff view
                    diffSection

                    // Detailed errors
                    if !correction.errors.isEmpty {
                        errorsSection
                    }

                    Spacer(minLength: 40)
                }
                .padding(24)
            }
            .onChange(of: correction.id) {
                proxy.scrollTo("top", anchor: .top)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(formattedDate)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: copyToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy corrected text")
            }
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusGradient)
                    .frame(width: 56, height: 56)

                Image(systemName: statusIcon)
                    .font(.system(size: 24, weight: .semibold))
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

    // MARK: - Diff Section

    private var diffSection: some View {
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
                    ErrorCardView(error: error, index: index + 1)
                }
            }
        }
    }

    // MARK: - Toast

    private var copiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Copied to clipboard")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private var statusGradient: LinearGradient {
        if correction.isPerfect {
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if correction.errors.count <= 2 {
            return LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [.red, .red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var statusIcon: String {
        correction.isPerfect ? "checkmark" : "pencil"
    }

    private var statusTitle: String {
        if correction.isPerfect {
            return "Perfect!"
        } else {
            return "\(correction.errors.count) Correction\(correction.errors.count == 1 ? "" : "s")"
        }
    }

    private var statusSubtitle: String {
        if correction.isPerfect {
            return "Your English is flawless"
        } else if correction.errors.count == 1 {
            return "Just a small fix needed"
        } else if correction.errors.count <= 3 {
            return "A few things to improve"
        } else {
            return "Several areas to work on"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: correction.timestamp)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(correction.corrected, forType: .string)

        withAnimation(.spring(response: 0.3)) {
            showCopiedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                showCopiedToast = false
            }
        }
    }
}

struct ErrorCardView: View {
    let error: CorrectionError
    let index: Int

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
        isPerfect: false
    ))
}
