import SwiftUI

struct CorrectionListView: View {
    @EnvironmentObject var viewModel: CorrectionViewModel

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if !viewModel.pendingPrompts.isEmpty {
                    Section {
                        ForEach(viewModel.pendingPrompts) { prompt in
                            PendingRowView(prompt: prompt)
                        }
                    } header: {
                        Label("Processing", systemImage: "ellipsis.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .id("listTop")
                    }
                }

                Section {
                    ForEach(viewModel.corrections) { correction in
                        let isSelected = viewModel.selectedCorrectionId == correction.id
                        CorrectionRowView(
                            correction: correction,
                            isSelected: isSelected
                        )
                        .id(correction.id)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                                .padding(.horizontal, 4)
                        )
                        .onTapGesture {
                            viewModel.selectedCorrectionId = correction.id
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteCorrection(viewModel.corrections[index])
                        }
                    }
                } header: {
                    Label("History", systemImage: "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .id(viewModel.pendingPrompts.isEmpty ? "listTop" : "historyHeader")
                }
            }
            .onChange(of: viewModel.corrections.first?.id) {
                withAnimation {
                    proxy.scrollTo("listTop", anchor: .top)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("CCLangTutor")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.loadData()
                    viewModel.processPendingPrompts()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
    }
}

struct PendingRowView: View {
    let prompt: PendingPrompt

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 20)

            Text(prompt.prompt)
                .lineLimit(2)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.7))
        }
        .padding(.vertical, 6)
    }
}

struct CorrectionRowView: View {
    let correction: Correction
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            statusBadge

            VStack(alignment: .leading, spacing: 6) {
                Text(correction.original)
                    .lineLimit(2)
                    .font(.body)

                HStack(spacing: 8) {
                    if correction.isPerfect {
                        Label("Perfect", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("\(correction.errors.count) issue\(correction.errors.count == 1 ? "" : "s")", systemImage: "pencil.circle.fill")
                            .font(.caption)
                            .foregroundStyle(statusColor)
                    }

                    Text("·")
                        .foregroundStyle(Color.secondary.opacity(0.5))

                    Text(timeAgo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var statusBadge: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 32, height: 32)

            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusColor)
        }
    }

    private var statusIcon: String {
        if correction.isPerfect {
            return "checkmark"
        } else if correction.errors.count <= 2 {
            return "exclamationmark"
        } else {
            return "xmark"
        }
    }

    private var statusColor: Color {
        if correction.isPerfect {
            return .green
        } else if correction.errors.count <= 2 {
            return .orange
        } else {
            return .red
        }
    }

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: correction.timestamp, relativeTo: Date())
    }
}

#Preview {
    CorrectionListView()
        .environmentObject(CorrectionViewModel())
}
