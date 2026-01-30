import SwiftUI

struct CorrectionListView: View {
    @EnvironmentObject var viewModel: CorrectionViewModel
    @AppStorage("hidePerfectScore") private var hidePerfectScore = false

    private var filteredCorrections: [Correction] {
        if hidePerfectScore {
            return viewModel.corrections.filter { $0.score < 100 }
        }
        return viewModel.corrections
    }

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
                    ForEach(filteredCorrections) { correction in
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
                            viewModel.deleteCorrection(filteredCorrections[index])
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
                Button(action: { hidePerfectScore.toggle() }) {
                    Image(systemName: hidePerfectScore ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .help(hidePerfectScore ? "Show all" : "Hide perfect scores")
            }

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
        if correction.score == 100 {
            goldMedalBadge
        } else {
            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Text("\(correction.score)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
            }
        }
    }

    private var goldMedalBadge: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.92, blue: 0.55),
                            Color(red: 0.95, green: 0.75, blue: 0.3),
                            Color(red: 0.85, green: 0.65, blue: 0.25),
                            Color(red: 0.95, green: 0.8, blue: 0.4),
                            Color(red: 1.0, green: 0.92, blue: 0.55),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)

            // Inner circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.65),
                            Color(red: 1.0, green: 0.85, blue: 0.45),
                            Color(red: 0.95, green: 0.75, blue: 0.35),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 26, height: 26)

            // Thumbs up
            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.75, green: 0.55, blue: 0.15),
                            Color(red: 0.6, green: 0.45, blue: 0.1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.4), radius: 3, x: 0, y: 1)
    }

    private var scoreColor: Color {
        switch correction.score {
        case 100:
            return Color(red: 0.85, green: 0.65, blue: 0.13) // Gold
        case 90..<100:
            return .green
        case 70..<90:
            return .orange
        default:
            return .red
        }
    }

    private var statusColor: Color {
        scoreColor
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
