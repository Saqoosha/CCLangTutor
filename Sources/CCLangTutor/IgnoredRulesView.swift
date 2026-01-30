import SwiftUI

struct IgnoredRulesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rules: [IgnoredRule] = []
    private let storage = StorageManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Ignored Rules")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            // Content
            Group {
                if rules.isEmpty {
                    emptyState
                } else {
                    rulesList
                }
            }
        }
        .frame(width: 450, height: 400)
        .onAppear {
            loadRules()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Ignored Rules")
                .font(.headline)

            Text("When you click the ignore button on a correction card, rules will appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rulesList: some View {
        List {
            ForEach(rules) { rule in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(rule.rule)
                            .font(.headline)

                        Spacer()

                        Button {
                            deleteRule(rule)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete this rule")
                    }

                    HStack(spacing: 4) {
                        Text("ex.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        Text(rule.example)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Text(rule.originalExplanation)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.inset)
    }

    private func loadRules() {
        rules = storage.loadIgnoredRules()
    }

    private func deleteRule(_ rule: IgnoredRule) {
        try? storage.removeIgnoredRule(id: rule.id)
        loadRules()
    }
}

#Preview {
    IgnoredRulesView()
}
