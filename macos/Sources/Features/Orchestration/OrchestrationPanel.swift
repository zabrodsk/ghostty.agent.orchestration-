import SwiftUI
import GhosttyKit

/// Main orchestration panel showing all terminal states
struct OrchestrationPanel: View {
    @ObservedObject var viewModel: OrchestrationViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TERMINALS (\(viewModel.surfaces.count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Terminal list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(viewModel.surfaces) { surface in
                        TerminalCardView(
                            surface: surface,
                            isSelected: viewModel.selectedSurfaceId == surface.id,
                            onTap: {
                                viewModel.focusSurface(surfaceId: surface.id)
                            }
                        )
                    }
                }
            }
        }
        .frame(minWidth: 250, maxWidth: 400)
    }
}
