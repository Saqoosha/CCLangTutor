import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: CorrectionViewModel

    var body: some View {
        NavigationSplitView {
            CorrectionListView()
        } detail: {
            if let id = viewModel.selectedCorrectionId,
               let correction = viewModel.corrections.first(where: { $0.id == id }) {
                CorrectionDetailView(correction: correction)
            } else {
                emptyStateView
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Analyzing...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text("No Correction Selected")
                    .font(.title2.weight(.semibold))

                Text("Select a correction from the list\nto view details and explanations")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environmentObject(CorrectionViewModel())
}
